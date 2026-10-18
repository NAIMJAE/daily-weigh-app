-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-record-flows.sql 다음에 실행한다.
-- 끼니마다 식사 종류(집밥, 외식 …)를 하나만 둔다. 통계의 식사 종류 비율이 이 값으로 센다.
-- 예전 태그(tags)가 있으면 첫 태그를 종류로 옮긴다. tags 칸은 더 쓰지 않지만 지우지는 않는다.
-- 다시 실행해도 된다.

alter table public.meal_entries add column if not exists category text;
alter table public.meal_entries drop constraint if exists meal_entries_category_known;
alter table public.meal_entries add constraint meal_entries_category_known check (
  category is null
  or category in ('home', 'eatout', 'delivery', 'salad', 'simple', 'cheat')
);

update public.meal_entries
set category = tags[1]
where category is null and tags is not null and cardinality(tags) > 0;
