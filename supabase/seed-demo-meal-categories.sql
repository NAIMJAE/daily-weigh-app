-- 통계 화면 확인용. 앱 전용 테스트 프로젝트에서만 실행한다. 운영 DB에는 실행하지 않는다.
-- patch-meal-category.sql 다음에 실행한다. demo01 의 종류 없는 끼니에 식사 종류를 채운다.
-- 집밥이 가장 많고, 저녁에 배달·외식, 간식에 간편식·치팅이 섞이게 날짜와 끼니로 고른다.

update public.meal_entries as meal
set category = case meal.slot
  when 'breakfast' then (array['home', 'home', 'simple', 'home', 'salad'])[1 + (meal.record_date - date '2000-01-01') % 5]
  when 'lunch' then (array['eatout', 'home', 'salad', 'eatout', 'delivery', 'home'])[1 + (meal.record_date - date '2000-01-01') % 6]
  when 'dinner' then (array['home', 'delivery', 'home', 'eatout', 'home', 'cheat', 'home'])[1 + (meal.record_date - date '2000-01-01') % 7]
  else (array['simple', 'cheat', 'simple', 'home'])[1 + (meal.record_date - date '2000-01-01') % 4]
end
from public.profiles as profile
where profile.id = meal.user_id
  and profile.username = 'demo01'
  and meal.category is null;
