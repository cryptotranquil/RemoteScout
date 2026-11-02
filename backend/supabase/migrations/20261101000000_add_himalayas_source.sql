-- Add Himalayas listings to databases that already have the original schema.
alter table public.jobs
  drop constraint if exists jobs_source_check;

alter table public.jobs
  add constraint jobs_source_check
  check (source in ('remotive', 'remoteok', 'himalayas', 'manual'));
