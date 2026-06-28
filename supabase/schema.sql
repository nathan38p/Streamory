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

create table if not exists public.user_episode_watches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  series_tvdb_id text not null,
  series_title text not null,
  episode_tvdb_id text not null,
  season_number integer not null,
  episode_number integer not null,
  episode_name text,
  watched_at timestamptz,
  watched_count integer not null default 1,
  rewatch_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, series_tvdb_id, episode_tvdb_id)
);

alter table public.user_episode_watches enable row level security;

drop policy if exists "Users can read their Streamory episode watches" on public.user_episode_watches;

create policy "Users can read their Streamory episode watches"
  on public.user_episode_watches for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their Streamory episode watches" on public.user_episode_watches;

create policy "Users can create their Streamory episode watches"
  on public.user_episode_watches for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their Streamory episode watches" on public.user_episode_watches;

create policy "Users can update their Streamory episode watches"
  on public.user_episode_watches for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their Streamory episode watches" on public.user_episode_watches;

create policy "Users can delete their Streamory episode watches"
  on public.user_episode_watches for delete
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
alter table public.profiles drop constraint if exists profiles_username_format_check;
create unique index if not exists profiles_username_lower_key
  on public.profiles (lower(username));
alter table public.profiles add constraint profiles_username_format_check
  check (username ~ '^[a-z0-9._-]{3,28}$') not valid;

alter table public.profiles enable row level security;

create or replace function public.is_streamory_username_available(candidate text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select btrim(candidate) ~ '^[a-z0-9._-]{3,28}$'
    and not exists (
      select 1
      from public.profiles
      where lower(username) = lower(btrim(candidate))
    );
$$;

create or replace function public.normalize_streamory_username(raw_username text, fallback_user_id uuid)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when length(cleaned.username) >= 3 then substring(cleaned.username from 1 for 28)
    else 'user' || replace(substring(fallback_user_id::text from 1 for 8), '-', '')
  end
  from (
    select regexp_replace(lower(coalesce(raw_username, '')), '[^a-z0-9._-]', '', 'g') as username
  ) cleaned;
$$;

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
    public.normalize_streamory_username(
      coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
      new.id
    ),
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
drop trigger if exists on_auth_user_updated_streamory on auth.users;

create trigger on_auth_user_created_streamory
  after insert on auth.users
  for each row execute function public.handle_new_streamory_user();

create trigger on_auth_user_updated_streamory
  after update of raw_user_meta_data on auth.users
  for each row execute function public.handle_new_streamory_user();

insert into public.profiles (user_id, username, birth_date, country, country_label)
select
  users.id,
  public.normalize_streamory_username(
    coalesce(users.raw_user_meta_data ->> 'display_name', users.raw_user_meta_data ->> 'username', split_part(users.email, '@', 1)),
    users.id
  ),
  nullif(users.raw_user_meta_data ->> 'birth_date', '')::date,
  nullif(users.raw_user_meta_data ->> 'country', ''),
  nullif(users.raw_user_meta_data ->> 'country_label', '')
from auth.users users
on conflict (user_id) do update set
  username = excluded.username,
  birth_date = excluded.birth_date,
  country = excluded.country,
  country_label = excluded.country_label,
  updated_at = now();

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  check (requester_id <> addressee_id)
);

create unique index if not exists friend_requests_pair_key
  on public.friend_requests (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

alter table public.friend_requests enable row level security;

drop policy if exists "Users can read their Streamory friend requests" on public.friend_requests;

create policy "Users can read their Streamory friend requests"
  on public.friend_requests for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "Users can create their Streamory friend requests" on public.friend_requests;

create policy "Users can create their Streamory friend requests"
  on public.friend_requests for insert
  with check (auth.uid() = requester_id and requester_id <> addressee_id);

drop policy if exists "Users can answer their Streamory friend requests" on public.friend_requests;

create policy "Users can answer their Streamory friend requests"
  on public.friend_requests for update
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

drop policy if exists "Users can delete their Streamory friend requests" on public.friend_requests;

create policy "Users can delete their Streamory friend requests"
  on public.friend_requests for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create or replace function public.search_streamory_profiles(candidate text)
returns table (
  user_id uuid,
  username text,
  country text,
  relationship_status text
)
language sql
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.username,
    p.country,
    fr.status as relationship_status
  from public.profiles p
  left join public.friend_requests fr
    on fr.status in ('pending', 'accepted')
   and (
      (fr.requester_id = auth.uid() and fr.addressee_id = p.user_id)
      or (fr.addressee_id = auth.uid() and fr.requester_id = p.user_id)
    )
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and btrim(candidate) <> ''
    and lower(p.username) like '%' || lower(btrim(candidate)) || '%'
  order by p.username
  limit 12;
$$;

create or replace function public.send_streamory_friend_request(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or target_user_id is null or target_user_id = auth.uid() then
    return;
  end if;

  insert into public.friend_requests (requester_id, addressee_id)
  values (auth.uid(), target_user_id)
  on conflict do nothing;
end;
$$;

create or replace function public.list_streamory_friends()
returns table (
  user_id uuid,
  username text,
  country text,
  accepted_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.username,
    p.country,
    fr.accepted_at
  from public.friend_requests fr
  join public.profiles p
    on p.user_id = case
      when fr.requester_id = auth.uid() then fr.addressee_id
      else fr.requester_id
    end
  where auth.uid() is not null
    and fr.status = 'accepted'
    and (fr.requester_id = auth.uid() or fr.addressee_id = auth.uid())
  order by p.username;
$$;

create or replace function public.get_streamory_public_profile(profile_username text)
returns table (
  user_id uuid,
  username text,
  country text,
  friend_count bigint,
  relationship_status text
)
language sql
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.username,
    p.country,
    count(accepted.id) as friend_count,
    viewer_relation.status as relationship_status
  from public.profiles p
  left join public.friend_requests accepted
    on accepted.status = 'accepted'
   and (accepted.requester_id = p.user_id or accepted.addressee_id = p.user_id)
  left join public.friend_requests viewer_relation
    on auth.uid() is not null
   and viewer_relation.status in ('pending', 'accepted')
   and (
      (viewer_relation.requester_id = auth.uid() and viewer_relation.addressee_id = p.user_id)
      or (viewer_relation.addressee_id = auth.uid() and viewer_relation.requester_id = p.user_id)
    )
  where lower(p.username) = lower(btrim(profile_username))
  group by p.user_id, p.username, p.country, viewer_relation.status
  limit 1;
$$;

create or replace function public.list_streamory_friend_notifications()
returns table (
  request_id uuid,
  requester_id uuid,
  username text,
  country text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    fr.id,
    fr.requester_id,
    p.username,
    p.country,
    fr.created_at
  from public.friend_requests fr
  join public.profiles p on p.user_id = fr.requester_id
  where auth.uid() is not null
    and fr.addressee_id = auth.uid()
    and fr.status = 'pending'
  order by fr.created_at desc;
$$;

create or replace function public.accept_streamory_friend_request(request_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.friend_requests
  set status = 'accepted',
      accepted_at = now(),
      updated_at = now()
  where id = request_id
    and addressee_id = auth.uid()
    and status = 'pending';
$$;

create or replace function public.reject_streamory_friend_request(request_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.friend_requests
  where id = request_id
    and addressee_id = auth.uid()
    and status = 'pending';
$$;

create or replace function public.remove_streamory_friend(target_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.friend_requests
  where status = 'accepted'
    and (
      (requester_id = auth.uid() and addressee_id = target_user_id)
      or (addressee_id = auth.uid() and requester_id = target_user_id)
    );
$$;
