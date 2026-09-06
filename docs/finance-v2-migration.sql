-- Additive migration for the Saldo finance features.
-- Safe to run once in Supabase SQL Editor; existing rows are preserved.
alter table public.finance
  add column if not exists eenmalige_uitgaven jsonb not null default '[]'::jsonb;

comment on column public.finance.eenmalige_uitgaven is
  'One-off purchases paid from the main account for this financial period';
