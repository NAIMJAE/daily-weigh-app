-- 매일재라 앱 v1 스키마. 앱 전용 빈 프로젝트에서 SQL Editor로 실행한다.
-- Authentication > Sign In / Providers > Email 의 Confirm email 은 OFF.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 테이블
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  nickname text not null,
  height numeric(5, 1),
  start_weight numeric(5, 2),
  target_weight numeric(5, 2),
  wallet_points integer not null default 0,
  streak_days integer not null default 0,
  last_attend_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text,
  is_personal boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint personal_has_no_invite check (
    (is_personal and invite_code is null) or (not is_personal)
  )
);

create unique index if not exists groups_invite_code_uidx
  on public.groups (invite_code) where invite_code is not null;

create unique index if not exists groups_one_personal_per_user
  on public.groups (created_by) where is_personal;

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create table if not exists public.daily_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  record_date date not null,
  weight numeric(5, 2),
  body_photo_url text,
  meal_photo_url text,
  workout_minutes integer,
  workout_kinds text[],
  memo text,
  points_earned integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, record_date),
  constraint workout_kinds_known check (
    workout_kinds is null
    or workout_kinds <@ array['gym', 'cardio', 'home', 'swim', 'ball', 'pilates', 'walk', 'rest']::text[]
  ),
  constraint daily_records_at_least_one check (
    weight is not null
    or body_photo_url is not null
    or meal_photo_url is not null
    or (workout_kinds is not null and cardinality(workout_kinds) > 0)
    or (memo is not null and length(trim(memo)) > 0)
  )
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  record_id uuid not null references public.daily_records(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  photo_kind text not null check (photo_kind in ('body', 'meal')),
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.pokes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 가입 트리거
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, nickname)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'nickname', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 헬퍼
-- ---------------------------------------------------------------------------

create or replace function public.share_group(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members me
    join public.group_members them
      on them.group_id = me.group_id
    where me.user_id = a
      and them.user_id = b
  );
$$;

create or replace function public.is_group_member(check_group_id uuid, check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = check_group_id and user_id = check_user_id
  );
$$;

create or replace function public.ensure_personal_group()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id into gid
  from public.groups
  where created_by = auth.uid()
    and is_personal = true;

  if gid is not null then
    insert into public.group_members (group_id, user_id, role)
    values (gid, auth.uid(), 'owner')
    on conflict (group_id, user_id) do nothing;
    return gid;
  end if;

  insert into public.groups (name, is_personal, created_by)
  values ('나만의 그룹', true, auth.uid())
  returning id into gid;

  insert into public.group_members (group_id, user_id, role)
  values (gid, auth.uid(), 'owner');
  return gid;
end;
$$;

create or replace function public.create_friend_group(p_name text, p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  created public.groups%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if length(trim(p_name)) = 0 then
    raise exception 'group name required';
  end if;

  insert into public.groups (name, is_personal, invite_code, created_by)
  values (trim(p_name), false, p_code, auth.uid())
  returning * into created;

  insert into public.group_members (group_id, user_id, role)
  values (created.id, auth.uid(), 'owner');
  return created;
end;
$$;

grant execute on function public.ensure_personal_group() to authenticated;
grant execute on function public.create_friend_group(text, text) to authenticated;

create or replace function public.join_friend_group(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.groups%rowtype;
  member_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into target
  from public.groups
  where invite_code = upper(trim(code))
    and is_personal = false;

  if target.id is null then
    raise exception 'invalid invite code';
  end if;

  select count(*) into member_count
  from public.group_members
  where group_id = target.id;

  if member_count >= 8 then
    raise exception 'group is full';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (target.id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return target.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.daily_records enable row level security;
alter table public.comments enable row level security;
alter table public.pokes enable row level security;

create policy profiles_select on public.profiles
  for select using (id = auth.uid() or public.share_group(auth.uid(), id));

create policy profiles_insert on public.profiles
  for insert with check (id = auth.uid());

create policy profiles_update on public.profiles
  for update using (id = auth.uid());

create policy groups_select on public.groups
  for select using (
    created_by = auth.uid() or public.is_group_member(id, auth.uid())
  );

create policy groups_insert on public.groups
  for insert with check (auth.uid() is not null and created_by = auth.uid());

create policy groups_update on public.groups
  for update using (public.is_group_member(id, auth.uid()));

create policy groups_delete on public.groups
  for delete using (
    created_by = auth.uid() or public.is_group_member(id, auth.uid())
  );

create policy members_select on public.group_members
  for select using (public.is_group_member(group_id, auth.uid()));

create policy members_insert on public.group_members
  for insert with check (user_id = auth.uid());

create policy members_update on public.group_members
  for update using (public.is_group_member(group_id, auth.uid()));

create policy members_delete on public.group_members
  for delete using (
    user_id = auth.uid() or public.is_group_member(group_id, auth.uid())
  );

create policy records_select on public.daily_records
  for select using (user_id = auth.uid() or public.share_group(auth.uid(), user_id));

create policy records_insert on public.daily_records
  for insert with check (user_id = auth.uid());

create policy records_update on public.daily_records
  for update using (user_id = auth.uid());

create policy comments_select on public.comments
  for select using (public.is_group_member(group_id, auth.uid()));

create policy comments_insert on public.comments
  for insert with check (
    author_id = auth.uid() and public.is_group_member(group_id, auth.uid())
  );

create policy comments_delete on public.comments
  for delete using (author_id = auth.uid());

create policy pokes_select on public.pokes
  for select using (public.is_group_member(group_id, auth.uid()));

create policy pokes_insert on public.pokes
  for insert with check (
    sender_id = auth.uid() and public.is_group_member(group_id, auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values
  ('body-photos', 'body-photos', false),
  ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

create policy body_photos_select on storage.objects
  for select using (
    bucket_id = 'body-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.share_group(auth.uid(), ((storage.foldername(name))[1])::uuid)
    )
  );

create policy body_photos_insert on storage.objects
  for insert with check (
    bucket_id = 'body-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy body_photos_update on storage.objects
  for update using (
    bucket_id = 'body-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy meal_photos_select on storage.objects
  for select using (
    bucket_id = 'meal-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.share_group(auth.uid(), ((storage.foldername(name))[1])::uuid)
    )
  );

create policy meal_photos_insert on storage.objects
  for insert with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy meal_photos_update on storage.objects
  for update using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
