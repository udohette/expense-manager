create table if not exists public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  onboarding_complete boolean not null default false,
  currency_code text not null default 'NGN',
  hide_balances boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.expense_categories (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  icon_code_point integer not null,
  color_value integer not null,
  type text not null check (type in ('expense', 'income')),
  is_default boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.expense_entries (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  amount numeric not null,
  date timestamptz not null,
  category_id text not null,
  type text not null check (type in ('expense', 'income')),
  payment_method text not null default '',
  note text not null default '',
  source text not null default 'manual' check (source in ('manual', 'sms', 'bankApi')),
  external_id text not null default '',
  merchant_or_sender text not null default '',
  account_hint text not null default '',
  institution_name text not null default '',
  raw_message text not null default '',
  imported_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.budget_plans (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  limit_amount numeric not null,
  category_id text,
  start_date timestamptz not null,
  period text not null check (period in ('weekly', 'monthly')),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.debt_records (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  person_name text not null,
  amount numeric not null,
  type text not null check (type in ('owedToMe', 'iOwe')),
  status text not null check (status in ('active', 'settled')),
  person_source text not null check (person_source in ('manual', 'contacts')),
  created_at timestamptz not null,
  phone_number text,
  note text not null default '',
  contact_id text,
  due_date timestamptz,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.user_settings enable row level security;
alter table public.expense_categories enable row level security;
alter table public.expense_entries enable row level security;
alter table public.budget_plans enable row level security;
alter table public.debt_records enable row level security;

create policy "users manage own settings"
on public.user_settings
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users manage own categories"
on public.expense_categories
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users manage own entries"
on public.expense_entries
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users manage own budgets"
on public.budget_plans
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users manage own debts"
on public.debt_records
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
