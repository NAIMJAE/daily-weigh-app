-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-meal-entries.sql 다음에 실행한다.
-- 1) 끼니별 식단이 하루 기록의 출석과 점수에 들어가게 한다. 끼니가 하나라도 있으면 daily_records.has_meal 이 켜진다.
-- 2) 어제 기록을 나중에 채워도 스트릭이 맞도록, 스트릭을 하루 기록에서 다시 센다.
-- 3) 끼니에 빠른 태그(집밥, 외식 …)를 둔다.
-- 다시 실행해도 된다.

-- ---------------------------------------------------------------------------
-- 칸
-- ---------------------------------------------------------------------------

alter table public.meal_entries add column if not exists tags text[];
alter table public.meal_entries drop constraint if exists meal_entries_tags_known;
alter table public.meal_entries add constraint meal_entries_tags_known check (
  tags is null
  or tags <@ array['home', 'eatout', 'delivery', 'salad', 'simple', 'cheat']::text[]
);

alter table public.daily_records add column if not exists has_meal boolean not null default false;
alter table public.daily_records drop constraint if exists daily_records_at_least_one;
alter table public.daily_records add constraint daily_records_at_least_one check (
  weight is not null
  or body_photo_url is not null
  or meal_photo_url is not null
  or has_meal
  or (workout_kinds is not null and cardinality(workout_kinds) > 0)
  or (memo is not null and length(trim(memo)) > 0)
);

-- ---------------------------------------------------------------------------
-- 점수. 식단은 예전 식단 사진이나 끼니 기록 중 하나만 있어도 하루 한 번 +15.
-- ---------------------------------------------------------------------------

drop function if exists public.compute_record_points(numeric, text, text, text[], integer);
create or replace function public.compute_record_points(
  p_weight numeric,
  p_body text,
  p_meal text,
  p_kinds text[],
  p_minutes integer,
  p_has_meal boolean
)
returns integer
language sql
immutable
as $$
  select
    (case when p_weight is not null then 10 else 0 end)
    + (case when nullif(p_body, '') is not null then 15 else 0 end)
    + (case when nullif(p_meal, '') is not null or coalesce(p_has_meal, false) then 15 else 0 end)
    + (case when coalesce(cardinality(p_kinds), 0) > 0 then
         20 + (case when p_kinds <> array['rest']::text[] and coalesce(p_minutes, 0) >= 30 then 5 else 0 end)
       else 0 end)
    + (case when p_weight is not null
             and nullif(p_body, '') is not null
             and coalesce(cardinality(p_kinds), 0) > 0 then 15 else 0 end);
$$;

create or replace function public.daily_records_set_points()
returns trigger
language plpgsql
as $$
begin
  new.points_earned := public.compute_record_points(
    new.weight, new.body_photo_url, new.meal_photo_url, new.workout_kinds, new.workout_minutes, new.has_meal
  );
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 스트릭. 가장 최근 날짜로 끝나는 연속 출석 일수. 오래 쉬었는지는 reconcile_my_streak 이 앱을 열 때 본다.
-- ---------------------------------------------------------------------------

create or replace function public.recompute_streak(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  with numbered as (
    select record_date, record_date - (row_number() over (order by record_date))::int as run_key
    from public.daily_records
    where user_id = p_user
  ),
  latest as (
    select max(record_date) as last_day, count(*)::int as days
    from numbered
    group by run_key
    order by last_day desc
    limit 1
  )
  update public.profiles set
    streak_days = coalesce((select days from latest), 0),
    last_attend_date = (select last_day from latest),
    updated_at = now()
  where id = p_user;
$$;

create or replace function public.daily_records_apply_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  prev_points integer := 0;
begin
  if tg_op = 'UPDATE' then
    prev_points := old.points_earned;
  end if;

  update public.profiles set
    wallet_points = wallet_points + new.points_earned - prev_points,
    updated_at = now()
  where id = new.user_id;

  perform public.recompute_streak(new.user_id);
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 끼니가 바뀌면 그 날 하루 기록의 has_meal 을 맞춘다.
-- 마지막 끼니를 지웠는데 그 날 다른 기록이 없으면 하루 기록을 지우고 점수를 돌려놓는다.
-- ---------------------------------------------------------------------------

create or replace function public.meal_entries_sync_day()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := coalesce(new.user_id, old.user_id);
  day date := coalesce(new.record_date, old.record_date);
  rec public.daily_records%rowtype;
begin
  if exists (select 1 from public.meal_entries where user_id = uid and record_date = day) then
    insert into public.daily_records (user_id, record_date, has_meal)
    values (uid, day, true)
    on conflict (user_id, record_date) do update
      set has_meal = true, updated_at = now()
      where public.daily_records.has_meal is distinct from true;
    return null;
  end if;

  select * into rec from public.daily_records where user_id = uid and record_date = day;
  if rec.id is null or not rec.has_meal then
    return null;
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
    where id = uid;
    perform public.recompute_streak(uid);
  else
    update public.daily_records set has_meal = false, updated_at = now() where id = rec.id;
  end if;
  return null;
end;
$$;

drop trigger if exists meal_entries_sync_day on public.meal_entries;
create trigger meal_entries_sync_day
  after insert or update or delete on public.meal_entries
  for each row execute function public.meal_entries_sync_day();

-- ---------------------------------------------------------------------------
-- 이미 있는 끼니를 하루 기록에 반영하고, 모든 사람의 스트릭을 새 방식으로 다시 센다.
-- ---------------------------------------------------------------------------

insert into public.daily_records (user_id, record_date, has_meal)
select distinct user_id, record_date, true
from public.meal_entries
on conflict (user_id, record_date) do update
  set has_meal = true, updated_at = now()
  where public.daily_records.has_meal is distinct from true;

select public.recompute_streak(id) from public.profiles;
