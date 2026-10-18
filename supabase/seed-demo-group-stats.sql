-- 통계의 '그룹 전체' 보기(멤버별 식사 종류, 멤버별 볼륨)를 확인하기 위한 더미 데이터.
-- 앱 전용 테스트 프로젝트에서만 실행한다. 운영 DB에는 실행하지 않는다.
-- patch-meal-category.sql 다음에 실행한다.
--
-- 대상은 demo01 과 같은 그룹의 '민지'와 '준호'이고, 어제까지 최근 6주를 채운다.
-- 1) 끼니 (meal_entries). 사진 없이 메뉴와 식사 종류만 둔다.
--    민지는 집밥·샐러드 위주, 준호는 배달·외식·치팅이 많다. 다시 실행하면 같은 끼니를 덮는다.
-- 2) 운동 (workout_sessions, session_sets). 민지는 주 3번, 준호는 주 2번 한다.
--    무게는 주마다 조금씩 오른다. 준호는 시작 무게가 크고, 민지는 더 빨리 는다(증가율 비교용).
--    note 가 'seed:group-stats' 인 운동은 다시 실행할 때 지우고 새로 넣는다.
--
-- 끼니와 운동을 넣으면 서버 트리거가 두 사람의 하루 기록(식단·운동 표시, 점수)을 맞춘다.
-- 다시 실행해도 된다.

begin;

-- ---------------------------------------------------------------------------
-- 1) 끼니
-- ---------------------------------------------------------------------------

with friends as (
  select distinct p.id, p.nickname
  from public.profiles p
  join public.group_members them on them.user_id = p.id
  join public.group_members me on me.group_id = them.group_id
  join public.profiles demo on demo.id = me.user_id and demo.username = 'demo01'
  where p.nickname in ('민지', '준호')
),
days as (
  select n, (now() at time zone 'Asia/Seoul')::date - n as day
  from generate_series(1, 42) as n
),
slots(slot, i) as (
  values ('breakfast', 0), ('lunch', 1), ('dinner', 2), ('snack', 3)
),
-- 사람·끼니마다 고를 종류와 메뉴. 같은 종류가 여러 번 들어가 있으면 그만큼 자주 나온다.
menus(nickname, slot, categories, texts) as (
  values
    ('민지', 'breakfast', array['home', 'salad', 'home', 'simple'],
      array['그릭요거트와 그래놀라', '닭가슴살 샐러드', '현미밥과 계란말이', '바나나 단백질 쉐이크']),
    ('민지', 'lunch', array['salad', 'home', 'eatout', 'salad', 'home'],
      array['연어 포케', '도시락 (현미밥, 불고기)', '회사 앞 비빔밥', '리코타 샐러드', '두부 조림 정식']),
    ('민지', 'dinner', array['home', 'home', 'salad', 'eatout', 'home', 'delivery'],
      array['고등어구이 정식', '닭가슴살 볶음밥', '샐러드와 고구마', '친구와 샤브샤브', '된장찌개', '포케 배달']),
    ('민지', 'snack', array['simple', 'home'],
      array['프로틴바', '방울토마토']),
    ('준호', 'breakfast', array['simple', 'simple', 'eatout'],
      array['편의점 삼각김밥', '컵라면', '토스트 가게']),
    ('준호', 'lunch', array['eatout', 'eatout', 'delivery', 'home'],
      array['제육볶음 백반', '국밥', '햄버거 세트', '김치볶음밥']),
    ('준호', 'dinner', array['delivery', 'cheat', 'eatout', 'home', 'delivery', 'cheat'],
      array['치킨 반반', '피자와 콜라', '삼겹살', '라면과 계란', '족발', '곱창']),
    ('준호', 'snack', array['cheat', 'simple', 'cheat'],
      array['아이스크림', '과자 한 봉지', '맥주와 안주'])
)
insert into public.meal_entries (user_id, record_date, slot, description, category, updated_at)
select
  friends.id,
  days.day,
  slots.slot,
  menus.texts[1 + (days.n * 11 + slots.i) % cardinality(menus.texts)],
  menus.categories[1 + (days.n * 7 + slots.i * 2) % cardinality(menus.categories)],
  now()
from friends
cross join days
cross join slots
join menus on menus.nickname = friends.nickname and menus.slot = slots.slot
where
  -- 민지는 아침을 가끔, 준호는 자주 거른다. 간식은 사흘에 한 번쯤.
  case friends.nickname
    when '민지' then (days.n * 7 + slots.i * 3) % 6 <> 0
    else slots.slot <> 'breakfast' or days.n % 3 = 0
  end
  and (slots.slot <> 'snack' or days.n % 3 = 1)
-- 민지·준호는 테스트용 계정이라, 다시 실행하면 같은 끼니를 새 값으로 덮는다.
on conflict (user_id, record_date, slot) do update set
  description = excluded.description,
  category = excluded.category,
  updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- 2) 운동
-- ---------------------------------------------------------------------------

delete from public.workout_sessions where note = 'seed:group-stats';

do $$
declare
  friend record;
  plan record;
  n integer;
  day_date date;
  week_index integer;
  new_session uuid;
  today date := (now() at time zone 'Asia/Seoul')::date;
begin
  for friend in
    select distinct p.id, p.nickname
    from public.profiles p
    join public.group_members them on them.user_id = p.id
    join public.group_members me on me.group_id = them.group_id
    join public.profiles demo on demo.id = me.user_id and demo.username = 'demo01'
    where p.nickname in ('민지', '준호')
  loop
    for n in 1..42 loop
      day_date := today - n;
      -- 민지는 월·수·금, 준호는 화·토에 운동한다.
      if (friend.nickname = '민지' and extract(isodow from day_date) not in (1, 3, 5))
        or (friend.nickname = '준호' and extract(isodow from day_date) not in (2, 6)) then
        continue;
      end if;
      -- 이미 그날 운동이 있으면(앞서 넣은 어제 운동 등) 건너뛴다.
      if exists (select 1 from public.workout_sessions where user_id = friend.id and record_date = day_date) then
        continue;
      end if;
      -- 오래된 주가 0. 주마다 무게가 오른다.
      week_index := (42 - n) / 7;

      insert into public.workout_sessions (user_id, record_date, day_name, started_at, finished_at, duration_minutes, note)
      values (
        friend.id,
        day_date,
        case when friend.nickname = '민지' then '전신' else '파워' end,
        (day_date + time '19:00') at time zone 'Asia/Seoul',
        (day_date + time '19:50') at time zone 'Asia/Seoul',
        50,
        'seed:group-stats'
      )
      returning id into new_session;

      -- 종목마다 4세트. 시작 무게에 주마다 오르는 비율(민지 5%, 준호 2%)을 곱해 2.5kg 단위로 맞춘다.
      for plan in
        select *
        from (
          values
            ('민지', 0, '스쿼트', 40.0, 10, 0.05),
            ('민지', 1, '벤치프레스', 25.0, 10, 0.05),
            ('민지', 2, '랫풀다운', 30.0, 12, 0.05),
            ('준호', 0, '데드리프트', 100.0, 5, 0.02),
            ('준호', 1, '벤치프레스', 70.0, 6, 0.02),
            ('준호', 2, '바벨 로우', 60.0, 8, 0.02)
        ) as t(nickname, item_position, exercise_name, start_kg, reps, weekly_gain)
        where t.nickname = friend.nickname
      loop
        insert into public.session_sets (
          session_id, exercise_id, exercise_name, item_position, set_number, weight_kg, reps, target_reps, done
        )
        select
          new_session,
          (select e.id from public.exercises e where e.name = plan.exercise_name and e.owner_id is null limit 1),
          plan.exercise_name,
          plan.item_position,
          set_number,
          round(plan.start_kg * (1 + plan.weekly_gain * week_index) / 2.5) * 2.5,
          plan.reps,
          plan.reps,
          true
        from generate_series(1, 4) as set_number;
      end loop;
    end loop;
  end loop;
end $$;

commit;
