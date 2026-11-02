-- Add We Work Remotely RSS listings to existing databases.
alter table public.jobs
  drop constraint if exists jobs_source_check;

alter table public.jobs
  add constraint jobs_source_check
  check (source in (
    'remotive', 'remoteok', 'himalayas', 'jobicy', 'arbeitnow', 'adzuna',
    'jooble', 'themuse', 'findwork', 'weworkremotely', 'manual'
  ));
