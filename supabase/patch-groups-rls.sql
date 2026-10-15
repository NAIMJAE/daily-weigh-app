-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행.
-- 그룹 insert 후 멤버가 되기 전에 select가 막히던 문제를 고친다.

drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select using (
    created_by = auth.uid() or public.is_group_member(id, auth.uid())
  );

create or replace function public.ensure_personal_group()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id into gid
  from public.groups
  where created_by = auth.uid()
    and is_personal = true;

  if gid is not null then
    insert into public.group_members (group_id, user_id, role)
    values (gid, auth.uid(), 'owner')
    on conflict (group_id, user_id) do nothing;
    return gid;
  end if;

  insert into public.groups (name, is_personal, created_by)
  values ('나만의 그룹', true, auth.uid())
  returning id into gid;

  insert into public.group_members (group_id, user_id, role)
  values (gid, auth.uid(), 'owner');
  return gid;
end;
$$;

create or replace function public.create_friend_group(p_name text, p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  created public.groups%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if length(trim(p_name)) = 0 then
    raise exception 'group name required';
  end if;

  insert into public.groups (name, is_personal, invite_code, created_by)
  values (trim(p_name), false, p_code, auth.uid())
  returning * into created;

  insert into public.group_members (group_id, user_id, role)
  values (created.id, auth.uid(), 'owner');
  return created;
end;
$$;

grant execute on function public.ensure_personal_group() to authenticated;
grant execute on function public.create_friend_group(text, text) to authenticated;
grant execute on function public.join_friend_group(text) to authenticated;
