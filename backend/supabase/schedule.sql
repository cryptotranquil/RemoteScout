-- Before running: add these secrets in Supabase Dashboard → Database → Vault:
--   remotescout_functions_url     https://YOUR_PROJECT_REF.supabase.co/functions/v1
--   remotescout_service_role_key  the project's service_role/secret API key
-- Never paste credentials into this SQL file or commit them to source control.

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'remotescout-fetch-jobs',
  'remotescout-score-jobs',
  'remotescout-send-digest'
);

select cron.schedule('remotescout-fetch-jobs', '15 */3 * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'remotescout_functions_url') || '/fetch-jobs',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'remotescout_service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$);

select cron.schedule('remotescout-score-jobs', '25 */3 * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'remotescout_functions_url') || '/score-jobs',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'remotescout_service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$);

-- The worker checks every user's IANA timezone and configured local digest time.
select cron.schedule('remotescout-send-digest', '*/5 * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'remotescout_functions_url') || '/send-digest',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'remotescout_service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$);
