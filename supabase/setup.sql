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

-- History of evaluated jobs (written and read only by the Edge Function).
-- Score and verdict are NOT stored: the app recomputes them from `analysis`
-- with its fixed rules, so old entries always follow the current rules.
create table if not exists public.job_history (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  job_text   text not null,
  analysis   jsonb not null
);
alter table public.job_history enable row level security;
grant select, insert, delete on table public.job_history to service_role;

-- Application tracker: where I am with each saved job.
alter table public.job_history
  add column if not exists status text not null default 'saved'
  check (status in ('saved', 'applied', 'interview', 'rejected', 'offer'));
grant update (status) on table public.job_history to service_role;

-- Cover letter written for a saved job (kept so it is not generated twice).
alter table public.job_history add column if not exists cover_letter text;
grant update (cover_letter) on table public.job_history to service_role;
