-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-security.sql 다음에 실행한다.
-- 회원 탈퇴. 구글 플레이 정책상 앱 안에서 계정을 지울 수 있어야 한다.
-- 다시 실행해도 된다.
--
-- 앱은 먼저 저장소(body-photos, meal-photos)의 내 사진 파일을 지우고(본인 폴더 삭제 권한은 patch-security.sql),
-- 그다음 이 함수를 부른다. 함수는
--   1) 내 개인 그룹을 지우고,
--   2) 친구 그룹에서는 나가기와 같게 처리한다(마지막 멤버면 그룹을 지우고, 방장이면 다음 사람에게 넘긴다),
--   3) 친구가 가져간 루틴에 내가 만든 종목이 들어 있으면 그 친구 몫으로 종목을 복사해 둔다
--      (내 종목이 지워지면서 친구 루틴의 종목 줄까지 지워지지 않게),
--   4) 마지막으로 auth 사용자를 지운다. 프로필과 기록, 끼니, 운동, 루틴, 댓글, 찌르기는 on delete cascade 로 함께 지워진다.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  membership record;
  borrowed record;
  copied uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- 1) 개인 그룹
  delete from public.groups where created_by = uid and is_personal;

  -- 2) 친구 그룹
  for membership in
    select gm.group_id from public.group_members gm
    join public.groups g on g.id = gm.group_id
    where gm.user_id = uid and not g.is_personal
  loop
    perform 1 from public.groups where id = membership.group_id for update;
    delete from public.group_members where group_id = membership.group_id and user_id = uid;

    if not exists (select 1 from public.group_members where group_id = membership.group_id) then
      delete from public.groups where id = membership.group_id;
    elsif not exists (
      select 1 from public.group_members where group_id = membership.group_id and role = 'owner'
    ) then
      update public.group_members
      set role = 'owner'
      where id = (
        select id from public.group_members
        where group_id = membership.group_id
        order by joined_at, id
        limit 1
      );
    end if;
  end loop;

  -- 3) 친구 루틴에 들어 있는 내 종목은 친구 몫으로 복사한다.
  for borrowed in
    select distinct r.owner_id as friend, i.exercise_id
    from public.routine_items i
    join public.routine_days d on d.id = i.day_id
    join public.routines r on r.id = d.routine_id
    join public.exercises e on e.id = i.exercise_id
    where e.owner_id = uid and r.owner_id is distinct from uid and r.owner_id is not null
  loop
    insert into public.exercises (owner_id, name, body_part, equipment, measure, progression, increment, rest_seconds, sort_order)
    select borrowed.friend, name, body_part, equipment, measure, progression, increment, rest_seconds, sort_order
    from public.exercises where id = borrowed.exercise_id
    returning id into copied;

    update public.routine_items i
    set exercise_id = copied
    from public.routine_days d, public.routines r
    where i.day_id = d.id and d.routine_id = r.id
      and r.owner_id = borrowed.friend
      and i.exercise_id = borrowed.exercise_id;
  end loop;

  -- 4) 계정. 나머지는 cascade 로 지워진다.
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
