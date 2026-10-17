-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. schema.sql, patch-permissions.sql 다음에 실행한다.
-- 식단 기록을 끼니(아침, 점심, 저녁, 간식)별로 나눠 저장한다.
-- 사진은 기존 meal-photos 버킷의 '사용자/날짜-끼니.jpg'에 둔다. 버킷 정책은 schema.sql 그대로 쓴다.
-- 점수와 출석에는 아직 넣지 않는다. daily_records.meal_photo_url 은 그대로 둔다.

create table if not exists public.meal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  record_date date not null,
  slot text not null check (slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  photo_url text,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, record_date, slot),
  constraint meal_entries_at_least_one check (
    photo_url is not null
    or (description is not null and length(trim(description)) > 0)
  )
);

alter table public.meal_entries enable row level security;

drop policy if exists meal_entries_select on public.meal_entries;
create policy meal_entries_select on public.meal_entries
  for select using (user_id = auth.uid() or public.share_group(auth.uid(), user_id));

drop policy if exists meal_entries_insert on public.meal_entries;
create policy meal_entries_insert on public.meal_entries
  for insert with check (user_id = auth.uid());

drop policy if exists meal_entries_update on public.meal_entries;
create policy meal_entries_update on public.meal_entries
  for update using (user_id = auth.uid());

drop policy if exists meal_entries_delete on public.meal_entries;
create policy meal_entries_delete on public.meal_entries
  for delete using (user_id = auth.uid());
