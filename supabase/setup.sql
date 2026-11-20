-- Job Fit: private settings table (paste into Supabase → SQL Editor → Run).
-- Holds my profile and evaluation rules. Structure only: no data in this file.

create table if not exists public.private_settings (
  key   text primary key,
  value text not null
);

-- Row Level Security ON and NO policies: the browser (publishable key) can
-- read nothing. Only the server function, using the service key, can read it.
alter table public.private_settings enable row level security;

-- New Supabase projects don't grant table access automatically:
-- allow ONLY the server role (used inside the Edge Function) to read it.
grant select on table public.private_settings to service_role;
