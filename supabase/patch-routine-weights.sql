-- 앱 전용 프로젝트 SQL Editor에서 한 번 실행. patch-workout-routines.sql 다음에 실행한다.
-- 루틴 종목의 무게를 언제 고쳤는지 남긴다. 다음 운동은 루틴 무게와 지난번 운동 무게 중 더 최근에 바뀐 쪽으로 채운다.
-- 비어 있으면(템플릿·친구 루틴에서 복사한 직후 포함) 지난번 운동 무게가 앞선다.
-- 다시 실행해도 된다.

alter table public.routine_items add column if not exists weight_updated_at timestamptz;
