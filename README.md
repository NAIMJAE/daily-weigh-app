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
5. 이어서 `supabase/patch-meal-entries.sql`, `supabase/patch-record-flows.sql`, `supabase/patch-workout-routines.sql`, `supabase/patch-routine-weights.sql`, `supabase/patch-meal-category.sql` 순서로 실행 (끼니별 식단, 식단 점수, 스트릭 다시 세기, 운동 루틴과 기본 종목·템플릿, 끼니의 식사 종류)
   - 테스트 프로젝트에서 화면을 확인하려면 `supabase/seed-demo-records.sql`로 `demo01` 더미 기록을 넣고, `supabase/seed-demo-meal-categories.sql`로 그 끼니에 식사 종류를 채운다. 통계의 그룹 보기를 보려면 `supabase/seed-demo-group-stats.sql`로 같은 그룹 민지·준호의 6주치 끼니와 운동을 넣는다
6. 마지막에 `supabase/patch-security.sql` 실행 (기록 날짜·사진 제한, 초대 코드와 강퇴, 사진 저장소 권한, 함수 권한, 찌르기·댓글 제한). 다른 패치를 다시 실행했다면 이것도 다시 실행한다. 이어서 `supabase/patch-delete-account.sql` 실행 (앱 안 회원 탈퇴), `supabase/patch-reports.sql` 실행 (신고·차단)
7. Storage에 `body-photos`, `meal-photos` 버킷이 생겼는지 확인

로그인은 웹과 같습니다. 아이디 `foo`는 `foo@dailyweigh.local`로 들어갑니다.

## 앱 아이콘

원본은 `assets/icon/app_icon.svg`(눈금 저울)입니다. 모양을 바꾸면 아래를 모두 같이 고칩니다.

| 쓰는 곳 | 파일 |
|---|---|
| 런처 아이콘 (안드로이드 8 이상, 적응형·테마 아이콘) | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, 저울 `drawable/ic_launcher_foreground.xml`, 바탕색 `values/colors.xml` |
| 런처 아이콘 (안드로이드 8 미만) | `mipmap-*/ic_launcher.png` |
| 스플래시 (흰 바탕 가운데 128dp 아이콘) | `drawable/splash_logo.xml`. 12 이상은 `values-v31`·`values-night-v31/styles.xml`과 `drawable/splash_icon.xml`, 12 미만은 `drawable*/launch_background.xml` |
| 앱 첫 로딩 화면, 로그인 화면 | `lib/shared/widgets/app_logo.dart` (`AppSplash`, `AppLogo`) |
| 푸시 알림 상태바 아이콘 | `drawable/ic_stat_notify.xml` (흰색 실루엣). 푸시를 붙일 때 알림의 small icon으로 `@drawable/ic_stat_notify`, 색은 `@color/ic_launcher_background`를 지정 |
| Play 스토어 아이콘 512×512 | `assets/icon/play_store_icon_512.png` (모서리 없음, Play가 깎음) |
| Play 스토어 그래픽 이미지 1024×500 | `assets/icon/play_feature_graphic.png` |
| 초대 링크 공유 미리보기 1200×630 | `assets/icon/og_invite.png`. 초대 링크 웹 페이지를 만들 때 `og:image`로 쓴다 |

PNG는 저장소 루트에서 `powershell -ExecutionPolicy Bypass -File tool/icons/render_icons.ps1`로 다시 그립니다. `assets/icon/`은 앱에 묶이지 않습니다(`pubspec.yaml`에 넣지 않음).
