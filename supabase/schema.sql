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

create policy "Users can read their Streamory items"
  on public.user_items for select
  using (auth.uid() = user_id);

create policy "Users can create their Streamory items"
  on public.user_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update their Streamory items"
  on public.user_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their Streamory items"
  on public.user_items for delete
  using (auth.uid() = user_id);
