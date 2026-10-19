-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. 다른 patch-*.sql 을 모두 실행한 다음 마지막에 실행한다.
-- 보안 점검에서 나온 서버 쪽 문제를 막는다. 다시 실행해도 된다.
--
-- 1) 점수 위조: 하루 기록의 식단·운동 표시 칸은 서버만 쓴다. 기록은 어제~내일(한국 시간)만 쓰고 고친다.
--    사진 칸은 내 폴더에 실제로 올린 파일만 넣을 수 있다(외부 URL 금지).
-- 2) 초대 코드: 서버가 8자리 코드를 만든다. 방장이 코드를 바꿀 수 있다. 강퇴된 사람은 다시 못 들어온다.
--    틀린 코드는 한 시간에 10번까지만 넣을 수 있다.
-- 3) 사진 저장소: 그룹원은 지금 기록에 걸린 사진만 본다. 내 사진은 지울 수 있다. jpg 5MB까지만 올린다.
-- 4) 그 밖: 로그인 안 한 사용자(anon)는 함수를 못 부른다. 가입 아이디는 이메일에서 정한다.
--    찌르기는 같은 그룹원에게 하루 한 번, 댓글은 300자까지이고 기록 주인도 지울 수 있다.
--
-- 이 SQL Editor에서 직접 넣는 데이터(이관, 테스트 시드)는 1)의 날짜·사진 제한을 받지 않는다.

begin;

-- ---------------------------------------------------------------------------
-- 1) 기록 쓰기 제한
-- ---------------------------------------------------------------------------

-- 앱에서 기록을 쓰고 고칠 수 있는 날. 앱은 오늘과 어제만 쓰고, 휴대폰 시계가 조금 앞서도 되게 내일까지 둔다.
create or replace function public.is_editable_day(p_day date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_day between (now() at time zone 'Asia/Seoul')::date - 1
                   and (now() at time zone 'Asia/Seoul')::date + 1;
$$;

-- 하루 기록: 앱이 보내는 칸만 쓸 수 있다. has_meal, has_session, session_minutes, points_earned 는
-- 끼니·운동 트리거(sync_day_flags)와 점수 트리거만 쓴다.
revoke insert, update on public.daily_records from anon, authenticated;
grant insert (user_id, record_date, weight, body_photo_url, meal_photo_url, workout_minutes, workout_kinds, memo, updated_at)
  on public.daily_records to authenticated;
-- upsert 는 충돌하면 보낸 칸을 모두 update 하므로 같은 칸에 update 권한도 준다.
grant update (user_id, record_date, weight, body_photo_url, meal_photo_url, workout_minutes, workout_kinds, memo, updated_at)
  on public.daily_records to authenticated;

drop policy if exists records_insert on public.daily_records;
create policy records_insert on public.daily_records
  for insert with check (user_id = auth.uid() and public.is_editable_day(record_date));

drop policy if exists records_update on public.daily_records;
create policy records_update on public.daily_records
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_editable_day(record_date));

drop policy if exists meal_entries_insert on public.meal_entries;
create policy meal_entries_insert on public.meal_entries
  for insert with check (user_id = auth.uid() and public.is_editable_day(record_date));

drop policy if exists meal_entries_update on public.meal_entries;
create policy meal_entries_update on public.meal_entries
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_editable_day(record_date));

-- 운동: 지우기는 전처럼 내 운동이면 된다. 넣기와 고치기만 날짜를 본다.
drop policy if exists workout_sessions_write on public.workout_sessions;
drop policy if exists workout_sessions_insert on public.workout_sessions;
drop policy if exists workout_sessions_update on public.workout_sessions;
drop policy if exists workout_sessions_delete on public.workout_sessions;
create policy workout_sessions_insert on public.workout_sessions
  for insert with check (user_id = auth.uid() and public.is_editable_day(record_date));
create policy workout_sessions_update on public.workout_sessions
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_editable_day(record_date));
create policy workout_sessions_delete on public.workout_sessions
  for delete using (user_id = auth.uid());

-- 이미 있는 행은 검사하지 않고(not valid) 새로 쓰는 값만 막는다.
alter table public.workout_sessions drop constraint if exists workout_sessions_duration_limit;
alter table public.workout_sessions add constraint workout_sessions_duration_limit
  check (duration_minutes <= 600) not valid;

alter table public.meal_entries drop constraint if exists meal_entries_description_length;
alter table public.meal_entries add constraint meal_entries_description_length
  check (description is null or char_length(description) <= 200) not valid;

-- 사진 칸: 값이 새로 들어오거나 바뀔 때만, 내 폴더(사용자id/파일.jpg)에 실제로 올린 파일인지 본다.
-- 바뀌지 않은 예전 값(웹 이관 데이터 등)은 그대로 둔다. 외부 URL 은 여기서 막힌다.
create or replace function public.check_own_photo(p_value text, p_old text, p_user uuid, p_bucket text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_value is null or p_value is not distinct from p_old then
    return;
  end if;
  if p_value !~ ('^' || p_user::text || '/[^/]+\.jpg$')
     or not exists (select 1 from storage.objects o where o.bucket_id = p_bucket and o.name = p_value) then
    raise exception 'photo must be an uploaded file in your own folder' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.daily_records_check_photos()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.check_own_photo(
    new.body_photo_url, case when tg_op = 'UPDATE' then old.body_photo_url end, new.user_id, 'body-photos');
  perform public.check_own_photo(
    new.meal_photo_url, case when tg_op = 'UPDATE' then old.meal_photo_url end, new.user_id, 'meal-photos');
  return new;
end;
$$;

drop trigger if exists daily_records_check_photos on public.daily_records;
create trigger daily_records_check_photos
  before insert or update on public.daily_records
  for each row execute function public.daily_records_check_photos();

create or replace function public.meal_entries_check_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.check_own_photo(
    new.photo_url, case when tg_op = 'UPDATE' then old.photo_url end, new.user_id, 'meal-photos');
  return new;
end;
$$;

drop trigger if exists meal_entries_check_photo on public.meal_entries;
create trigger meal_entries_check_photo
  before insert or update on public.meal_entries
  for each row execute function public.meal_entries_check_photo();

-- ---------------------------------------------------------------------------
-- 2) 초대 코드와 강퇴
-- ---------------------------------------------------------------------------

-- 강퇴된 사람. 같은 그룹에 초대 코드로 다시 들어오지 못한다. 함수만 읽고 쓴다.
create table if not exists public.group_bans (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  banned_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
alter table public.group_bans enable row level security;
revoke all on public.group_bans from anon, authenticated;

-- 틀린 초대 코드를 넣은 기록. 한 시간에 10번을 넘으면 막는다. 함수만 읽고 쓴다.
create table if not exists public.invite_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index if not exists invite_attempts_user_idx on public.invite_attempts (user_id, attempted_at);
alter table public.invite_attempts enable row level security;
revoke all on public.invite_attempts from anon, authenticated;

-- 8자리 초대 코드. 헷갈리는 글자(I, O, 0, 1)는 뺀 32글자에서 고른다. 앱의 invite_code.dart 와 같은 글자다.
-- gen_random_uuid 의 무작위 바이트를 쓴다. 256 은 32의 배수라 글자마다 확률이 같다.
create or replace function public.new_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  code text;
begin
  loop
    bytes := uuid_send(gen_random_uuid());
    code := '';
    for i in 0..7 loop
      code := code || substr(alphabet, 1 + get_byte(bytes, i) % 32, 1);
    end loop;
    exit when not exists (select 1 from public.groups g where g.invite_code = code);
  end loop;
  return code;
end;
$$;

-- 앱이 보내는 p_code 는 쓰지 않는다(예전 앱과 호환하려고 인자만 남긴다).
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
  if char_length(trim(p_name)) > 30 then
    raise exception 'group name too long';
  end if;

  insert into public.groups (name, is_personal, invite_code, created_by)
  values (trim(p_name), false, public.new_invite_code(), auth.uid())
  returning * into created;

  insert into public.group_members (group_id, user_id, role)
  values (created.id, auth.uid(), 'owner');
  return created;
end;
$$;

-- 방장이 초대 코드를 새로 바꾼다. 예전 코드는 바로 못 쓴다.
create or replace function public.rotate_invite_code(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  code text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_group_owner(p_group_id, auth.uid()) then
    raise exception 'only owner can change invite code';
  end if;
  if exists (select 1 from public.groups where id = p_group_id and is_personal) then
    raise exception 'personal group has no invite code';
  end if;
  code := public.new_invite_code();
  update public.groups set invite_code = code where id = p_group_id;
  return code;
end;
$$;

-- 틀린 코드면 오류 대신 null 을 돌려준다. 오류를 내면 시도 기록까지 되돌려지기 때문이다.
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

  delete from public.invite_attempts
  where user_id = auth.uid() and attempted_at < now() - interval '1 day';
  if (
    select count(*) from public.invite_attempts
    where user_id = auth.uid() and attempted_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'too many invite attempts';
  end if;

  select * into target
  from public.groups
  where invite_code = upper(trim(code))
    and is_personal = false
  for update;

  if target.id is null then
    insert into public.invite_attempts (user_id) values (auth.uid());
    return null;
  end if;

  if exists (
    select 1 from public.group_members
    where group_id = target.id and user_id = auth.uid()
  ) then
    return target.id;
  end if;

  if exists (select 1 from public.group_bans where group_id = target.id and user_id = auth.uid()) then
    raise exception 'banned from group';
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

-- 강퇴하면 다시 못 들어오게 남긴다.
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

  insert into public.group_bans (group_id, user_id)
  values (p_group_id, p_user_id)
  on conflict (group_id, user_id) do update set banned_at = now();
end;
$$;

-- 그룹을 만든 사람도 나간 뒤에는 그룹(초대 코드)을 못 본다. 만들기 함수가 새 그룹 행을 바로 돌려준다.
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select using (public.is_group_member(id, auth.uid()));

-- ---------------------------------------------------------------------------
-- 3) 사진 저장소
-- ---------------------------------------------------------------------------

update storage.buckets
set file_size_limit = 5 * 1024 * 1024,
    allowed_mime_types = array['image/jpeg']
where id in ('body-photos', 'meal-photos');

-- 그룹원은 지금 기록에 걸린 사진만 본다. 뺀 사진이나 지운 끼니의 사진은 주인만 본다.
-- 예전 기록에는 서명 URL 전체가 들어 있을 수 있어 '버킷/경로'가 들어 있는지도 본다.
drop policy if exists body_photos_select on storage.objects;
create policy body_photos_select on storage.objects
  for select using (
    bucket_id = 'body-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.daily_records r
        where r.user_id::text = (storage.foldername(name))[1]
          and (r.body_photo_url = name or strpos(r.body_photo_url, 'body-photos/' || name) > 0)
          and public.share_group(auth.uid(), r.user_id)
      )
    )
  );

drop policy if exists meal_photos_select on storage.objects;
create policy meal_photos_select on storage.objects
  for select using (
    bucket_id = 'meal-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.meal_entries m
        where m.user_id::text = (storage.foldername(name))[1]
          and (m.photo_url = name or strpos(m.photo_url, 'meal-photos/' || name) > 0)
          and public.share_group(auth.uid(), m.user_id)
      )
      or exists (
        select 1 from public.daily_records r
        where r.user_id::text = (storage.foldername(name))[1]
          and (r.meal_photo_url = name or strpos(r.meal_photo_url, 'meal-photos/' || name) > 0)
          and public.share_group(auth.uid(), r.user_id)
      )
    )
  );

-- 내 사진은 지울 수 있다. 앱은 사진을 빼거나 끼니를 지울 때 파일도 지운다.
drop policy if exists body_photos_delete on storage.objects;
create policy body_photos_delete on storage.objects
  for delete using (
    bucket_id = 'body-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists meal_photos_delete on storage.objects;
create policy meal_photos_delete on storage.objects
  for delete using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- 4) 함수 권한, 가입, 찌르기, 댓글
-- ---------------------------------------------------------------------------

-- 로그인 안 한 사용자는 public 함수를 부르지 못한다. 로그인한 사용자는 전처럼 부른다.
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
alter default privileges in schema public revoke execute on functions from public, anon;
-- 다른 사람 행을 다시 계산하는 함수는 트리거(security definer)에서만 쓴다.
revoke execute on function public.sync_day_flags(uuid, date) from authenticated;
revoke execute on function public.recompute_streak(uuid) from authenticated;
revoke execute on function public.check_own_photo(text, text, uuid, text) from authenticated;
revoke execute on function public.new_invite_code() from authenticated;
-- 가입 트리거는 Supabase Auth 가 실행한다.
grant execute on function public.handle_new_user() to supabase_auth_admin;

-- 가입: 아이디는 이메일 앞부분으로 정한다(메타데이터의 username 은 믿지 않는다).
-- 앱 아이디는 '아이디@dailyweigh.local' 로만 가입한다.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text := lower(split_part(new.email, '@', 1));
  nick text := left(trim(coalesce(new.raw_user_meta_data->>'nickname', '')), 20);
begin
  if lower(new.email) not like '%@dailyweigh.local' then
    raise exception 'sign up with the app username';
  end if;
  if char_length(uname) < 3 or char_length(uname) > 30 then
    raise exception 'username must be 3 to 30 characters';
  end if;
  if char_length(nick) < 2 then
    nick := uname;
  end if;

  insert into public.profiles (id, username, nickname)
  values (new.id, uname, nick)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 찌르기: 같은 그룹원에게만, 나 자신은 안 되고, 한 사람에게 하루(한국 시간) 한 번.
drop policy if exists pokes_insert on public.pokes;
create policy pokes_insert on public.pokes
  for insert with check (
    sender_id = auth.uid()
    and receiver_id <> auth.uid()
    and public.is_group_member(group_id, auth.uid())
    and public.is_group_member(group_id, receiver_id)
    and not exists (
      select 1 from public.pokes p
      where p.group_id = pokes.group_id
        and p.sender_id = auth.uid()
        and p.receiver_id = pokes.receiver_id
        and p.created_at >= ((now() at time zone 'Asia/Seoul')::date::timestamp at time zone 'Asia/Seoul')
    )
  );

-- 댓글: 그 그룹 멤버의 기록에만, 300자까지. 기록 주인도 자기 사진에 달린 댓글을 지울 수 있다.
alter table public.comments drop constraint if exists comments_body_length;
alter table public.comments add constraint comments_body_length
  check (char_length(trim(body)) between 1 and 300) not valid;

drop policy if exists comments_insert on public.comments;
create policy comments_insert on public.comments
  for insert with check (
    author_id = auth.uid()
    and public.is_group_member(group_id, auth.uid())
    and exists (
      select 1 from public.daily_records r
      where r.id = record_id and public.is_group_member(group_id, r.user_id)
    )
  );

drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments
  for delete using (
    author_id = auth.uid()
    or exists (select 1 from public.daily_records r where r.id = record_id and r.user_id = auth.uid())
  );

commit;
