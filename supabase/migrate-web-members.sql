-- 웹 MVP를 앱 전용 DB로 복사한 뒤에만 실행한다.
-- 원본 웹 프로젝트에는 실행하지 않는다.
-- 복사본의 기존 테이블은 legacy 스키마에 있다고 가정한다.
--   create schema if not exists legacy;
--   alter table public.profiles set schema legacy;  (덤프를 legacy로 복구한 경우)

-- 1. 같은 사용자·같은 날짜 기록을 하나로 합친다.
--    빈 칸은 다른 행으로 채우고, 값이 다르면 updated_at이 늦은 행을 남긴다.
create table if not exists public.daily_records (
  id uuid primary key,
  user_id uuid not null,
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
  unique (user_id, record_date)
);

insert into public.daily_records (
  id, user_id, record_date, weight, body_photo_url, memo,
  workout_minutes, points_earned, created_at, updated_at
)
select distinct on (user_id, record_date)
  id,
  user_id,
  record_date,
  weight,
  photo_url,
  memo,
  workout_minutes,
  0,
  created_at,
  updated_at
from legacy.daily_records
order by user_id, record_date, updated_at desc
on conflict (user_id, record_date) do update set
  weight = coalesce(public.daily_records.weight, excluded.weight),
  body_photo_url = coalesce(public.daily_records.body_photo_url, excluded.body_photo_url),
  memo = coalesce(public.daily_records.memo, excluded.memo),
  workout_minutes = coalesce(public.daily_records.workout_minutes, excluded.workout_minutes),
  updated_at = greatest(public.daily_records.updated_at, excluded.updated_at);

-- 값이 충돌하면 더 늦게 수정된 행을 다시 덮는다.
update public.daily_records target
set
  weight = winner.weight,
  body_photo_url = coalesce(winner.photo_url, target.body_photo_url),
  memo = coalesce(winner.memo, target.memo),
  updated_at = winner.updated_at
from (
  select distinct on (user_id, record_date) *
  from legacy.daily_records
  order by user_id, record_date, updated_at desc
) winner
where target.user_id = winner.user_id
  and target.record_date = winner.record_date;

-- 2. 탈락한 기록의 찌르기는 남은 기록으로 옮긴다. 사진 파일은 스토리지에 둔다.
insert into public.pokes (id, group_id, sender_id, receiver_id, created_at)
select
  p.id,
  p.group_id,
  p.sender_id,
  p.receiver_id,
  p.created_at
from legacy.pokes p
join legacy.daily_records dropped on dropped.id = p.record_id
join public.daily_records kept
  on kept.user_id = dropped.user_id
 and kept.record_date = dropped.record_date
on conflict (id) do nothing;

-- 3. 지갑은 합쳐진 하루 점수로 다시 계산한다. 주간 점수와 그룹 스트릭은 가져오지 않는다.
update public.profiles profile
set wallet_points = coalesce(scored.total, 0)
from (
  select user_id, sum(
    (case when weight is not null then 10 else 0 end)
    + (case when body_photo_url is not null then 15 else 0 end)
    + (case when meal_photo_url is not null then 15 else 0 end)
    + (case when workout_minutes is not null or coalesce(cardinality(workout_kinds), 0) > 0 then 20 else 0 end)
    + (case when coalesce(workout_minutes, 0) >= 30
             and workout_kinds is distinct from array['rest']::text[] then 5 else 0 end)
    + (case when weight is not null and body_photo_url is not null
             and (workout_minutes is not null or coalesce(cardinality(workout_kinds), 0) > 0) then 15 else 0 end)
  ) as total
  from public.daily_records
  group by user_id
) scored
where profile.id = scored.user_id;

-- 4. 스트릭은 오늘 또는 어제까지 이어진 연속만 남긴다.
update public.profiles
set streak_days = 0, last_attend_date = null
where last_attend_date is null
   or last_attend_date < (current_date - 1);

-- 5. 기존 그룹은 친구 그룹으로 남긴다. 개인 그룹으로 바꾸지 않는다.
update public.groups
set is_personal = false
where is_personal is distinct from true;

-- 6. 그룹이 없던 회원에게만 개인 그룹을 만든다.
insert into public.groups (name, is_personal, created_by)
select '나만의 그룹', true, profile.id
from public.profiles profile
where not exists (
  select 1 from public.group_members member where member.user_id = profile.id
)
and not exists (
  select 1 from public.groups personal
  where personal.created_by = profile.id and personal.is_personal
);

insert into public.group_members (group_id, user_id, role)
select groups.id, groups.created_by, 'owner'
from public.groups groups
where groups.is_personal
  and groups.created_by is not null
  and not exists (
    select 1 from public.group_members member
    where member.group_id = groups.id and member.user_id = groups.created_by
  );
