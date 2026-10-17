# 웹 MVP DB 구조

지금 운영 중인 웹 MVP Supabase 프로젝트의 `public` 스키마다. 앱 v1을 마친 뒤 이 DB의 데이터를 앱 전용 DB로 옮긴다. 앱 DB 구조는 `supabase/schema.sql`이 기준이다.

출처는 2026-10-17 대시보드의 Schema Visualizer 화면이다. 제약, 인덱스, RLS, 함수, 트리거, 스토리지 버킷은 화면에 보이지 않아 적지 않았다. 필요하면 웹 프로젝트에서 `pg_dump -n public --schema-only`로 확인한다.

필수 칸은 화면에서 채워진 표시였던 칸이다. 나머지는 비어 있어도 되는 칸으로 보인다.

## 테이블

### profiles

| 칸 | 타입 | 비고 |
|---|---|---|
| id | uuid | 기본 키, `auth.users.id` 참조 |
| username | text | 필수, 유일 |
| nickname | text | 필수 |
| avatar_url | text | 둥근 프로필 사진. 앱으로 옮기지 않는다 |
| start_weight | numeric | |
| target_weight | numeric | |
| created_at | timestamptz | |
| height | numeric | |

지갑 포인트, 스트릭, 마지막 출석일은 없다.

### groups

| 칸 | 타입 | 비고 |
|---|---|---|
| id | uuid | 기본 키 |
| name | text | 필수 |
| invite_code | text | 필수, 유일 |
| penalty_rule | text | 벌칙 문구. 앱에서는 보여 주지 않는다 |
| created_by | uuid | `profiles.id` 참조 |
| created_at | timestamptz | |

개인 그룹 여부 칸이 없다. 모든 그룹이 초대 코드가 있는 친구 그룹이다.

### group_members

| 칸 | 타입 | 비고 |
|---|---|---|
| id | uuid | 기본 키 |
| group_id | uuid | `groups.id` 참조 |
| user_id | uuid | `profiles.id` 참조 |
| role | text | |
| streak_days | int4 | 그룹별 스트릭. 앱으로 옮기지 않는다 |
| weekly_points | int4 | 그룹별 주간 점수. 앱으로 옮기지 않는다 |
| joined_at | timestamptz | |

### daily_records

| 칸 | 타입 | 비고 |
|---|---|---|
| id | uuid | 기본 키 |
| user_id | uuid | `profiles.id` 참조 |
| group_id | uuid | `groups.id` 참조 |
| record_date | date | 필수 |
| weight | numeric | |
| photo_url | text | 사진 한 장. 앱의 `body_photo_url`에 대응 |
| workout_tags | text[] | 운동 종류. 저장된 값이 앱의 `workout_kinds` 코드와 같은지 아직 모른다 |
| workout_minutes | int4 | |
| memo | text | |
| points_earned | int4 | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

기록이 그룹마다 따로 저장된다. 그래서 같은 사람의 같은 날짜 기록이 여러 행일 수 있다. 식단 사진 칸은 없다.

### pokes

| 칸 | 타입 | 비고 |
|---|---|---|
| id | uuid | 기본 키 |
| group_id | uuid | `groups.id` 참조 |
| sender_id | uuid | `profiles.id` 참조 |
| receiver_id | uuid | `profiles.id` 참조 |
| message | text | 필수. 앱 `pokes`에는 이 칸이 없다 |
| created_at | timestamptz | |

기록 참조 칸(`record_id`)은 없다. 처음부터 그룹에 붙어 있다.

## 앱 DB와 다른 점

| 웹 | 앱 |
|---|---|
| 기록이 그룹마다 한 행 | 기록이 사람·날짜마다 한 행, 멤버십으로 그룹에 보인다 |
| 사진 한 장 (`photo_url`) | 눈바디와 식단 사진을 나눈다 |
| `workout_tags` | `workout_kinds`, 정해진 코드만 허용 |
| 점수와 스트릭이 멤버십에 | 지갑과 스트릭이 프로필에 |
| 개인 그룹 없음 | 사람마다 개인 그룹 하나 |
| 찌르기에 메시지 | 메시지 없음 |
| 그룹 벌칙, 프로필 사진 | 없음 |

## 지금 이관 스크립트와 맞지 않는 점

`supabase/migrate-web-members.sql`은 이 구조를 보기 전에 썼다. 아래는 아직 고치지 않았다.

- 찌르기를 옮길 때 `legacy.pokes.record_id`로 기록과 잇는데, 웹 `pokes`에는 그 칸이 없다
- 웹에 운동 종류가 없다고 보고 `workout_tags`를 버린다
- `profiles`, `groups`, `group_members`를 `legacy`에서 `public`으로 옮기는 단계가 없다
