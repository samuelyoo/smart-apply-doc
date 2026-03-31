-- Resume-Flow AI
-- Database Schema for Supabase / PostgreSQL
-- Version: 1.0
-- Notes:
--   - Designed for Clerk + Supabase integration
--   - Generated resume PDFs are NOT stored in DB
--   - RLS policies assume JWT contains Clerk user id in `sub`
--   - Adjust current_clerk_user_id() if your Clerk/Supabase claim mapping differs

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Utility functions
-- ---------------------------------------------------------------------------

create or replace function public.current_clerk_user_id()
returns text
language sql
stable
as $$
  select nullif(
    coalesce(
      auth.jwt() ->> 'sub',
      auth.jwt() ->> 'userId',
      auth.jwt() -> 'claims' ->> 'sub'
    ),
    ''
  );
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'application_status'
  ) then
    create type public.application_status as enum (
      'draft',
      'generated',
      'applied',
      'interviewing',
      'offer',
      'rejected',
      'withdrawn'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.master_profiles (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null unique,
  full_name text,
  email text,
  phone text,
  location text,
  linkedin_url text,
  portfolio_url text,
  summary text,
  base_skills jsonb not null default '[]'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  experiences jsonb not null default '[]'::jsonb,
  education jsonb not null default '[]'::jsonb,
  raw_profile_source text,
  profile_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint master_profiles_base_skills_is_array
    check (jsonb_typeof(base_skills) = 'array'),
  constraint master_profiles_certifications_is_array
    check (jsonb_typeof(certifications) = 'array'),
  constraint master_profiles_experiences_is_array
    check (jsonb_typeof(experiences) = 'array'),
  constraint master_profiles_education_is_array
    check (jsonb_typeof(education) = 'array')
);

create table if not exists public.application_history (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null,
  company_name text not null,
  job_title text not null,
  source_platform text,
  source_url text,
  job_description_hash text,
  drive_link text,
  ats_score_before integer,
  ats_score_after integer,
  applied_resume_snapshot jsonb,
  status public.application_status not null default 'applied',
  created_at timestamptz not null default now(),
  applied_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint application_history_ats_score_before_range
    check (ats_score_before is null or (ats_score_before >= 0 and ats_score_before <= 100)),
  constraint application_history_ats_score_after_range
    check (ats_score_after is null or (ats_score_after >= 0 and ats_score_after <= 100))
);

create table if not exists public.user_integrations (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null,
  provider text not null,
  provider_account_email text,
  access_scope text,
  refresh_token_encrypted text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_integrations_provider_check
    check (provider in ('google_drive')),
  constraint user_integrations_unique_user_provider
    unique (clerk_user_id, provider)
);

-- ---------------------------------------------------------------------------
-- Foreign Keys
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'application_history_clerk_user_id_fkey'
  ) then
    alter table public.application_history
      add constraint application_history_clerk_user_id_fkey
      foreign key (clerk_user_id)
      references public.master_profiles (clerk_user_id)
      on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_integrations_clerk_user_id_fkey'
  ) then
    alter table public.user_integrations
      add constraint user_integrations_clerk_user_id_fkey
      foreign key (clerk_user_id)
      references public.master_profiles (clerk_user_id)
      on delete cascade;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists idx_master_profiles_clerk_user_id
  on public.master_profiles (clerk_user_id);

create index if not exists idx_application_history_clerk_user_id
  on public.application_history (clerk_user_id);

create index if not exists idx_application_history_created_at
  on public.application_history (created_at desc);

create index if not exists idx_application_history_status
  on public.application_history (status);

create index if not exists idx_application_history_company_name
  on public.application_history (company_name);

create index if not exists idx_application_history_job_description_hash
  on public.application_history (job_description_hash);

create index if not exists idx_user_integrations_clerk_user_id
  on public.user_integrations (clerk_user_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

drop trigger if exists trg_master_profiles_updated_at on public.master_profiles;
create trigger trg_master_profiles_updated_at
before update on public.master_profiles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_application_history_updated_at on public.application_history;
create trigger trg_application_history_updated_at
before update on public.application_history
for each row
execute function public.set_updated_at();

drop trigger if exists trg_user_integrations_updated_at on public.user_integrations;
create trigger trg_user_integrations_updated_at
before update on public.user_integrations
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.master_profiles enable row level security;
alter table public.application_history enable row level security;
alter table public.user_integrations enable row level security;

-- master_profiles policies
drop policy if exists "master_profiles_select_own" on public.master_profiles;
create policy "master_profiles_select_own"
on public.master_profiles
for select
using (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "master_profiles_insert_own" on public.master_profiles;
create policy "master_profiles_insert_own"
on public.master_profiles
for insert
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "master_profiles_update_own" on public.master_profiles;
create policy "master_profiles_update_own"
on public.master_profiles
for update
using (clerk_user_id = public.current_clerk_user_id())
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "master_profiles_delete_own" on public.master_profiles;
create policy "master_profiles_delete_own"
on public.master_profiles
for delete
using (clerk_user_id = public.current_clerk_user_id());

-- application_history policies
drop policy if exists "application_history_select_own" on public.application_history;
create policy "application_history_select_own"
on public.application_history
for select
using (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "application_history_insert_own" on public.application_history;
create policy "application_history_insert_own"
on public.application_history
for insert
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "application_history_update_own" on public.application_history;
create policy "application_history_update_own"
on public.application_history
for update
using (clerk_user_id = public.current_clerk_user_id())
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "application_history_delete_own" on public.application_history;
create policy "application_history_delete_own"
on public.application_history
for delete
using (clerk_user_id = public.current_clerk_user_id());

-- user_integrations policies
drop policy if exists "user_integrations_select_own" on public.user_integrations;
create policy "user_integrations_select_own"
on public.user_integrations
for select
using (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "user_integrations_insert_own" on public.user_integrations;
create policy "user_integrations_insert_own"
on public.user_integrations
for insert
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "user_integrations_update_own" on public.user_integrations;
create policy "user_integrations_update_own"
on public.user_integrations
for update
using (clerk_user_id = public.current_clerk_user_id())
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists "user_integrations_delete_own" on public.user_integrations;
create policy "user_integrations_delete_own"
on public.user_integrations
for delete
using (clerk_user_id = public.current_clerk_user_id());

commit;

-- ---------------------------------------------------------------------------
-- Example JSON shapes
-- ---------------------------------------------------------------------------
-- base_skills:
--   ["C#", ".NET", "SQL", "Node.js"]
--
-- experiences:
--   [
--     {
--       "company": "CIBC",
--       "role": "Backend Developer",
--       "start_date": "2024-10",
--       "end_date": null,
--       "description": [
--         "Built backend services using Node.js and SQL",
--         "Worked on capital markets internal systems"
--       ]
--     }
--   ]
--
-- education:
--   [
--     {
--       "school": "Example University",
--       "degree": "BSc Computer Science",
--       "start_date": "2018-09",
--       "end_date": "2022-06"
--     }
--   ]
