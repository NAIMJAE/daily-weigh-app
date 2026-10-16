-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. schema.sql, patch-groups-rls.sql 다음에 실행한다.
-- 1) 그룹 나가기·강퇴·방장 이관을 서버 함수로 옮기고, 멤버십을 직접 쓰지 못하게 막는다.
-- 2) 하루 점수, 지갑, 스트릭을 서버 트리거가 계산한다. 앱은 지갑과 스트릭을 직접 쓰지 않는다.

-- ---------------------------------------------------------------------------
-- 헬퍼
-- ---------------------------------------------------------------------------

create or replace function public.is_group_owner(check_group_id uuid, check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = check_group_id and user_id = check_user_id and role = 'owner'
  );
$$;

-- ---------------------------------------------------------------------------
-- 점수, 지갑, 스트릭
-- ---------------------------------------------------------------------------

-- lib/core/utils/points.dart 의 computePoints 와 같은 규칙.
create or replace function public.compute_record_points(
  p_weight numeric,
  p_body text,
  p_meal text,
  p_kinds text[],
  p_minutes integer
)
returns integer
language sql
immutable
as $$
  select
    (case when p_weight is not null then 10 else 0 end)
    + (case when nullif(p_body, '') is not null then 15 else 0 end)
    + (case when nullif(p_meal, '') is not null then 15 else 0 end)
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
    new.weight, new.body_photo_url, new.meal_photo_url, new.workout_kinds, new.workout_minutes
  );
  return new;
end;
$$;

create or replace function public.daily_records_apply_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  prev_points integer := 0;
  last_date date;
  streak integer;
begin
  if tg_op = 'UPDATE' then
    prev_points := old.points_earned;
  end if;

  select streak_days, last_attend_date into streak, last_date
  from public.profiles
  where id = new.user_id
  for update;
  if not found then
    return new;
  end if;

  if last_date is null or last_date < new.record_date - 1 then
    streak := 1;
  elsif last_date = new.record_date - 1 then
    streak := streak + 1;
  end if;

  update public.profiles set
    wallet_points = wallet_points + new.points_earned - prev_points,
    streak_days = streak,
    last_attend_date = greatest(coalesce(last_date, new.record_date), new.record_date),
    updated_at = now()
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists daily_records_points on public.daily_records;
create trigger daily_records_points
  before insert or update on public.daily_records
  for each row execute function public.daily_records_set_points();

drop trigger if exists daily_records_wallet on public.daily_records;
create trigger daily_records_wallet
  after insert or update on public.daily_records
  for each row execute function public.daily_records_apply_wallet();

-- 앱을 열 때 하루 이상 쉬었으면 스트릭을 0으로. 하루의 경계는 휴대폰 날짜(p_today).
create or replace function public.reconcile_my_streak(p_today date)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set streak_days = 0, updated_at = now()
  where id = auth.uid()
    and streak_days <> 0
    and (last_attend_date is null or last_attend_date < p_today - 1);
$$;

-- ---------------------------------------------------------------------------
-- 그룹 함수
-- ---------------------------------------------------------------------------

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
    and is_personal = false
  for update;

  if target.id is null then
    raise exception 'invalid invite code';
  end if;

  if exists (
    select 1 from public.group_members
    where group_id = target.id and user_id = auth.uid()
  ) then
    return target.id;
  end if;

  select count(*) into member_count
  from public.group_members
  where group_id = target.id;

  if member_count >= 8 then
    raise exception 'group is full';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (target.id, auth.uid(), 'member');

  return target.id;
end;
$$;

create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.groups%rowtype;
  my_role text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into target from public.groups where id = p_group_id for update;
  if target.id is null then
    raise exception 'group not found';
  end if;
  if target.is_personal then
    raise exception 'personal group cannot be left';
  end if;

  delete from public.group_members
  where group_id = p_group_id and user_id = auth.uid()
  returning role into my_role;
  if my_role is null then
    raise exception 'not a member';
  end if;

  if not exists (select 1 from public.group_members where group_id = p_group_id) then
    delete from public.groups where id = p_group_id;
    return;
  end if;

  if not exists (
    select 1 from public.group_members where group_id = p_group_id and role = 'owner'
  ) then
    update public.group_members
    set role = 'owner'
    where id = (
      select id from public.group_members
      where group_id = p_group_id
      order by joined_at, id
      limit 1
    );
  end if;
end;
$$;

create or replace function public.kick_member(p_group_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'owner cannot kick self';
  end if;
  if not public.is_group_owner(p_group_id, auth.uid()) then
    raise exception 'only owner can kick';
  end if;
  if exists (select 1 from public.groups where id = p_group_id and is_personal) then
    raise exception 'personal group has no members to kick';
  end if;

  delete from public.group_members
  where group_id = p_group_id and user_id = p_user_id;
end;
$$;

grant execute on function public.join_friend_group(text) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.kick_member(uuid, uuid) to authenticated;
grant execute on function public.reconcile_my_streak(date) to authenticated;

-- ---------------------------------------------------------------------------
-- 권한. 그룹과 멤버십은 위 함수와 ensure_personal_group, create_friend_group 으로만 바꾼다.
-- ---------------------------------------------------------------------------

drop policy if exists profiles_insert on public.profiles;
revoke insert, update on public.profiles from anon, authenticated;
grant update (nickname, height, start_weight, target_weight, updated_at)
  on public.profiles to authenticated;

drop policy if exists groups_insert on public.groups;
drop policy if exists groups_delete on public.groups;
drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups
  for update using (public.is_group_owner(id, auth.uid()));
revoke insert, update, delete on public.groups from anon, authenticated;
grant update (name) on public.groups to authenticated;

drop policy if exists members_insert on public.group_members;
drop policy if exists members_update on public.group_members;
drop policy if exists members_delete on public.group_members;
revoke insert, update, delete on public.group_members from anon, authenticated;
