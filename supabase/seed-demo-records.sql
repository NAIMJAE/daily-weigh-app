-- 기록 화면 확인용 더미 데이터. 앱 전용 테스트 프로젝트에서만 실행한다. 운영 DB에는 실행하지 않는다.
-- 대상은 아래 demo_user 의 username 한 명이고, 오늘 포함 최근 35일을 채운다.
-- 1) 끼니별 식단 (meal_entries). 사진 없이 메뉴만 둔다. 앱은 바깥 이미지 주소를 보여 주지 않고,
--    patch-security.sql 이후로는 내 저장소에 올린 사진만 넣을 수 있다. 예전에 넣은 바깥 주소는 다시 실행하면 지워진다.
-- 2) 운동. 이미 있는 하루 기록 중 운동이 비어 있는 날에만 넣는다. 새 하루 기록은 만들지 않는다.
--    운동을 넣으면 점수 트리거가 그 날 점수와 지갑을 다시 계산한다. 스트릭은 바뀌지 않는다.
-- 다시 실행해도 된다. 식단은 같은 값으로 덮고, 운동은 비어 있는 날에만 들어간다.

begin;

with demo_user as (
  select id from public.profiles where username = 'demo01'
),
days as (
  select n, (now() at time zone 'Asia/Seoul')::date - n as day
  from generate_series(0, 34) as n
),
notes(slot, texts) as (
  values
    ('breakfast', array['그릭요거트에 바나나', '통밀 토스트랑 계란 두 개', '오트밀에 블루베리', '샐러드랑 삶은 계란', '고구마 하나랑 우유']),
    ('lunch', array['회사 근처 비빔밥', '닭가슴살 샐러드', '김치찌개, 밥은 반 공기', '연어 포케', '파스타 반만 먹음', '제육볶음 정식']),
    ('dinner', array['된장국이랑 생선구이', '닭가슴살 스테이크', '소고기 샐러드', '두부 샐러드랑 현미밥', '친구랑 삼겹살 (치팅)', '샤브샤브']),
    ('snack', array['아몬드 한 줌', '프로틴 쉐이크', '사과 하나', '아메리카노에 쿠키 하나'])
),
slots(slot, i) as (
  values ('breakfast', 0), ('lunch', 1), ('dinner', 2), ('snack', 3)
)
insert into public.meal_entries (user_id, record_date, slot, photo_url, description, updated_at)
select
  demo_user.id,
  days.day,
  slots.slot,
  null,
  notes.texts[1 + (days.n * 5 + slots.i) % cardinality(notes.texts)],
  now()
from demo_user
cross join days
cross join slots
join notes on notes.slot = slots.slot
where
  -- 끼니마다 가끔 건너뛰고, 간식은 사흘에 한 번만 먹는다. 오늘은 아침·점심만 있다.
  (days.n * 7 + slots.i * 3) % 5 <> 0
  and (slots.slot <> 'snack' or days.n % 3 = 1)
  and (days.n > 0 or slots.slot in ('breakfast', 'lunch'))
on conflict (user_id, record_date, slot) do update set
  photo_url = excluded.photo_url,
  description = excluded.description,
  updated_at = excluded.updated_at;

with demo_user as (
  select id from public.profiles where username = 'demo01'
),
plan as (
  select
    record.id,
    ((now() at time zone 'Asia/Seoul')::date - record.record_date) % 7 as k,
    ((now() at time zone 'Asia/Seoul')::date - record.record_date) % 4 as m
  from public.daily_records record
  join demo_user on demo_user.id = record.user_id
  where record.record_date > (now() at time zone 'Asia/Seoul')::date - 35
    and record.workout_kinds is null
)
update public.daily_records record
set
  workout_kinds = case plan.k
    when 0 then array['rest']
    when 1 then array['gym']
    when 2 then array['cardio', 'walk']
    when 4 then array['gym', 'cardio']
    when 5 then array['home']
    when 6 then array['pilates']
  end,
  workout_minutes = case when plan.k in (0, 3) then null else (array[30, 45, 60, 40])[1 + plan.m] end,
  updated_at = now()
from plan
where record.id = plan.id
  and plan.k <> 3;

commit;

-- 확인용
-- select record_date, slot, description from public.meal_entries
-- where user_id = (select id from public.profiles where username = 'demo01') order by record_date desc, slot;
