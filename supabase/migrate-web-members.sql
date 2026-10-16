-- 웹 MVP를 앱 전용 DB로 복사한 뒤에만 실행한다.
-- 원본 웹 프로젝트에는 실행하지 않는다.
-- 복사본의 기존 테이블은 legacy 스키마에 있다고 가정한다.
--   create schema if not exists legacy;
--   alter table public.profiles set schema legacy;  (덤프를 legacy로 복구한 경우)
-- schema.sql, patch-permissions.sql 을 먼저 실행한 뒤 돌린다.
-- 날짜 기준은 한국 시간이다 (Supabase 서버의 current_date 는 UTC).

begin;

-- 이관 중에는 점수·지갑 트리거를 끄고, 아래 3단계에서 한 번에 다시 계산한다.
alter table public.daily_records disable trigger daily_records_points;
alter table public.daily_records disable trigger daily_records_wallet;

-- 1. 같은 사용자·같은 날짜 기록을 하나로 합친다.
--    칸마다 가장 늦게 수정된 행의 값을 쓰고, 그 행이 비어 있으면 다른 행 중 가장 늦은 값으로 채운다.
--    id 는 가장 늦게 수정된 행의 것을 남긴다. 탈락한 행의 사진 파일은 스토리지에 그대로 둔다.
insert into public.daily_records (
  id, user_id, record_date, weight, body_photo_url, memo,
  workout_minutes, points_earned, created_at, updated_at
)
select
  merged.id,
  merged.user_id,
  merged.record_date,
  merged.weight,
  merged.photo_url,
  merged.memo,
  merged.workout_minutes,
  0,
  merged.created_at,
  merged.updated_at
from (
  select
    user_id,
    record_date,
    (array_agg(id order by updated_at desc))[1] as id,
    (array_agg(weight order by updated_at desc) filter (where weight is not null))[1] as weight,
    (array_agg(photo_url order by updated_at desc)
      filter (where nullif(photo_url, '') is not null))[1] as photo_url,
    (array_agg(memo order by updated_at desc)
      filter (where nullif(trim(memo), '') is not null))[1] as memo,
    (array_agg(workout_minutes order by updated_at desc)
      filter (where workout_minutes is not null))[1] as workout_minutes,
    min(created_at) as created_at,
    max(updated_at) as updated_at
  from legacy.daily_records
  group by user_id, record_date
) merged
on conflict (user_id, record_date) do nothing;

-- 2. 탈락한 기록의 찌르기는 남은 기록으로 옮긴다. 새 찌르기 테이블은 기록 대신 그룹에 붙는다.
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

-- 3. 하루 점수를 다시 매기고, 지갑은 합쳐진 하루 점수의 합으로 다시 계산한다.
--    웹 기록에는 운동 종류가 없으므로 운동 시간이 있으면 운동한 날로 본다.
--    주간 점수와 그룹 스트릭은 가져오지 않는다.
update public.daily_records
set points_earned =
  (case when weight is not null then 10 else 0 end)
  + (case when body_photo_url is not null then 15 else 0 end)
  + (case when meal_photo_url is not null then 15 else 0 end)
  + (case when workout_minutes is not null or coalesce(cardinality(workout_kinds), 0) > 0 then 20 else 0 end)
  + (case when coalesce(workout_minutes, 0) >= 30
           and workout_kinds is distinct from array['rest']::text[] then 5 else 0 end)
  + (case when weight is not null and body_photo_url is not null
           and (workout_minutes is not null or coalesce(cardinality(workout_kinds), 0) > 0) then 15 else 0 end);

update public.profiles profile
set wallet_points = coalesce((
  select sum(points_earned) from public.daily_records record
  where record.user_id = profile.id
), 0);

-- 4. 스트릭은 오늘 또는 어제까지 이어진 연속 출석만 남긴다. 그보다 오래 쉬었으면 0.
with numbered as (
  select
    user_id,
    record_date,
    record_date - (row_number() over (partition by user_id order by record_date))::int as run_key
  from public.daily_records
),
runs as (
  select user_id, max(record_date) as last_day, count(*)::int as days
  from numbered
  group by user_id, run_key
),
latest as (
  select distinct on (user_id) user_id, last_day, days
  from runs
  order by user_id, last_day desc
)
update public.profiles profile
set
  last_attend_date = latest.last_day,
  streak_days = case
    when latest.last_day >= (now() at time zone 'Asia/Seoul')::date - 1 then latest.days
    else 0
  end
from latest
where profile.id = latest.user_id;

update public.profiles
set streak_days = 0, last_attend_date = null
where not exists (
  select 1 from public.daily_records record where record.user_id = profiles.id
);

alter table public.daily_records enable trigger daily_records_points;
alter table public.daily_records enable trigger daily_records_wallet;

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

commit;
