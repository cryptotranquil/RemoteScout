-- RemoteScout — Supabase / PostgreSQL schema (05_Backend_Schema.md).
-- Single project; RLS enabled on every user-scoped table even for the
-- single-user MVP so it is multi-user-ready later.

create extension if not exists "uuid-ossp";

-- ============================================================ profiles ====

create table if not exists public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  name               text not null default '',
  email              text not null default '',
  skills             text[] not null default '{}',
  target_roles       text[] not null default '{}',
  minimum_salary     numeric,
  preferred_countries text[] not null default '{worldwide}',
  preferred_timezones text[] not null default '{}',
  experience_level   text not null default 'junior',
  cv_url             text,
  portfolio_url      text,
  created_at         timestamptz not null default now(),
  -- Schema note (documented deviation): notification preferences live with
  -- the profile as JSONB: {digest_time, min_match_score, max_jobs_per_day,
  -- weekend_enabled}. Kept here so `send-digest` can read them in one query.
  notification_prefs jsonb not null default
    '{"digest_time":"08:00","time_zone":"UTC","min_match_score":70,"max_jobs_per_day":5,"weekend_enabled":false}'::jsonb
);

-- ================================================================= jobs ====

create table if not exists public.jobs (
  id                  uuid primary key default uuid_generate_v4(),
  external_id         text not null,
  source              text not null check (source in ('remotive', 'remoteok', 'manual')),
  title               text not null,
  company             text not null,
  description         text not null default '',
  apply_url           text not null,
  source_url          text not null,
  location_text       text not null default 'Unspecified',
  location_scope      text not null default 'region_restricted'
                      check (location_scope in ('worldwide', 'region_restricted', 'country_restricted')),
  salary_min          numeric,
  salary_max          numeric,
  currency            text,
  employment_type     text not null default 'full_time',
  published_at        timestamptz not null,
  collected_at        timestamptz not null default now(),
  expires_at          timestamptz,
  is_expired_reported boolean not null default false,
  constraint jobs_source_external_unique unique (source, external_id)
);

-- Cross-source dedup enforced at write time (see fetch-jobs function):
-- an additional unique index on the normalized (company, title, apply_url).
create unique index if not exists jobs_cross_source_dedup
  on public.jobs (
    lower(trim(company)),
    lower(trim(title)),
    lower(regexp_replace(apply_url, '/+$', ''))
  );

create index if not exists jobs_published_at_idx on public.jobs (published_at desc);

-- ========================================================== job_matches ====

create table if not exists public.job_matches (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  job_id         uuid not null references public.jobs (id) on delete cascade,
  match_score    integer not null check (match_score between 0 and 100),
  matched_skills text[] not null default '{}',
  missing_skills text[] not null default '{}',
  match_reason   text not null default '',
  is_seen        boolean not null default false,
  is_saved       boolean not null default false,
  is_rejected    boolean not null default false,
  created_at     timestamptz not null default now(),
  constraint job_matches_user_job_unique unique (user_id, job_id)
);

create index if not exists job_matches_discover_idx
  on public.job_matches (user_id, match_score desc, is_seen);

-- ========================================================= applications ====

create table if not exists public.applications (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  -- Nullable to support "Add manually" entries; manual entries first insert a
  -- jobs row with source = 'manual' and still reference it here.
  job_id       uuid references public.jobs (id) on delete set null,
  status       text not null default 'new'
               check (status in ('new', 'saved', 'plan_to_apply', 'applied',
                                 'interview', 'rejected', 'offer', 'closed')),
  applied_at   timestamptz,
  follow_up_at timestamptz,
  cv_version   text,
  cover_letter text,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists applications_status_idx
  on public.applications (user_id, status);
create index if not exists applications_follow_up_idx
  on public.applications (user_id, follow_up_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists applications_set_updated_at on public.applications;
create trigger applications_set_updated_at
  before update on public.applications
  for each row execute function public.set_updated_at();

-- ======================================================== notifications ====

create table if not exists public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  job_id     uuid references public.jobs (id) on delete set null,
  channel    text not null check (channel in ('push', 'email')),
  sent_at    timestamptz not null default now(),
  opened_at  timestamptz
);

-- FCM registration tokens are private to each authenticated user's devices.
create table if not exists public.push_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

-- ============================================ manual "report expired" RPC ==
-- Column-level update via security definer so users can flag expired jobs
-- without broader write access to `jobs` (writes are otherwise service-role).

create or replace function public.report_expired_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.jobs
     set is_expired_reported = true
   where id = p_job_id;
end;
$$;

revoke all on function public.report_expired_job(uuid) from public;
grant execute on function public.report_expired_job(uuid) to authenticated;

-- ============================================== scheduled worker (cron) ====
-- Worker schedules and private Vault credential setup are in schedule.sql.

-- ================================================================ storage ==
-- Private CV bucket, RLS-scoped to the owning user (see rls.sql).

insert into storage.buckets (id, name, public)
values ('cv-files', 'cv-files', false)
on conflict (id) do nothing;
