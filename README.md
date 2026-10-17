# 매일재라 (Daily Weigh) 앱 v1

Flutter 3.47.7 / Dart 3.13.5, 안드로이드 전용. 구현 기준은 `docs/v1-app-plan.md`.

## 시작 전에 필요한 것

앱 코드는 이 저장소에 있습니다. 앱 전용 Supabase 키는 이 PC 밖에 있습니다.

1. **앱 전용 Supabase 프로젝트** URL과 anon/publishable 키  
   웹 MVP 프로젝트 키를 넣지 마세요. 기획서대로 DB는 나눕니다.

Play Console 앱 ID를 이미 만들었다면 `kr.dailyweigh.daily_weigh` 대신 그 값을 알려주세요.

## 로컬 실행

```bash
flutter --version   # 3.47.7
copy assets\env\.env.example assets\env\.env
# .env에 앱 전용 URL / 키 입력
flutter pub get
flutter run
```

Supabase 대시보드에서:

1. Authentication > Email의 Confirm email을 OFF
2. `supabase/schema.sql` 전체를 SQL Editor에서 실행
3. 이어서 `supabase/patch-permissions.sql` 실행 (점수·스트릭 트리거, 그룹 나가기·강퇴 함수, 권한)
4. 이미 예전 스키마를 넣었다면 `supabase/patch-drop-character.sql`, `supabase/patch-groups-rls.sql`, `supabase/patch-permissions.sql` 순서로 실행
5. 이어서 `supabase/patch-meal-entries.sql`, `supabase/patch-record-flows.sql`, `supabase/patch-workout-routines.sql` 순서로 실행 (끼니별 식단, 식단 점수, 스트릭 다시 세기, 운동 루틴과 기본 종목·템플릿)
   - 테스트 프로젝트에서 화면을 확인하려면 `supabase/seed-demo-records.sql`로 `demo01` 더미 기록을 넣는다
6. Storage에 `body-photos`, `meal-photos` 버킷이 생겼는지 확인

로그인은 웹과 같습니다. 아이디 `foo`는 `foo@dailyweigh.local`로 들어갑니다.
