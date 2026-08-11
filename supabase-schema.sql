-- Daily Coach — Supabase Database Schema
-- Voer dit uit in Supabase Dashboard → SQL Editor

-- Tabellen aanmaken

create table daily_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  date date not null,
  data jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

create table weekly_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  week_number int not null,
  data jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, week_number)
);

create table therapy_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  data jsonb not null default '[]',
  updated_at timestamptz default now()
);

create table coach_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  date date not null,
  data jsonb not null default '{}',
  created_at timestamptz default now()
);

create table goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  active_goals jsonb not null default '[]',
  active_actions jsonb not null default '[]',
  updated_at timestamptz default now()
);

create table finance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  month_key text not null,
  vaste jsonb not null default '[]',
  knab jsonb not null default '[]',
  knab_tx jsonb not null default '[]',
  betaald jsonb not null default '{}',
  salaris numeric default 0,
  salaris_ontvangen boolean default false,
  salaris_datum date,
  history jsonb not null default '[]',
  updated_at timestamptz default now(),
  unique(user_id, month_key)
);

create table settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null unique,
  profiel jsonb default '[]',
  start_date date,
  prev_appointment date,
  next_appointment date,
  updated_at timestamptz default now()
);

create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  owner_id uuid references auth.users(id) not null,
  role text not null check (role in ('owner', 'behandelaar')),
  created_at timestamptz default now(),
  unique(user_id, owner_id)
);

-- updated_at trigger
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_daily_entries_updated before update on daily_entries for each row execute function update_updated_at();
create trigger trg_weekly_entries_updated before update on weekly_entries for each row execute function update_updated_at();
create trigger trg_therapy_sessions_updated before update on therapy_sessions for each row execute function update_updated_at();
create trigger trg_goals_updated before update on goals for each row execute function update_updated_at();
create trigger trg_finance_updated before update on finance for each row execute function update_updated_at();
create trigger trg_settings_updated before update on settings for each row execute function update_updated_at();

-- RLS inschakelen
alter table daily_entries enable row level security;
alter table weekly_entries enable row level security;
alter table therapy_sessions enable row level security;
alter table coach_sessions enable row level security;
alter table goals enable row level security;
alter table finance enable row level security;
alter table settings enable row level security;
alter table user_roles enable row level security;

-- Owner policies: eigen data lezen/schrijven
create policy "owner_select" on daily_entries for select using (user_id = auth.uid());
create policy "owner_insert" on daily_entries for insert with check (user_id = auth.uid());
create policy "owner_update" on daily_entries for update using (user_id = auth.uid());
create policy "owner_delete" on daily_entries for delete using (user_id = auth.uid());

create policy "owner_select" on weekly_entries for select using (user_id = auth.uid());
create policy "owner_insert" on weekly_entries for insert with check (user_id = auth.uid());
create policy "owner_update" on weekly_entries for update using (user_id = auth.uid());
create policy "owner_delete" on weekly_entries for delete using (user_id = auth.uid());

create policy "owner_select" on therapy_sessions for select using (user_id = auth.uid());
create policy "owner_insert" on therapy_sessions for insert with check (user_id = auth.uid());
create policy "owner_update" on therapy_sessions for update using (user_id = auth.uid());
create policy "owner_delete" on therapy_sessions for delete using (user_id = auth.uid());

create policy "owner_select" on coach_sessions for select using (user_id = auth.uid());
create policy "owner_insert" on coach_sessions for insert with check (user_id = auth.uid());
create policy "owner_update" on coach_sessions for update using (user_id = auth.uid());
create policy "owner_delete" on coach_sessions for delete using (user_id = auth.uid());

create policy "owner_select" on goals for select using (user_id = auth.uid());
create policy "owner_insert" on goals for insert with check (user_id = auth.uid());
create policy "owner_update" on goals for update using (user_id = auth.uid());
create policy "owner_delete" on goals for delete using (user_id = auth.uid());

create policy "owner_select" on finance for select using (user_id = auth.uid());
create policy "owner_insert" on finance for insert with check (user_id = auth.uid());
create policy "owner_update" on finance for update using (user_id = auth.uid());
create policy "owner_delete" on finance for delete using (user_id = auth.uid());

create policy "owner_select" on settings for select using (user_id = auth.uid());
create policy "owner_insert" on settings for insert with check (user_id = auth.uid());
create policy "owner_update" on settings for update using (user_id = auth.uid());
create policy "owner_delete" on settings for delete using (user_id = auth.uid());

create policy "owner_select" on user_roles for select using (owner_id = auth.uid() or user_id = auth.uid());
create policy "owner_insert" on user_roles for insert with check (owner_id = auth.uid());
create policy "owner_delete" on user_roles for delete using (owner_id = auth.uid());

-- Behandelaar policies: alleen lezen op mentale tabellen
create policy "behandelaar_select" on daily_entries for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = daily_entries.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on weekly_entries for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = weekly_entries.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on therapy_sessions for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = therapy_sessions.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on coach_sessions for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = coach_sessions.user_id and user_roles.role = 'behandelaar')
);
create policy "behandelaar_select" on goals for select using (
  exists (select 1 from user_roles where user_roles.user_id = auth.uid() and user_roles.owner_id = goals.user_id and user_roles.role = 'behandelaar')
);
