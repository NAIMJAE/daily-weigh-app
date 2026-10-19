-- Google Play 심사용 계정(playreview)을 채운다. 계정은 앱 가입으로 먼저 만들어 둔다.
-- 1) demo01 이 있는 친구 그룹(민지·준호)에 멤버로 넣는다.
-- 2) 어제까지 14일 동안의 체중과 끼니(식사 종류 포함), 운동 표시를 넣는다. 오늘은 비워 둬서
--    심사자가 홈의 '오늘 할 일'에서 직접 기록해 볼 수 있게 한다.
-- 다시 실행해도 된다. 같은 날 기록은 새 값으로 덮는다.

begin;

do $$
declare
  reviewer uuid := (select id from public.profiles where username = 'playreview');
  friend_group uuid;
begin
  if reviewer is null then
    raise exception 'playreview 계정을 먼저 만들어 주세요';
  end if;

  select g.id into friend_group
  from public.groups g
  join public.group_members m on m.group_id = g.id
  join public.profiles demo on demo.id = m.user_id and demo.username = 'demo01'
  where not g.is_personal
  order by g.created_at
  limit 1;
  if friend_group is null then
    raise exception 'demo01 의 친구 그룹을 찾지 못했어요';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (friend_group, reviewer, 'member')
  on conflict (group_id, user_id) do nothing;
end $$;

-- 체중: 78kg 에서 하루 0.1kg 안팎으로 조금씩 줄어든다. 운동은 이틀에 한 번.
with reviewer as (
  select id from public.profiles where username = 'playreview'
),
days as (
  select n, (now() at time zone 'Asia/Seoul')::date - n as day
  from generate_series(1, 14) as n
)
insert into public.daily_records (user_id, record_date, weight, workout_kinds, workout_minutes, updated_at)
select
  reviewer.id,
  days.day,
  round((76.6 + days.n * 0.1 + ((days.n * 7) % 5 - 2) * 0.1)::numeric, 1),
  case when days.n % 2 = 0 then array['gym'] when days.n % 7 = 3 then array['rest'] end,
  case when days.n % 2 = 0 then 45 end,
  now()
from reviewer
cross join days
on conflict (user_id, record_date) do update set
  weight = excluded.weight,
  workout_kinds = excluded.workout_kinds,
  workout_minutes = excluded.workout_minutes,
  updated_at = excluded.updated_at;

with reviewer as (
  select id from public.profiles where username = 'playreview'
),
days as (
  select n, (now() at time zone 'Asia/Seoul')::date - n as day
  from generate_series(1, 14) as n
),
slots(slot, i) as (
  values ('breakfast', 0), ('lunch', 1), ('dinner', 2), ('snack', 3)
),
menus(slot, categories, texts) as (
  values
    ('breakfast', array['home', 'simple', 'salad'], array['계란 두 개와 토스트', '바나나와 우유', '그릭요거트 샐러드']),
    ('lunch', array['eatout', 'home', 'salad', 'eatout'], array['회사 앞 비빔밥', '도시락', '닭가슴살 샐러드', '김치찌개 정식']),
    ('dinner', array['home', 'delivery', 'home', 'cheat', 'eatout'], array['현미밥과 생선구이', '포케 배달', '두부 된장찌개', '치킨 반 마리', '샤브샤브']),
    ('snack', array['simple'], array['아몬드 한 줌'])
)
insert into public.meal_entries (user_id, record_date, slot, description, category, updated_at)
select
  reviewer.id,
  days.day,
  slots.slot,
  menus.texts[1 + (days.n * 11 + slots.i) % cardinality(menus.texts)],
  menus.categories[1 + (days.n * 11 + slots.i) % cardinality(menus.categories)],
  now()
from reviewer
cross join days
cross join slots
join menus on menus.slot = slots.slot
where (slots.slot <> 'snack' or days.n % 3 = 1)
  and (slots.slot <> 'breakfast' or days.n % 4 <> 0)
on conflict (user_id, record_date, slot) do update set
  description = excluded.description,
  category = excluded.category,
  updated_at = excluded.updated_at;

commit;

-- 확인용
-- select g.name, p.nickname from public.group_members m join public.groups g on g.id = m.group_id
-- join public.profiles p on p.id = m.user_id
-- where m.group_id in (select group_id from public.group_members gm join public.profiles pp on pp.id = gm.user_id where pp.username = 'playreview');
