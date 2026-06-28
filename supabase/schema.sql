create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tvdb_id text not null,
  media_type text not null check (media_type in ('series', 'movie')),
  title text not null,
  image_url text,
  year text,
  overview text,
  status text not null default 'watchlist' check (status in ('watchlist', 'watching', 'watched')),
  rating smallint check (rating between 0 and 10),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, tvdb_id, media_type)
);

alter table public.user_items enable row level security;

drop policy if exists "Users can read their Streamory items" on public.user_items;

create policy "Users can read their Streamory items"
  on public.user_items for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their Streamory items" on public.user_items;

create policy "Users can create their Streamory items"
  on public.user_items for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their Streamory items" on public.user_items;

create policy "Users can update their Streamory items"
  on public.user_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their Streamory items" on public.user_items;

create policy "Users can delete their Streamory items"
  on public.user_items for delete
  using (auth.uid() = user_id);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  birth_date date,
  country text,
  country_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles drop constraint if exists profiles_username_key;

alter table public.profiles enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can read their Streamory profile'
  ) then
    create policy "Users can read their Streamory profile"
      on public.profiles for select
      using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can update their Streamory profile'
  ) then
    create policy "Users can update their Streamory profile"
      on public.profiles for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

create or replace function public.handle_new_streamory_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, username, birth_date, country, country_label)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data ->> 'birth_date', '')::date,
    nullif(new.raw_user_meta_data ->> 'country', ''),
    nullif(new.raw_user_meta_data ->> 'country_label', '')
  )
  on conflict (user_id) do update set
    username = excluded.username,
    birth_date = excluded.birth_date,
    country = excluded.country,
    country_label = excluded.country_label,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_streamory on auth.users;

create trigger on_auth_user_created_streamory
  after insert on auth.users
  for each row execute function public.handle_new_streamory_user();
