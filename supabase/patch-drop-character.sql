-- 앱 전용 프로젝트에서만 실행한다. 웹 MVP 프로젝트에는 실행하지 않는다.
-- 이미 schema.sql을 돌린 테스트 DB에서 캐릭터와 연출용 운동을 걷어낸다.

alter table public.daily_records
  add column if not exists workout_kinds text[];

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'daily_records'
      and column_name = 'workout_motion'
  ) then
    execute $upd$
      update public.daily_records
      set workout_kinds = case workout_motion
        when 'rest' then array['rest']
        when 'upper' then array['gym']
        when 'lower' then array['gym']
        when 'flex' then array['gym']
        else workout_kinds
      end
      where workout_motion is not null
    $upd$;
  end if;
end $$;

alter table public.daily_records drop constraint if exists daily_records_at_least_one;
alter table public.daily_records drop constraint if exists daily_records_workout_motion_check;
alter table public.daily_records drop column if exists workout_motion;

alter table public.daily_records drop constraint if exists workout_kinds_known;
alter table public.daily_records
  add constraint workout_kinds_known check (
    workout_kinds is null
    or workout_kinds <@ array['gym', 'cardio', 'home', 'swim', 'ball', 'pilates', 'walk', 'rest']::text[]
  );

alter table public.daily_records
  add constraint daily_records_at_least_one check (
    weight is not null
    or body_photo_url is not null
    or meal_photo_url is not null
    or (workout_kinds is not null and cardinality(workout_kinds) > 0)
    or (memo is not null and length(trim(memo)) > 0)
  );

alter table public.profiles
  drop column if exists body_type,
  drop column if exists hair_id,
  drop column if exists face_id,
  drop column if exists top_id,
  drop column if exists bottom_id;

drop policy if exists skit_rules_select on public.skit_rules;
drop table if exists public.skit_rules;
