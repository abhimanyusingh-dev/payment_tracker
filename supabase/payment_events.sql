create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  source_id text not null unique,
  package_name text not null,
  app_name text not null,
  amount numeric(12,2),
  received boolean not null default false,
  payee_name text,
  timestamp timestamptz not null,
  status text,
  transaction_id text,
  reference_id text,
  upi_id text,
  currency text,
  raw_title text,
  raw_body text,
  raw_text text,
  note text,
  masked_account text,
  created_at timestamptz not null default now()
);

create index if not exists payment_events_timestamp_idx
  on public.payment_events (timestamp desc);

create index if not exists payment_events_app_name_idx
  on public.payment_events (app_name);

create index if not exists payment_events_received_idx
  on public.payment_events (received);

alter table public.payment_events enable row level security;

-- If you are using direct Supabase client access from a private app, replace these
-- policies with authenticated-user or service-to-service policies.
create policy "Allow read access to payment events"
  on public.payment_events
  for select
  using (true);

create policy "Allow insert payment events"
  on public.payment_events
  for insert
  with check (true);
