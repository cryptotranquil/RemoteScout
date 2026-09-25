-- RemoteScout — Row Level Security (05_Backend_Schema.md §2).
-- Enabled on every user-scoped table, even for a single-user MVP.

-- ============================================================ profiles ====

alter table public.profiles enable row level security;

drop policy if exists "profiles: own row" on public.profiles;
create policy "profiles: own row"
  on public.profiles
  for all
  using (id = auth.uid())
  with check (id = auth.uid());

-- ================================================================= jobs ====

alter table public.jobs enable row level security;

-- Shared catalog: readable by any authenticated user.
drop policy if exists "jobs: authenticated read" on public.jobs;
create policy "jobs: authenticated read"
  on public.jobs
  for select
  to authenticated
  using (true);

-- Writes restricted to the service role (backend worker).
-- Manual entries: the app may insert listings it created itself.
drop policy if exists "jobs: manual insert" on public.jobs;
create policy "jobs: manual insert"
  on public.jobs
  for insert
  to authenticated
  with check (source = 'manual');

-- Expired flag is flipped only through the report_expired_job() RPC
-- (security definer), so no update policy is granted here.

-- ========================================================== job_matches ====

alter table public.job_matches enable row level security;

drop policy if exists "job_matches: own rows select" on public.job_matches;
create policy "job_matches: own rows select"
  on public.job_matches
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "job_matches: own rows update" on public.job_matches;
create policy "job_matches: own rows update"
  on public.job_matches
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Inserts come from the scoring worker (service role); users may also
-- insert their own rows (e.g. manual tracking starts).
drop policy if exists "job_matches: own rows insert" on public.job_matches;
create policy "job_matches: own rows insert"
  on public.job_matches
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- ========================================================= applications ====

alter table public.applications enable row level security;

drop policy if exists "applications: own rows" on public.applications;
create policy "applications: own rows"
  on public.applications
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ======================================================== notifications ====

alter table public.notifications enable row level security;

drop policy if exists "notifications: own rows select" on public.notifications;
create policy "notifications: own rows select"
  on public.notifications
  for select
  to authenticated
  using (user_id = auth.uid());

-- Writes restricted to the service role (send-digest worker).

-- ================================================================= storage =
-- cv-files bucket: only the owning user may read/write their own CV.

drop policy if exists "cv-files: own folder" on storage.objects;
create policy "cv-files: own folder"
  on storage.objects
  for all
  to authenticated
  using (bucket_id = 'cv-files' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'cv-files' and (storage.foldername(name))[1] = auth.uid()::text);
