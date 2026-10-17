-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-record-flows.sql 다음에 실행한다.
-- 운동 루틴 (docs/workout-routine-plan.md).
-- 1) 종목, 루틴(날, 종목), 운동 기록(세션, 세트) 테이블과 권한
-- 2) 운동을 완료하면 그 날 하루 기록에 운동 표시와 시간이 들어가 출석, 점수, 스트릭이 돈다
-- 3) 템플릿과 친구 루틴을 내 루틴으로 복사하는 함수, 운동 하나를 한 번에 저장하는 함수
-- 4) 기본 종목 63개와 템플릿 4개
-- 다시 실행해도 된다. 기본 종목은 이름으로 맞추고, 템플릿은 지우고 다시 만든다.

-- ---------------------------------------------------------------------------
-- 테이블
-- ---------------------------------------------------------------------------

-- owner_id 가 없으면 앱이 주는 기본 종목이다.
create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  body_part text not null check (body_part in ('chest', 'back', 'shoulder', 'legs', 'arms', 'core', 'cardio', 'other')),
  equipment text check (equipment in ('barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'other')),
  -- 기록 방식: kg×회, 회(맨몸), 시간, 시간+거리
  measure text not null check (measure in ('weight_reps', 'reps', 'time', 'time_distance')),
  -- 증량 방식: 무게, 더블 프로그레션, 횟수, 시간, 제안 안 함
  progression text not null default 'none' check (progression in ('weight', 'double', 'reps', 'time', 'none')),
  -- 증량 단위. 무게는 kg, 횟수는 회, 시간은 초.
  increment numeric(6, 2),
  rest_seconds integer check (rest_seconds is null or rest_seconds >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists exercises_base_name_uidx
  on public.exercises (name) where owner_id is null;
create unique index if not exists exercises_owner_name_uidx
  on public.exercises (owner_id, name) where owner_id is not null;

-- owner_id 가 없으면 템플릿이다. 템플릿은 template_key 로 찾는다.
create table if not exists public.routines (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade,
  template_key text unique,
  name text not null check (length(trim(name)) > 0),
  description text,
  is_active boolean not null default false,
  source_routine_id uuid references public.routines(id) on delete set null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routines_template_has_no_owner check (template_key is null or owner_id is null)
);

-- 사용 중인 루틴은 사람마다 하나다.
create unique index if not exists routines_one_active_per_user
  on public.routines (owner_id) where is_active;

create table if not exists public.routine_days (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines(id) on delete cascade,
  position integer not null,
  name text not null check (length(trim(name)) > 0)
);

create index if not exists routine_days_routine_idx on public.routine_days (routine_id, position);

-- 목표: 세트 수와 횟수 범위(같으면 고정, 둘 다 비면 '최대'), 시간(초), 거리(km), 무게(kg).
-- 증량 방식, 단위, 쉬는 시간이 비어 있으면 종목의 기본값을 쓴다.
create table if not exists public.routine_items (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.routine_days(id) on delete cascade,
  position integer not null,
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  target_sets integer not null default 3 check (target_sets between 1 and 20),
  reps_min integer check (reps_min is null or reps_min > 0),
  reps_max integer check (reps_max is null or reps_max > 0),
  target_seconds integer check (target_seconds is null or target_seconds > 0),
  target_distance_km numeric(6, 2),
  target_weight numeric(6, 2),
  progression text check (progression in ('weight', 'double', 'reps', 'time', 'none')),
  increment numeric(6, 2),
  rest_seconds integer check (rest_seconds is null or rest_seconds >= 0),
  constraint routine_items_reps_range check (reps_min is null or reps_max is null or reps_min <= reps_max)
);

create index if not exists routine_items_day_idx on public.routine_items (day_id, position);

-- 완료한 운동 하나. 진행 중 상태는 휴대폰에 둔다.
-- 헬스장에서 기록하면 시작·끝 시각이 있고, 어제 운동을 표로 채우면 운동 시간만 있다.
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  record_date date not null,
  routine_id uuid references public.routines(id) on delete set null,
  routine_day_id uuid references public.routine_days(id) on delete set null,
  -- 루틴을 고쳐도 지난 기록의 이름은 그대로 보이도록 남긴다.
  day_name text,
  started_at timestamptz,
  finished_at timestamptz,
  duration_minutes integer not null check (duration_minutes >= 0),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists workout_sessions_user_date_idx on public.workout_sessions (user_id, record_date desc);

create table if not exists public.session_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id uuid references public.exercises(id) on delete set null,
  exercise_name text not null,
  item_position integer not null,
  set_number integer not null,
  weight_kg numeric(6, 2),
  reps integer,
  seconds integer,
  distance_km numeric(6, 2),
  -- 증량 제안은 그때의 목표와 비교한다.
  target_reps integer,
  target_seconds integer,
  done boolean not null default true
);

create index if not exists session_sets_session_idx on public.session_sets (session_id, item_position, set_number);
create index if not exists session_sets_exercise_idx on public.session_sets (exercise_id);

-- ---------------------------------------------------------------------------
-- 하루 기록에 운동 표시
-- ---------------------------------------------------------------------------

alter table public.daily_records add column if not exists has_session boolean not null default false;
alter table public.daily_records add column if not exists session_minutes integer;

alter table public.daily_records drop constraint if exists daily_records_at_least_one;
alter table public.daily_records add constraint daily_records_at_least_one check (
  weight is not null
  or body_photo_url is not null
  or meal_photo_url is not null
  or has_meal
  or has_session
  or (workout_kinds is not null and cardinality(workout_kinds) > 0)
  or (memo is not null and length(trim(memo)) > 0)
);

-- 운동 점수: 예전 운동 종류를 골랐거나 운동을 완료한 날 +20. 휴식이 아니고 30분 이상이면 +5.
drop function if exists public.compute_record_points(numeric, text, text, text[], integer, boolean);
create or replace function public.compute_record_points(
  p_weight numeric,
  p_body text,
  p_meal text,
  p_kinds text[],
  p_minutes integer,
  p_has_meal boolean,
  p_has_session boolean,
  p_session_minutes integer
)
returns integer
language sql
immutable
as $$
  with flags as (
    select
      coalesce(cardinality(p_kinds), 0) > 0 or coalesce(p_has_session, false) as worked,
      (coalesce(p_has_session, false) and coalesce(p_session_minutes, 0) >= 30)
        or (coalesce(cardinality(p_kinds), 0) > 0
            and p_kinds <> array['rest']::text[]
            and coalesce(p_minutes, 0) >= 30) as long_workout
  )
  select
    (case when p_weight is not null then 10 else 0 end)
    + (case when nullif(p_body, '') is not null then 15 else 0 end)
    + (case when nullif(p_meal, '') is not null or coalesce(p_has_meal, false) then 15 else 0 end)
    + (case when flags.worked then 20 + (case when flags.long_workout then 5 else 0 end) else 0 end)
    + (case when p_weight is not null and nullif(p_body, '') is not null and flags.worked then 15 else 0 end)
  from flags;
$$;

create or replace function public.daily_records_set_points()
returns trigger
language plpgsql
as $$
begin
  new.points_earned := public.compute_record_points(
    new.weight, new.body_photo_url, new.meal_photo_url, new.workout_kinds, new.workout_minutes,
    new.has_meal, new.has_session, new.session_minutes
  );
  return new;
end;
$$;

-- 그 날의 끼니와 운동을 보고 하루 기록의 has_meal, has_session, session_minutes 를 맞춘다.
-- 끼니도 운동도 없고 다른 기록도 없으면 하루 기록을 지우고 점수를 돌려놓는다.
create or replace function public.sync_day_flags(p_user uuid, p_day date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  meal boolean;
  session_count integer;
  minutes integer;
  rec public.daily_records%rowtype;
begin
  select exists (select 1 from public.meal_entries where user_id = p_user and record_date = p_day) into meal;
  select count(*), sum(duration_minutes)::integer into session_count, minutes
  from public.workout_sessions
  where user_id = p_user and record_date = p_day;

  select * into rec from public.daily_records where user_id = p_user and record_date = p_day;

  if meal or session_count > 0 then
    insert into public.daily_records (user_id, record_date, has_meal, has_session, session_minutes)
    values (p_user, p_day, meal, session_count > 0, minutes)
    on conflict (user_id, record_date) do update set
      has_meal = excluded.has_meal,
      has_session = excluded.has_session,
      session_minutes = excluded.session_minutes,
      updated_at = now()
    where public.daily_records.has_meal is distinct from excluded.has_meal
       or public.daily_records.has_session is distinct from excluded.has_session
       or public.daily_records.session_minutes is distinct from excluded.session_minutes;
    return;
  end if;

  if rec.id is null or (not rec.has_meal and not rec.has_session) then
    return;
  end if;

  if rec.weight is null
     and nullif(rec.body_photo_url, '') is null
     and nullif(rec.meal_photo_url, '') is null
     and coalesce(cardinality(rec.workout_kinds), 0) = 0
     and nullif(trim(coalesce(rec.memo, '')), '') is null then
    delete from public.daily_records where id = rec.id;
    update public.profiles set
      wallet_points = wallet_points - rec.points_earned,
      updated_at = now()
    where id = p_user;
    perform public.recompute_streak(p_user);
  else
    update public.daily_records set
      has_meal = false,
      has_session = false,
      session_minutes = null,
      updated_at = now()
    where id = rec.id;
  end if;
end;
$$;

-- 끼니 트리거도 같은 함수를 쓴다 (patch-record-flows.sql 의 함수를 바꾼다).
create or replace function public.meal_entries_sync_day()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'INSERT' then
    perform public.sync_day_flags(old.user_id, old.record_date);
  end if;
  if tg_op <> 'DELETE' then
    perform public.sync_day_flags(new.user_id, new.record_date);
  end if;
  return null;
end;
$$;

create or replace function public.workout_sessions_sync_day()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'INSERT' then
    perform public.sync_day_flags(old.user_id, old.record_date);
  end if;
  if tg_op <> 'DELETE' then
    perform public.sync_day_flags(new.user_id, new.record_date);
  end if;
  return null;
end;
$$;

drop trigger if exists workout_sessions_sync_day on public.workout_sessions;
create trigger workout_sessions_sync_day
  after insert or update or delete on public.workout_sessions
  for each row execute function public.workout_sessions_sync_day();

-- ---------------------------------------------------------------------------
-- 권한. 종목과 루틴은 기본·템플릿, 내 것, 같은 그룹 친구 것을 본다. 쓰기는 내 것만.
-- ---------------------------------------------------------------------------

create or replace function public.can_see_owner(p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_owner is null or p_owner = auth.uid() or public.share_group(auth.uid(), p_owner);
$$;

create or replace function public.routine_owner(p_routine uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select owner_id from public.routines where id = p_routine;
$$;

create or replace function public.routine_day_owner(p_day uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select r.owner_id
  from public.routine_days d
  join public.routines r on r.id = d.routine_id
  where d.id = p_day;
$$;

create or replace function public.session_owner(p_session uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select user_id from public.workout_sessions where id = p_session;
$$;

alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_days enable row level security;
alter table public.routine_items enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.session_sets enable row level security;

drop policy if exists exercises_select on public.exercises;
create policy exercises_select on public.exercises
  for select using (public.can_see_owner(owner_id));
drop policy if exists exercises_insert on public.exercises;
create policy exercises_insert on public.exercises
  for insert with check (owner_id = auth.uid());
drop policy if exists exercises_update on public.exercises;
create policy exercises_update on public.exercises
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists exercises_delete on public.exercises;
create policy exercises_delete on public.exercises
  for delete using (owner_id = auth.uid());

-- 사용 중 표시는 set_active_routine 으로만 바꾼다 (사람마다 하나).
drop policy if exists routines_select on public.routines;
create policy routines_select on public.routines
  for select using (public.can_see_owner(owner_id));
drop policy if exists routines_insert on public.routines;
create policy routines_insert on public.routines
  for insert with check (owner_id = auth.uid() and template_key is null and not is_active);
drop policy if exists routines_update on public.routines;
create policy routines_update on public.routines
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid() and template_key is null);
drop policy if exists routines_delete on public.routines;
create policy routines_delete on public.routines
  for delete using (owner_id = auth.uid());
revoke update on public.routines from anon, authenticated;
grant update (name, description, sort_order, updated_at) on public.routines to authenticated;

drop policy if exists routine_days_select on public.routine_days;
create policy routine_days_select on public.routine_days
  for select using (public.can_see_owner(public.routine_owner(routine_id)));
drop policy if exists routine_days_write on public.routine_days;
create policy routine_days_write on public.routine_days
  for all using (public.routine_owner(routine_id) = auth.uid())
  with check (public.routine_owner(routine_id) = auth.uid());

drop policy if exists routine_items_select on public.routine_items;
create policy routine_items_select on public.routine_items
  for select using (public.can_see_owner(public.routine_day_owner(day_id)));
drop policy if exists routine_items_write on public.routine_items;
create policy routine_items_write on public.routine_items
  for all using (public.routine_day_owner(day_id) = auth.uid())
  with check (public.routine_day_owner(day_id) = auth.uid());

drop policy if exists workout_sessions_select on public.workout_sessions;
create policy workout_sessions_select on public.workout_sessions
  for select using (user_id = auth.uid() or public.share_group(auth.uid(), user_id));
drop policy if exists workout_sessions_write on public.workout_sessions;
create policy workout_sessions_write on public.workout_sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists session_sets_select on public.session_sets;
create policy session_sets_select on public.session_sets
  for select using (
    public.session_owner(session_id) = auth.uid()
    or public.share_group(auth.uid(), public.session_owner(session_id))
  );
drop policy if exists session_sets_write on public.session_sets;
create policy session_sets_write on public.session_sets
  for all using (public.session_owner(session_id) = auth.uid())
  with check (public.session_owner(session_id) = auth.uid());

-- ---------------------------------------------------------------------------
-- 함수
-- ---------------------------------------------------------------------------

-- 템플릿, 내 루틴, 같은 그룹 친구 루틴을 내 루틴으로 복사한다.
-- p_with_cardio 면 날마다 마지막에 러닝머신 20분을 붙인다. 사용 중인 루틴이 없으면 새 루틴을 사용 중으로 둔다.
create or replace function public.copy_routine(p_source uuid, p_with_cardio boolean default false)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  source public.routines%rowtype;
  new_id uuid;
  src_day record;
  new_day uuid;
  cardio uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into source from public.routines where id = p_source;
  if source.id is null or not public.can_see_owner(source.owner_id) then
    raise exception 'routine not found';
  end if;

  insert into public.routines (owner_id, name, description, is_active, source_routine_id)
  values (
    auth.uid(),
    source.name,
    source.description,
    not exists (select 1 from public.routines where owner_id = auth.uid() and is_active),
    source.id
  )
  returning id into new_id;

  select id into cardio from public.exercises where owner_id is null and name = '러닝머신';

  for src_day in
    select * from public.routine_days where routine_id = source.id order by position
  loop
    insert into public.routine_days (routine_id, position, name)
    values (new_id, src_day.position, src_day.name)
    returning id into new_day;

    insert into public.routine_items (
      day_id, position, exercise_id, target_sets, reps_min, reps_max, target_seconds,
      target_distance_km, target_weight, progression, increment, rest_seconds
    )
    select
      new_day, position, exercise_id, target_sets, reps_min, reps_max, target_seconds,
      target_distance_km, target_weight, progression, increment, rest_seconds
    from public.routine_items
    where day_id = src_day.id;

    if p_with_cardio and cardio is not null then
      insert into public.routine_items (day_id, position, exercise_id, target_sets, target_seconds)
      select new_day, coalesce(max(position), 0) + 1, cardio, 1, 1200
      from public.routine_items
      where day_id = new_day;
    end if;
  end loop;

  return new_id;
end;
$$;

-- 사용 중인 루틴을 바꾼다. null 이면 사용 중인 루틴이 없어진다.
create or replace function public.set_active_routine(p_routine uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_routine is not null
     and not exists (select 1 from public.routines where id = p_routine and owner_id = auth.uid()) then
    raise exception 'routine not found';
  end if;

  update public.routines set is_active = false, updated_at = now()
  where owner_id = auth.uid() and is_active and id is distinct from p_routine;
  update public.routines set is_active = true, updated_at = now()
  where id = p_routine;
end;
$$;

-- 운동 하나와 세트를 한 번에 저장한다. 체크한 세트가 하나도 없으면 저장하지 않는다.
-- p_session: record_date, routine_id, routine_day_id, day_name, started_at, finished_at, duration_minutes, note
-- p_sets: [{exercise_id, exercise_name, item_position, set_number, weight_kg, reps, seconds, distance_km,
--           target_reps, target_seconds, done}]
create or replace function public.save_workout_session(p_session jsonb, p_sets jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(coalesce(p_sets, '[]'::jsonb)) as item
    where coalesce((item->>'done')::boolean, true)
  ) then
    raise exception 'no finished sets';
  end if;

  insert into public.workout_sessions (
    user_id, record_date, routine_id, routine_day_id, day_name,
    started_at, finished_at, duration_minutes, note
  )
  values (
    auth.uid(),
    (p_session->>'record_date')::date,
    nullif(p_session->>'routine_id', '')::uuid,
    nullif(p_session->>'routine_day_id', '')::uuid,
    nullif(p_session->>'day_name', ''),
    nullif(p_session->>'started_at', '')::timestamptz,
    nullif(p_session->>'finished_at', '')::timestamptz,
    coalesce((p_session->>'duration_minutes')::integer, 0),
    nullif(trim(coalesce(p_session->>'note', '')), '')
  )
  returning id into new_id;

  insert into public.session_sets (
    session_id, exercise_id, exercise_name, item_position, set_number,
    weight_kg, reps, seconds, distance_km, target_reps, target_seconds, done
  )
  select
    new_id, s.exercise_id, s.exercise_name, s.item_position, s.set_number,
    s.weight_kg, s.reps, s.seconds, s.distance_km, s.target_reps, s.target_seconds, coalesce(s.done, true)
  from jsonb_to_recordset(p_sets) as s(
    exercise_id uuid, exercise_name text, item_position integer, set_number integer,
    weight_kg numeric, reps integer, seconds integer, distance_km numeric,
    target_reps integer, target_seconds integer, done boolean
  );

  return new_id;
end;
$$;

grant execute on function public.copy_routine(uuid, boolean) to authenticated;
grant execute on function public.set_active_routine(uuid) to authenticated;
grant execute on function public.save_workout_session(jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 기본 종목. 증량 방식·단위·쉬는 시간은 docs/workout-routine-plan.md 6장의 기본값.
-- ---------------------------------------------------------------------------

insert into public.exercises (name, body_part, equipment, measure, progression, increment, rest_seconds, sort_order)
values
  -- 가슴
  ('벤치프레스', 'chest', 'barbell', 'weight_reps', 'weight', 2.5, 150, 101),
  ('인클라인 벤치프레스', 'chest', 'barbell', 'weight_reps', 'weight', 2.5, 150, 102),
  ('덤벨 벤치프레스', 'chest', 'dumbbell', 'weight_reps', 'double', 2, 90, 103),
  ('인클라인 덤벨 프레스', 'chest', 'dumbbell', 'weight_reps', 'double', 2, 90, 104),
  ('체스트 프레스', 'chest', 'machine', 'weight_reps', 'double', 2.5, 90, 105),
  ('펙덱 플라이', 'chest', 'machine', 'weight_reps', 'double', 2.5, 90, 106),
  ('케이블 크로스오버', 'chest', 'cable', 'weight_reps', 'double', 2.5, 90, 107),
  ('딥스', 'chest', 'bodyweight', 'reps', 'reps', 1, 90, 108),
  ('푸시업', 'chest', 'bodyweight', 'reps', 'reps', 1, 90, 109),
  -- 등
  ('데드리프트', 'back', 'barbell', 'weight_reps', 'weight', 5, 180, 201),
  ('풀업', 'back', 'bodyweight', 'reps', 'reps', 1, 90, 202),
  ('친업', 'back', 'bodyweight', 'reps', 'reps', 1, 90, 203),
  ('랫풀다운', 'back', 'machine', 'weight_reps', 'double', 2.5, 90, 204),
  ('바벨 로우', 'back', 'barbell', 'weight_reps', 'weight', 2.5, 150, 205),
  ('원암 덤벨 로우', 'back', 'dumbbell', 'weight_reps', 'double', 2, 90, 206),
  ('시티드 케이블 로우', 'back', 'cable', 'weight_reps', 'double', 2.5, 90, 207),
  ('티바 로우', 'back', 'machine', 'weight_reps', 'double', 2.5, 90, 208),
  ('백 익스텐션', 'back', 'bodyweight', 'reps', 'reps', 1, 90, 209),
  -- 어깨
  ('오버헤드 프레스', 'shoulder', 'barbell', 'weight_reps', 'weight', 2.5, 150, 301),
  ('덤벨 숄더 프레스', 'shoulder', 'dumbbell', 'weight_reps', 'double', 2, 90, 302),
  ('숄더 프레스', 'shoulder', 'machine', 'weight_reps', 'double', 2.5, 90, 303),
  ('사이드 레터럴 레이즈', 'shoulder', 'dumbbell', 'weight_reps', 'double', 2, 90, 304),
  ('프런트 레이즈', 'shoulder', 'dumbbell', 'weight_reps', 'double', 2, 90, 305),
  ('리어 델트 플라이', 'shoulder', 'machine', 'weight_reps', 'double', 2.5, 90, 306),
  ('페이스풀', 'shoulder', 'cable', 'weight_reps', 'double', 2.5, 90, 307),
  ('업라이트 로우', 'shoulder', 'barbell', 'weight_reps', 'weight', 2.5, 150, 308),
  -- 하체
  ('스쿼트', 'legs', 'barbell', 'weight_reps', 'weight', 5, 180, 401),
  ('프런트 스쿼트', 'legs', 'barbell', 'weight_reps', 'weight', 5, 180, 402),
  ('레그 프레스', 'legs', 'machine', 'weight_reps', 'double', 2.5, 90, 403),
  ('루마니안 데드리프트', 'legs', 'barbell', 'weight_reps', 'weight', 5, 180, 404),
  ('런지', 'legs', 'dumbbell', 'weight_reps', 'double', 2, 90, 405),
  ('불가리안 스플릿 스쿼트', 'legs', 'dumbbell', 'weight_reps', 'double', 2, 90, 406),
  ('레그 익스텐션', 'legs', 'machine', 'weight_reps', 'double', 2.5, 90, 407),
  ('레그 컬', 'legs', 'machine', 'weight_reps', 'double', 2.5, 90, 408),
  ('힙 쓰러스트', 'legs', 'barbell', 'weight_reps', 'weight', 5, 180, 409),
  ('카프 레이즈', 'legs', 'machine', 'weight_reps', 'double', 2.5, 90, 410),
  -- 팔
  ('바벨 컬', 'arms', 'barbell', 'weight_reps', 'weight', 2.5, 150, 501),
  ('덤벨 컬', 'arms', 'dumbbell', 'weight_reps', 'double', 2, 90, 502),
  ('해머 컬', 'arms', 'dumbbell', 'weight_reps', 'double', 2, 90, 503),
  ('프리처 컬', 'arms', 'machine', 'weight_reps', 'double', 2.5, 90, 504),
  ('트라이셉스 푸시다운', 'arms', 'cable', 'weight_reps', 'double', 2.5, 90, 505),
  ('오버헤드 트라이셉스 익스텐션', 'arms', 'dumbbell', 'weight_reps', 'double', 2, 90, 506),
  ('라잉 트라이셉스 익스텐션', 'arms', 'barbell', 'weight_reps', 'weight', 2.5, 150, 507),
  ('클로즈그립 벤치프레스', 'arms', 'barbell', 'weight_reps', 'weight', 2.5, 150, 508),
  -- 코어
  ('플랭크', 'core', 'bodyweight', 'time', 'time', 10, 60, 601),
  ('크런치', 'core', 'bodyweight', 'reps', 'reps', 1, 90, 602),
  ('행잉 레그 레이즈', 'core', 'bodyweight', 'reps', 'reps', 1, 90, 603),
  ('케이블 크런치', 'core', 'cable', 'weight_reps', 'double', 2.5, 90, 604),
  ('러시안 트위스트', 'core', 'bodyweight', 'reps', 'reps', 1, 90, 605),
  ('앱 롤아웃', 'core', 'other', 'reps', 'reps', 1, 90, 606),
  -- 유산소
  ('러닝머신', 'cardio', 'machine', 'time_distance', 'none', null, null, 701),
  ('야외 러닝', 'cardio', null, 'time_distance', 'none', null, null, 702),
  ('실내 사이클', 'cardio', 'machine', 'time_distance', 'none', null, null, 703),
  ('천국의 계단', 'cardio', 'machine', 'time', 'none', null, null, 704),
  ('로잉머신', 'cardio', 'machine', 'time_distance', 'none', null, null, 705),
  ('일립티컬', 'cardio', 'machine', 'time', 'none', null, null, 706),
  ('걷기', 'cardio', null, 'time_distance', 'none', null, null, 707),
  ('줄넘기', 'cardio', 'other', 'time', 'none', null, null, 708),
  -- 그 밖의 운동
  ('수영', 'other', null, 'time_distance', 'none', null, null, 801),
  ('필라테스', 'other', null, 'time', 'none', null, null, 802),
  ('요가', 'other', null, 'time', 'none', null, null, 803),
  ('구기운동', 'other', null, 'time', 'none', null, null, 804),
  ('등산', 'other', null, 'time_distance', 'none', null, null, 805)
on conflict (name) where owner_id is null do update set
  body_part = excluded.body_part,
  equipment = excluded.equipment,
  measure = excluded.measure,
  progression = excluded.progression,
  increment = excluded.increment,
  rest_seconds = excluded.rest_seconds,
  sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- 템플릿. 세트 × 횟수만 있고 무게는 첫 운동에서 채운다.
-- 더블 프로그레션 종목은 적힌 횟수부터 +2회까지를 목표 범위로 둔다 (예: 3×10 → 10–12회).
-- 횟수가 비어 있으면 '최대'다.
-- ---------------------------------------------------------------------------

delete from public.routines where template_key is not null;

insert into public.routines (template_key, name, description, sort_order)
values
  ('full_body', '무분할', '전신 A와 B를 번갈아 한다. 주 2–3회 운동에 맞다.', 1),
  ('upper_lower', '2분할', '상체와 하체를 번갈아 한다.', 2),
  ('push_pull_legs', '3분할', '밀기, 당기기, 하체를 돌아가며 한다.', 3),
  ('five_split', '5분할', '가슴, 등, 어깨, 하체, 팔을 하루씩 한다.', 4);

insert into public.routine_days (routine_id, position, name)
select r.id, d.position, d.name
from (
  values
    ('full_body', 1, 'A 전신'),
    ('full_body', 2, 'B 전신'),
    ('upper_lower', 1, 'A 상체'),
    ('upper_lower', 2, 'B 하체'),
    ('push_pull_legs', 1, 'A 밀기'),
    ('push_pull_legs', 2, 'B 당기기'),
    ('push_pull_legs', 3, 'C 하체'),
    ('five_split', 1, 'A 가슴'),
    ('five_split', 2, 'B 등'),
    ('five_split', 3, 'C 어깨'),
    ('five_split', 4, 'D 하체'),
    ('five_split', 5, 'E 팔')
) as d(template_key, position, name)
join public.routines r on r.template_key = d.template_key;

insert into public.routine_items (day_id, position, exercise_id, target_sets, reps_min, reps_max, target_seconds)
select
  rd.id,
  i.position,
  e.id,
  i.sets,
  i.reps,
  case when e.progression = 'double' then i.reps + 2 else i.reps end,
  i.seconds
from (
  values
    -- 무분할
    ('full_body', 1, 1, '스쿼트', 3, 8, null),
    ('full_body', 1, 2, '벤치프레스', 3, 8, null),
    ('full_body', 1, 3, '바벨 로우', 3, 8, null),
    ('full_body', 1, 4, '오버헤드 프레스', 3, 10, null),
    ('full_body', 1, 5, '플랭크', 3, null, 60),
    ('full_body', 2, 1, '데드리프트', 3, 5, null),
    ('full_body', 2, 2, '인클라인 덤벨 프레스', 3, 10, null),
    ('full_body', 2, 3, '랫풀다운', 3, 10, null),
    ('full_body', 2, 4, '런지', 3, 10, null),
    ('full_body', 2, 5, '행잉 레그 레이즈', 3, 12, null),
    -- 2분할
    ('upper_lower', 1, 1, '벤치프레스', 4, 8, null),
    ('upper_lower', 1, 2, '바벨 로우', 4, 8, null),
    ('upper_lower', 1, 3, '덤벨 숄더 프레스', 3, 10, null),
    ('upper_lower', 1, 4, '랫풀다운', 3, 10, null),
    ('upper_lower', 1, 5, '덤벨 컬', 3, 12, null),
    ('upper_lower', 1, 6, '트라이셉스 푸시다운', 3, 12, null),
    ('upper_lower', 2, 1, '스쿼트', 4, 8, null),
    ('upper_lower', 2, 2, '루마니안 데드리프트', 4, 10, null),
    ('upper_lower', 2, 3, '레그 프레스', 3, 12, null),
    ('upper_lower', 2, 4, '레그 컬', 3, 12, null),
    ('upper_lower', 2, 5, '카프 레이즈', 3, 15, null),
    ('upper_lower', 2, 6, '플랭크', 3, null, 60),
    -- 3분할
    ('push_pull_legs', 1, 1, '벤치프레스', 4, 8, null),
    ('push_pull_legs', 1, 2, '인클라인 덤벨 프레스', 3, 10, null),
    ('push_pull_legs', 1, 3, '오버헤드 프레스', 3, 8, null),
    ('push_pull_legs', 1, 4, '사이드 레터럴 레이즈', 3, 15, null),
    ('push_pull_legs', 1, 5, '트라이셉스 푸시다운', 3, 12, null),
    ('push_pull_legs', 2, 1, '데드리프트', 3, 5, null),
    ('push_pull_legs', 2, 2, '랫풀다운', 4, 10, null),
    ('push_pull_legs', 2, 3, '바벨 로우', 3, 8, null),
    ('push_pull_legs', 2, 4, '페이스풀', 3, 15, null),
    ('push_pull_legs', 2, 5, '해머 컬', 3, 12, null),
    ('push_pull_legs', 3, 1, '스쿼트', 4, 8, null),
    ('push_pull_legs', 3, 2, '레그 프레스', 3, 12, null),
    ('push_pull_legs', 3, 3, '루마니안 데드리프트', 3, 10, null),
    ('push_pull_legs', 3, 4, '레그 익스텐션', 3, 12, null),
    ('push_pull_legs', 3, 5, '카프 레이즈', 4, 15, null),
    -- 5분할
    ('five_split', 1, 1, '벤치프레스', 4, 8, null),
    ('five_split', 1, 2, '인클라인 덤벨 프레스', 3, 10, null),
    ('five_split', 1, 3, '펙덱 플라이', 3, 12, null),
    ('five_split', 1, 4, '딥스', 3, null, null),
    ('five_split', 2, 1, '데드리프트', 3, 5, null),
    ('five_split', 2, 2, '풀업', 3, null, null),
    ('five_split', 2, 3, '바벨 로우', 3, 8, null),
    ('five_split', 2, 4, '시티드 케이블 로우', 3, 10, null),
    ('five_split', 2, 5, '랫풀다운', 3, 10, null),
    ('five_split', 3, 1, '오버헤드 프레스', 4, 8, null),
    ('five_split', 3, 2, '사이드 레터럴 레이즈', 4, 15, null),
    ('five_split', 3, 3, '리어 델트 플라이', 3, 15, null),
    ('five_split', 3, 4, '페이스풀', 3, 15, null),
    ('five_split', 4, 1, '스쿼트', 4, 8, null),
    ('five_split', 4, 2, '레그 프레스', 3, 12, null),
    ('five_split', 4, 3, '루마니안 데드리프트', 3, 10, null),
    ('five_split', 4, 4, '레그 컬', 3, 12, null),
    ('five_split', 4, 5, '카프 레이즈', 4, 15, null),
    ('five_split', 5, 1, '바벨 컬', 3, 10, null),
    ('five_split', 5, 2, '해머 컬', 3, 12, null),
    ('five_split', 5, 3, '트라이셉스 푸시다운', 3, 12, null),
    ('five_split', 5, 4, '오버헤드 트라이셉스 익스텐션', 3, 12, null)
) as i(template_key, day_position, position, exercise_name, sets, reps, seconds)
join public.routines r on r.template_key = i.template_key
join public.routine_days rd on rd.routine_id = r.id and rd.position = i.day_position
join public.exercises e on e.owner_id is null and e.name = i.exercise_name;

-- 확인용: 템플릿마다 날과 종목 수
-- select r.name, d.position, d.name, count(i.id)
-- from public.routines r join public.routine_days d on d.routine_id = r.id
-- left join public.routine_items i on i.day_id = d.id
-- where r.template_key is not null group by 1, 2, 3 order by r.sort_order, d.position;
