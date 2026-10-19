-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-security.sql 다음에 실행한다.
-- 신고와 차단. 그룹원끼리 사진과 댓글을 나누므로 구글 플레이의 사용자 생성 콘텐츠 정책에 맞춘다.
-- 다시 실행해도 된다.
--
-- 1) 신고(reports): 그룹원이나 그 사람의 사진·댓글을 신고한다. 운영자는 Supabase 대시보드에서 보고 처리한다.
--    신고한 사람은 자기가 낸 신고만 본다.
-- 2) 차단(blocks): 차단한 사람의 댓글은 나에게 보이지 않고, 그 사람은 나를 찌를 수 없다.
--    사진은 앱이 숨긴다(멤버 방에서 '차단한 멤버'로 보인다).

begin;

-- ---------------------------------------------------------------------------
-- 1) 신고
-- ---------------------------------------------------------------------------

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  target_user_id uuid not null references public.profiles(id) on delete cascade,
  group_id uuid references public.groups(id) on delete set null,
  target_kind text not null check (target_kind in ('user', 'body_photo', 'meal_photo', 'comment')),
  record_id uuid references public.daily_records(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  -- 신고 당시의 댓글 내용. 댓글이 지워져도 무엇을 신고했는지 남긴다.
  comment_body text,
  reason text not null check (reason in ('sexual', 'harassment', 'spam', 'violence', 'other')),
  detail text check (detail is null or char_length(detail) <= 300),
  -- 운영자가 처리하면 바꾼다: open → done / dismissed
  status text not null default 'open' check (status in ('open', 'done', 'dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists reports_status_idx on public.reports (status, created_at desc);

alter table public.reports enable row level security;

drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert with check (
    reporter_id = auth.uid()
    and target_user_id <> auth.uid()
    and public.share_group(auth.uid(), target_user_id)
    and status = 'open'
  );

drop policy if exists reports_select on public.reports;
create policy reports_select on public.reports
  for select using (reporter_id = auth.uid());

revoke update, delete on public.reports from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) 차단
-- ---------------------------------------------------------------------------

create table if not exists public.blocks (
  blocker_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

drop policy if exists blocks_select on public.blocks;
create policy blocks_select on public.blocks
  for select using (blocker_id = auth.uid());

drop policy if exists blocks_insert on public.blocks;
create policy blocks_insert on public.blocks
  for insert with check (blocker_id = auth.uid());

drop policy if exists blocks_delete on public.blocks;
create policy blocks_delete on public.blocks
  for delete using (blocker_id = auth.uid());

revoke update on public.blocks from anon, authenticated;

-- 나를 차단한 사람인지. 정책 안에서 상대의 차단 목록을 봐야 해서 security definer 로 둔다.
create or replace function public.is_blocked_by(p_blocker uuid, p_blocked uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b where b.blocker_id = p_blocker and b.blocked_id = p_blocked
  );
$$;

revoke execute on function public.is_blocked_by(uuid, uuid) from public, anon;
grant execute on function public.is_blocked_by(uuid, uuid) to authenticated;

-- 차단한 사람의 댓글은 나에게 보이지 않는다.
drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments
  for select using (
    public.is_group_member(group_id, auth.uid())
    and not public.is_blocked_by(auth.uid(), author_id)
  );

-- 찌르기: patch-security.sql 의 조건에 '받는 사람이 나를 차단하지 않았을 것'을 더한다.
drop policy if exists pokes_insert on public.pokes;
create policy pokes_insert on public.pokes
  for insert with check (
    sender_id = auth.uid()
    and receiver_id <> auth.uid()
    and public.is_group_member(group_id, auth.uid())
    and public.is_group_member(group_id, receiver_id)
    and not public.is_blocked_by(receiver_id, auth.uid())
    and not exists (
      select 1 from public.pokes p
      where p.group_id = pokes.group_id
        and p.sender_id = auth.uid()
        and p.receiver_id = pokes.receiver_id
        and p.created_at >= ((now() at time zone 'Asia/Seoul')::date::timestamp at time zone 'Asia/Seoul')
    )
  );

-- 받은 찌르기 목록에서도 차단한 사람 것은 뺀다.
drop policy if exists pokes_select on public.pokes;
create policy pokes_select on public.pokes
  for select using (
    public.is_group_member(group_id, auth.uid())
    and not public.is_blocked_by(auth.uid(), sender_id)
  );

commit;
