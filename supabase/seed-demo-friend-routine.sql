-- 멤버 방의 '운동' 카드(친구 루틴 가져가기, 최근 운동)를 확인하기 위한 더미 데이터. 앱 전용 테스트 프로젝트에서만 실행한다.
-- demo01 과 같은 그룹에 있는 '민지'에게 2분할 템플릿을 사용 중 루틴으로 복사하고, 어제 'A 상체' 운동 하나를 남긴다.
-- 다시 실행하면 민지의 루틴과 운동이 하나씩 더 생긴다.

do $$
declare
  friend uuid;
  tpl public.routines%rowtype;
  new_routine uuid;
  src_day record;
  new_day uuid;
  first_day uuid;
  new_session uuid;
  day_date date := (now() at time zone 'Asia/Seoul')::date - 1;
begin
  select p.id into friend
  from public.profiles p
  join public.group_members them on them.user_id = p.id
  join public.group_members me on me.group_id = them.group_id
  join public.profiles demo on demo.id = me.user_id and demo.username = 'demo01'
  where p.nickname = '민지'
  limit 1;
  if friend is null then
    raise exception 'demo01 과 같은 그룹의 민지를 찾지 못했어요';
  end if;

  select * into tpl from public.routines where template_key = 'upper_lower';

  update public.routines set is_active = false where owner_id = friend and is_active;
  insert into public.routines (owner_id, name, description, is_active, source_routine_id)
  values (friend, '민지 상하체', tpl.description, true, tpl.id)
  returning id into new_routine;

  for src_day in select * from public.routine_days where routine_id = tpl.id order by position loop
    insert into public.routine_days (routine_id, position, name)
    values (new_routine, src_day.position, src_day.name)
    returning id into new_day;
    if first_day is null then
      first_day := new_day;
    end if;
    insert into public.routine_items (day_id, position, exercise_id, target_sets, reps_min, reps_max, target_seconds)
    select new_day, position, exercise_id, target_sets, reps_min, reps_max, target_seconds
    from public.routine_items where day_id = src_day.id;
  end loop;

  insert into public.workout_sessions (
    user_id, record_date, routine_id, routine_day_id, day_name, started_at, finished_at, duration_minutes
  )
  values (
    friend, day_date, new_routine, first_day, 'A 상체',
    (day_date + time '19:00') at time zone 'Asia/Seoul',
    (day_date + time '19:48') at time zone 'Asia/Seoul',
    48
  )
  returning id into new_session;

  -- 종목마다 목표 세트 수만큼, 무게는 종목별로 정해 둔 값으로 채운다.
  insert into public.session_sets (
    session_id, exercise_id, exercise_name, item_position, set_number, weight_kg, reps, seconds, target_reps, target_seconds, done
  )
  select
    new_session,
    e.id,
    e.name,
    i.position,
    n,
    case e.name
      when '벤치프레스' then 35
      when '바벨 로우' then 30
      when '덤벨 숄더 프레스' then 8
      when '랫풀다운' then 30
      when '덤벨 컬' then 6
      when '트라이셉스 푸시다운' then 15
    end,
    i.reps_min,
    i.target_seconds,
    i.reps_min,
    i.target_seconds,
    true
  from public.routine_items i
  join public.exercises e on e.id = i.exercise_id
  cross join generate_series(1, i.target_sets) as n
  where i.day_id = first_day;
end $$;
