-- 너의 정원 v2 — Initial schema
-- Supabase SQL Editor에 붙여넣고 Run.
-- 한 번에 다 실행 OK. 이미 만든 적이 있으면 "already exists" 에러 → 그 부분 건너뛰면 됨.

-- ============================================================
-- 1. Tables
-- ============================================================

create table if not exists profiles (
  id uuid primary key,                       -- auth.uid()와 동일하게 클라이언트가 채움
  device_id text not null unique,
  nickname text not null,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_profiles_public on profiles(is_public) where is_public = true;

create table if not exists plants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  species text not null default 'succulent',
  current_stage int not null default 1 check (current_stage between 1 and 5),
  started_at timestamptz not null default now(),
  last_growth_at timestamptz,
  is_completed boolean not null default false
);
create index if not exists idx_plants_owner on plants(owner_id);

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references plants(id) on delete cascade,
  user_text text not null check (char_length(user_text) <= 500),
  ai_empathy text not null,
  ai_plant_voice text not null,
  stage_when_added int not null check (stage_when_added between 1 and 5),
  is_flagged boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_entries_plant on entries(plant_id, created_at desc);

create table if not exists reactions (
  id uuid primary key default gen_random_uuid(),
  from_profile_id uuid not null references profiles(id) on delete cascade,
  to_entry_id uuid not null references entries(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('water','sun','wind','shade','sprout')),
  created_at timestamptz not null default now(),
  unique (from_profile_id, to_entry_id)
);
create index if not exists idx_reactions_to_entry on reactions(to_entry_id);
create index if not exists idx_reactions_from on reactions(from_profile_id, created_at desc);

create table if not exists visits (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid not null references profiles(id) on delete cascade,
  visited_plant_id uuid not null references plants(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists idx_visits_plant on visits(visited_plant_id, created_at desc);

-- ============================================================
-- 2. Row Level Security
-- ============================================================

alter table profiles  enable row level security;
alter table plants    enable row level security;
alter table entries   enable row level security;
alter table reactions enable row level security;
alter table visits    enable row level security;

-- profiles
drop policy if exists profiles_self_all on profiles;
create policy profiles_self_all on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists profiles_public_read on profiles;
create policy profiles_public_read on profiles
  for select using (is_public = true);

-- plants
drop policy if exists plants_self_all on plants;
create policy plants_self_all on plants
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists plants_public_read on plants;
create policy plants_public_read on plants
  for select using (
    exists (select 1 from profiles p where p.id = plants.owner_id and p.is_public = true)
  );

-- entries
drop policy if exists entries_self_all on entries;
create policy entries_self_all on entries
  for all using (
    exists (select 1 from plants pl where pl.id = entries.plant_id and pl.owner_id = auth.uid())
  ) with check (
    exists (select 1 from plants pl where pl.id = entries.plant_id and pl.owner_id = auth.uid())
  );

drop policy if exists entries_public_read on entries;
create policy entries_public_read on entries
  for select using (
    is_flagged = false and
    exists (
      select 1 from plants pl
      join profiles pr on pr.id = pl.owner_id
      where pl.id = entries.plant_id and pr.is_public = true
    )
  );

-- reactions
drop policy if exists reactions_self_send on reactions;
create policy reactions_self_send on reactions
  for insert with check (
    auth.uid() = from_profile_id and
    exists (
      select 1 from entries e
      join plants pl on pl.id = e.plant_id
      join profiles pr on pr.id = pl.owner_id
      where e.id = reactions.to_entry_id
        and e.is_flagged = false
        and pr.is_public = true
    )
  );

drop policy if exists reactions_self_read on reactions;
create policy reactions_self_read on reactions
  for select using (auth.uid() = from_profile_id);

drop policy if exists reactions_received_read on reactions;
create policy reactions_received_read on reactions
  for select using (
    exists (
      select 1 from entries e join plants pl on pl.id = e.plant_id
      where e.id = reactions.to_entry_id and pl.owner_id = auth.uid()
    )
  );

drop policy if exists reactions_self_delete on reactions;
create policy reactions_self_delete on reactions
  for delete using (auth.uid() = from_profile_id);

-- visits
drop policy if exists visits_self_insert on visits;
create policy visits_self_insert on visits
  for insert with check (auth.uid() = visitor_id);

drop policy if exists visits_received_read on visits;
create policy visits_received_read on visits
  for select using (
    exists (select 1 from plants pl where pl.id = visits.visited_plant_id and pl.owner_id = auth.uid())
  );

-- ============================================================
-- 3. RPC: Discover (랜덤 5개 정원)
-- ============================================================

create or replace function discover_random(viewer_id uuid, limit_n int default 5)
returns setof plants
language sql
volatile  -- random() 때문에 volatile
security invoker
as $$
  select pl.*
  from plants pl
  join profiles pr on pr.id = pl.owner_id
  where pr.is_public = true
    and pr.id <> viewer_id
    and pl.is_completed = false
  order by random()
  limit limit_n;
$$;
