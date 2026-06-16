# 댕냥스토리 개발 기록

## 2026-06-15

### 피드 이미지 비율 고정 (3:4)

**문제**
- 피드 단일/다중 이미지가 사진마다 비율이 달라 레이아웃 불규칙
- 다중 이미지(PageView) 스크롤 시 메인 탭 PageView와 제스처 충돌 발생

**해결**
- 모든 피드 이미지: `AspectRatio(3/4)` + `BoxFit.cover` 고정 프레임
- Supabase Transform: `width=900&height=1200&resize=cover` — 정확한 3:4 비율로 서버 크롭
- 게시글 상세 화면도 동일 적용 (`width=1200&height=1600`)
- 메인 `PageView`에 `NeverScrollableScrollPhysics` → 탭 스와이프 비활성화
- 내부 이미지 `PageView`에 `PageScrollPhysics(parent: ClampingScrollPhysics())` → 이미지 스와이프 정상 동작

---

### 기록 사진 버킷 404 수정

- `record_service.dart` 버킷명 `record-photos` → `post-images` 변경 (기존 버킷 RLS 미설정으로 404 발생)
- **참고**: `record-photos` 버킷은 여전히 존재하나 RLS 정책 미비 상태. 추후 정리 예정

---

### 예방접종 알림 시스템 전면 개선

**문제**
- 알림 관리 화면에 알림이 안 나타남 (`sent = NULL` 처리 누락)
- 알림 시간 설정 불가 (`remind_at` 컬럼이 `date` 타입이라 시간 저장 안 됨)
- 홈/상세 화면에서 알림 수정 불가

**DB 마이그레이션** (직접 실행)
```sql
ALTER TABLE reminders ALTER COLUMN remind_at TYPE timestamptz USING remind_at::date::timestamptz;
```

**Flutter 수정**
- `ReminderService.getMyReminders()`: `.or('sent.eq.false,sent.is.null')` — NULL sent 처리
- `remind_at` 저장: `toUtc().toIso8601String()` — timezone 포함 UTC 저장
- `remind_at` 읽기: `.toLocal()` — 기기 현지 시각으로 표시
- `add_record_screen.dart`: 알림 추가 → `AddRecord` 저장 후 `recordId` 연결
- `record_detail_screen.dart`: 상세 화면에서 알림 추가/수정/삭제 가능
- `reminder_screen.dart`: 알림 관리에서 수정/삭제 가능

**타임존 설계**
- 미국 등 해외에서 설정 시: 기기 로컬 타임 → UTC 변환 저장 → 정확한 현지 시각에 알림

---

### 알림 UI 리디자인

**이전**: 토글 카드 + pill 버튼 (복잡, overflow 버그)
**이후**: 심플한 한 줄 row → 탭하면 바텀시트

**바텀시트 구성**
- 날짜/시간 선택 row (탭 → OS 피커)
- "저장하기" 버튼
- "알림 삭제" 버튼 (수정 시)

**적용 범위**
- 기록 추가 화면: `ReminderSection` 위젯 완전 재설계
- 기록 상세 화면: 등록된 알림 리스트 제거 → 각 알림 row 탭으로 수정
- 알림 관리 화면: 수정 다이얼로그 → 바텀시트

---

### 알림-기록 연결 구조 추가

**문제**: 같은 펫의 다른 예방접종 알림이 한 기록 상세에 모두 표시됨

**해결**
- `reminders` 테이블에 `record_id uuid references records(id)` 컬럼 추가
  - 마이그레이션: `supabase/migrations/reminders_record_link.sql`
  - **Supabase SQL Editor에서 실행 필요**
- `addReminder()`: `recordId` 파라미터 추가
- `addRecord()`: 반환값 `Future<String>` (새 record ID 반환)
- 상세 화면 알림 로딩: `record_id` 기준 필터 (없으면 `pet_id` fallback)

---

### Edge Function 알림 발송 쿼리 수정

**이전**: `remind_at = '2026-06-15'` (date 타입 비교, KST 기준)
**이후**: `remind_at <= NOW() AND remind_at >= NOW() - 25h AND sent = false`
- `timestamptz` 저장 방식과 일치
- 크론이 실패해도 25시간 이내 재처리 가능
- `send-reminders` Edge Function 재배포 필요

---

### 삭제 확인 다이얼로그 & 기타 UX

- 기록 삭제: `포포얼굴사진.png` + "기록을 삭제할거냥?"
- 알림 삭제: `포포얼굴사진.png` + "알림을 삭제할거냥?" (문구 수정)
- 프로필 게시글 그리드: 3열 → 2열, 정사각형 썸네일
- 캘린더 "집 케어 메모" → "홈 케어 기록"

---

### 알림 크론 & 시간 피커 정밀화

**문제**: 크론이 매시간 정각 실행 → 12:05 설정하면 13:00에 발송 (최대 1시간 오차)

**해결 설계**: 시간을 30분 단위로만 설정 가능하게 제한 + 크론 30분마다 실행

**Flutter — 커스텀 시간 피커 (`_showHalfHourTimePicker`)**
- OS 기본 `showTimePicker` 제거
- 커스텀 바텀시트: `−/+` 버튼으로 시(hour) 조절 + `:00` / `:30` 버튼 선택
- 분(minute)은 0 또는 30만 선택 가능

**Supabase 크론**
- 기존 `send-reminders-daily` (`0 15 * * *`, 하루 1회) 제거
- 신규 `send-reminders` (`0,30 * * * *`, 30분마다) 등록
- 최대 알림 오차: 30분 → 설정 시각에 정확히 맞음

**완료 사항**
- `reminders_record_link.sql` Supabase 실행 완료
- `send-reminders` Edge Function 재배포 완료
- 크론 `0,30 * * * *` 등록 완료

---

### TODO (다음 세션)

- [ ] **`record-photos` 버킷 RLS 정책 점검** — 원래 버킷으로 복원 여부 결정

---

## 2026-06-10

### Supabase 서울 리전 이전 (US → ap-northeast-2)

- 새 프로젝트 ref: `wosuipvdblhpgutkxjkn`
- `backup_schema.sql` 전체 실행 완료 (테이블 21개, RLS, 트리거, 인덱스)
- Edge Functions 재배포: `send-notification`, `moderate-images`, `delete-account`, `send-reminders`, `send-birthday`
- Supabase Secrets 재설정: `FIREBASE_SERVICE_ACCOUNT`, `GOOGLE_VISION_API_KEY`, `CRON_SECRET`
- pg_cron 활성화 + Cron Jobs 재등록 (`send-reminders`, `send-birthday`)
- Storage 버킷 생성: `pet-photos`, `post-images`, `record-photos` + RLS 정책
- Google OAuth Redirect URL 업데이트: `com.pawprint.mobile://login-callback/`
- `config.dart` 새 프로젝트 URL·anon key로 업데이트

---

### 버그 수정 — Kakao OAuth

**문제 1: "unacceptable audience"**
- 원인: Supabase Kakao Provider에 REST API Key가 설정돼 있었으나, 네이티브 SDK가 발급하는 ID Token의 `aud` 클레임은 Native App Key임
- 해결: Supabase Dashboard → Auth → Providers → Kakao의 "REST API Key" 필드를 Native App Key(`692fad8b1fbfd8d8ec4aa4a3be40fc31`)로 변경

**문제 2: "unacceptable" (nonce 누락)**
- 원인: Supabase Kakao OIDC는 nonce 필수인데 앱이 nonce 없이 토큰 요청
- 해결: `auth_service.dart`에 nonce 생성 + SHA-256 해싱 추가
  ```dart
  final rawNonce = _generateNonce();
  final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
  token = await UserApi.instance.loginWithKakaoTalk(nonce: hashedNonce);
  await _supabase.auth.signInWithIdToken(
    provider: OAuthProvider.kakao,
    idToken: idToken,
    nonce: rawNonce,  // raw (unhashed) nonce 전달
  );
  ```
- `pubspec.yaml`에 `crypto: ^3.0.3` 추가

**문제 3: "unverified email"**
- 원인: Supabase가 이메일 인증을 요구하는데 Kakao 계정은 이메일 미인증 상태
- 해결: Supabase Dashboard → Auth → Settings → "Confirm email" 비활성화

---

### 버그 수정 — Storage 403

- 원인: 서울 신규 프로젝트에 버킷 RLS 정책이 전혀 없었음
- 해결: 3개 버킷(`pet-photos`, `post-images`, `record-photos`)에 각 4개씩 총 12개 RLS 정책 추가
  - SELECT: public (누구나 조회)
  - INSERT/UPDATE/DELETE: authenticated + `auth.uid()::text = (storage.foldername(name))[1]` (본인 폴더만)

---

### 버그 수정 — FCM 알림

**문제 1: DB 트리거 payload 형식 오류**
- 원인: `row_to_json(NEW)` 그대로 전송했으나 Edge Function이 `{type, table, record}` 구조를 기대
- 해결: `trigger_send_notification()` 함수 수정
  ```sql
  body := jsonb_build_object('type', 'INSERT', 'table', TG_TABLE_NAME, 'record', row_to_json(NEW))
  ```

**문제 2: FIREBASE_SERVICE_ACCOUNT JSON 형식 오류**
- 원인: Windows에서 파일 복사 시 `\n`이 리터럴 문자열로 저장되어 private_key 파싱 실패
- 해결: PowerShell에서 `ConvertFrom-Json | ConvertTo-Json -Compress`로 minify 후 Secret 재설정

**문제 3: FCM 토큰 미등록 (Google 계정)**
- 원인: 서울 신규 프로젝트에 로그인한 적 없어서 FCM 토큰이 DB에 없었음
- 해결: Google 계정으로 신규 로그인 → 토큰 자동 등록 → 알림 정상 수신 확인

**문제 4: service_role key 보안**
- 원인: `trigger_send_notification()` 함수의 Authorization 헤더에 실제 키를 backup_schema.sql에 저장하면 Git 노출 위험
- 대응: `backup_schema.sql`에는 `SUPABASE_SERVICE_ROLE_KEY` 플레이스홀더로 저장, 실제 키는 SQL Editor에서만 실행 후 저장 금지 (키 로테이션 완료)

---

### 버그 수정 — DB 스키마

**records 테이블**
- `pet_id`: NOT NULL → nullable (공통 기록 지원)
- `type`: 3종 → 8종으로 확장 (health, weight, note, meal, grooming, play, bath, photo)
- 컬럼명: `amount` → `value NUMERIC`, `memo` → `notes TEXT`, `photo_url TEXT` 추가
- backup_schema.sql + 운영 DB 모두 ALTER TABLE로 반영

**community_posts 테이블**
- category CHECK 제약: 기존 4종 → 6종으로 확장 (`tip`, `question` 추가)
- backup_schema.sql + 운영 DB 모두 반영

**`trigger_send_notification()` 함수 누락**
- 원인: backup_schema.sql 초안에 notifications/reports INSERT 트리거 함수가 빠져 있었음
- 해결: 함수 + 트리거 2개(trg_send_notification, trg_send_notification_report) 추가 후 운영 DB 실행

**관리자 UUID (신규 프로젝트)**
- Google: `99244f0e-6035-49df-9189-27caf6df9c89`
- Kakao: `b8ea8060-898b-4b2a-a98e-897e90be7d1f`
- backup_schema.sql, RLS 정책, Edge Function Secret(`ADMIN_USER_ID`) 모두 반영 완료

---

### 앱 기능 추가

**로그아웃 → 로그인 화면 자동 이동** (`main.dart`)
- `AuthGate` StreamBuilder에서 session이 null로 전환될 때 (`_wasAuthenticated` 플래그로 감지)
- `Navigator.popUntil((r) => r.isFirst)` 호출로 백스택 완전 정리 후 `LoginScreen` 표시

**뒤로가기 2회 종료** (`app.dart`)
- `PopScope(canPop: false)` 로 Android 뒤로가기 인터셉트
- 2초 이내 2회 → `SystemNavigator.pop()` 앱 종료
- 첫 번째 탭 시 "뒤로가기를 한 번 더 누르면 앱이 종료됩니다" SnackBar 표시

**펫 생일 선택 UI 개선** (`add_pet_screen.dart`, `edit_pet_screen.dart`)
- 기존 `showDatePicker()` → TableCalendar 바텀시트 방식으로 변경
- 홈(캘린더) 화면과 동일한 날짜 선택 UX로 통일

---

### 인기 게시글 점수 시스템 (Popular Score)

**설계 배경**
- 기존 인기 탭: 단순 `likes_count DESC` 정렬 → 오래된 글이 계속 상단 점령
- Reddit 시간 감쇠 + Instagram 인게이지먼트 가중치 방식 결합

**점수 공식**
```
score = (좋아요 × 2 + 댓글 × 3 + 저장 × 5) / (게시 후 시간 + 2)^1.5
```
- 저장(5) > 댓글(3) > 좋아요(2): 저장이 가장 강한 관심 신호
- 시간 감쇠: 분모 `(hours + 2)^1.5` — 새 글에 초기 부스트, 오래될수록 자연 하락
- `+2`: 게시 직후 분모가 0이 되는 것 방지

**DB 변경사항** (운영 DB + backup_schema.sql 모두 반영)
```sql
-- 컬럼 추가
ALTER TABLE posts
  ADD COLUMN saves_count INT NOT NULL DEFAULT 0 CHECK (saves_count >= 0),
  ADD COLUMN popular_score NUMERIC(10,4) NOT NULL DEFAULT 0;

-- saves_count 자동 관리 트리거
CREATE OR REPLACE FUNCTION update_saves_count() ...
CREATE TRIGGER update_saves_count AFTER INSERT OR DELETE ON saves ...

-- 점수 계산 함수
CREATE OR REPLACE FUNCTION update_popular_scores() ...
  UPDATE posts SET popular_score = (likes_count*2 + comments_count*3 + saves_count*5)
    / POWER(EXTRACT(EPOCH FROM (NOW()-created_at))/3600 + 2, 1.5) WHERE is_hidden = false;

-- pg_cron 매시간 자동 갱신
SELECT cron.unschedule('update-popular-scores');  -- 재실행 안전
SELECT cron.schedule('update-popular-scores', '0 * * * *', 'SELECT update_popular_scores()');

-- 초기값 계산 (최초 1회)
SELECT update_popular_scores();
```

**Flutter 변경** (`post_service.dart`)
- `getPopularPosts()` 정렬 기준: `likes_count DESC` → `popular_score DESC`

---

### 전체 이미지 CDN 캐싱 (CachedNetworkImage + Supabase Transform)

**문제**
- 앱 전체에서 `Image.network()` 직접 사용 → 스크롤 시 매번 재다운로드, 캐싱 없음
- Supabase Transform API 미활용 → 원본 해상도 이미지를 모바일에서 그대로 로드

**해결**
- 모든 `Image.network()` → `CachedNetworkImage()` 교체 (디스크 캐시 + 메모리 캐시)
- `toTransformUrl()` (`image_util.dart`) 적용 — Supabase Storage Transform API로 리사이즈/압축
- `precacheImage()` 인자도 `NetworkImage` → `CachedNetworkImageProvider`로 교체

**화면별 Transform 크기**

| 위치 | width | quality | 비고 |
|---|---|---|---|
| 피드 카드 이미지 | 900 | 85 | 단일/다중 이미지 모두 |
| 게시글 상세 / 커뮤니티 상세 | 1200 | 90 | 최고 화질 |
| 프로필 게시글 그리드 | 400 | 75 | 2열 썸네일 |
| 커뮤니티 목록 썸네일 | 200 | 75 | 76×76 표시 |
| 저장 목록 썸네일 | 112 | 75 | 56×56 표시 |
| 캘린더 기록 썸네일 | 144 | 75 | 72×72 표시 |
| 사진 갤러리 그리드 | 400 | 80 | |
| 기록 상세 | 900 | 85 | |
| 펫 아바타 | 200×200 | 85 | |
| 유저 프로필 펫 칩 아이콘 | 40×40 | 80 | 20×20 표시 |
| 수정 화면 기존 이미지 썸네일 | 176 | 80 | 88×88 표시 |
| 사진 뷰어 (전체화면) | 원본 | — | Transform 없음, 풀 화질 |

**수정된 파일 (17개)**
- `feed_screen.dart`, `post_detail_screen.dart`, `saved_posts_screen.dart`, `edit_post_screen.dart`
- `community_screen.dart`, `community_post_detail_screen.dart`
- `my_profile_screen.dart`, `profile_screen.dart`, `user_profile_screen.dart`
- `pet_screen.dart`
- `calendar_screen.dart`, `photo_gallery_screen.dart`, `photo_viewer_screen.dart`, `record_detail_screen.dart`
- `backup_schema.sql`, `database.md`
- `post_service.dart` (popular_score 정렬)

**결과**
- `flutter analyze` → No issues
- Galaxy S25+ 실기기 빌드·설치 완료

---

## 2026-06-09 (저녁)

### 한 일

**피드 UI 전면 개편**
- 이미지 포스트: 카드 컨테이너 제거 → overlay 스타일 (상단 그라디언트 + 아바타/이름, 하단 그라디언트 + 본문/액션)
- 텍스트 포스트: post.id 해시 기반 8가지 파스텔 그라디언트 카드, 본문 텍스트 크게 표시
- 더블탭 좋아요 토글 (좋아요 O → 취소, 좋아요 X → 추가 + 하트 애니메이션)
- 다중 이미지 dot indicator (PageView), 인접 이미지 precache
- `_ThreadPost(key: ValueKey(post.id))` 추가 → 필터/리프레시 시 state 누수 방지
- `AppPostImage`: `CachedNetworkImage`로 교체, `fixedHeight` 있어도 호출자 `fit` 파라미터 존중하도록 수정
- 이미지 크롭 버그 수정: Supabase Transform `resize=cover` 기본값이 서버 크롭 유발 → 원본 URL 직접 사용으로 해결

**캘린더 기능 강화**
- 날짜 셀 커스텀 빌더: 기록 타입별 이모지 마커 (최대 2개), 3개 이상 시 우상단 카운트 배지
- 헤더에 이번달 통계 (`N개 · N일 기록`) + 연속 기록 streak (`🔥 N일 연속`) 표시
- 헤더 탭 → 월/년도 점프 DateJumper (BottomSheet)
- 기록 타일 좌측 4px accent bar (기록 타입별 색상)
- 요일 헤더 색상: 일=빨강, 토=파랑
- 오늘=outline 원, 선택=solid 원 통일
- note 타입 기록에 활동별 이모지 매핑 (빗질 🪮, 목욕 🛁, 병원 🏥 등)
- 몸무게 이모지 ⚖️ → 📊 변경

**공통 기록 (pet_id nullable)**
- `records.pet_id` NOT NULL 제약 제거 (`records_nullable_pet.sql`)
- 전체 펫 대상 공통 기록 지원

---

## 2026-06-09

### 한 일

**커뮤니티 카테고리 확장 — 꿀팁/정보, 질문/고민**
- `tip` / `question` 카테고리 추가 (AppColors.catTip 퍼플, catQuestion 틸)
- 카테고리 선택 UI 카드 그리드 방식으로 개편 (LayoutBuilder, 아이콘 포함, 펫 3열 + 커뮤니티 2열 센터)
- 커뮤니티 탭바: 컬러 틴트 + 선택 시 컬러 그림자
- DB 제약 수정: `community_posts_category_check`에 tip/question 추가 (`community_category_expansion.sql`)

**UX 개선**
- GPS 좌표 → Nominatim 역지오코딩 (dart:io HttpClient, 패키지 없음): "서울 강남구 역삼동" 형식 표시
- 제목/내용 입력 필드 X 클리어 버튼 (`ValueListenableBuilder<TextEditingValue>`)
- 연락처 필드 제거

**1:1 채팅 시스템**
- `chat_rooms` / `chat_messages` 테이블 + RLS + Realtime (DB 실행 완료)
  - 채팅방 생성 시 author_id가 실제 게시글 owner인지 + 자기 자신과 채팅 불가 검증
  - last_message_at은 DB trigger 자동 갱신 (클라이언트 update 권한 없음)
- `ChatService`: getOrCreateRoom / getMyRooms / getMessages / sendMessage / subscribeToRoom
- `ChatRoomScreen`: 실시간 채팅 UI, 메시지 중복 제거, 날짜 구분선, 자동 스크롤
- `ChatListScreen`: 채팅 목록, 마지막 메시지 시간 표시
- 게시글 상세 하단 "찾았어요! 연락하기" 버튼 → 1:1 채팅 시작
- 게시글 owner: "해결됨으로 표시" / "다시 모집하기" 토글 (tip 제외)
- 커뮤니티 AppBar 채팅 아이콘 → ChatListScreen

**FCM 푸시 알림 (새 채팅 메시지)**
- `send-notification` Edge Function: `new_chat_message` 케이스 추가
  - payload: `{ trigger_type, recipient_id, sender_name, post_title }`
  - FCM data에 `type: 'chat'` 포함 → 앱에서 채팅 화면 라우팅 분기
- 멀티 디바이스 지원: 케이스 1/3/4 전부 `.maybeSingle()` → 전체 토큰 조회 + `Promise.all`
- `NotificationService`: `onChatNotificationTap` 콜백 + `consumePendingNotification()` (cold start 라우팅 유실 방지)
- `app.dart`: 채팅 알림 탭 → `ChatListScreen` push

**마이그레이션 / 배포**
- `supabase/migrations/community_category_expansion.sql` — DB 실행 완료
- `supabase/migrations/chat_schema.sql` — DB 실행 완료
- `send-notification` Edge Function 재배포 완료
- `flutter analyze` 0 issues

---

## 2026-06-08

### 한 일 (저녁)

**나눔&실종 · 검색 상단 그라데이션 AppBar 적용**
- 피드·프로필과 동일한 `[FFF0DC → FFFAF5]` 그라데이션 전체 탭 통일
- 검색은 TabBar 포함 높이 `kToolbarHeight + kTextTabBarHeight` 처리

**관리자 화면 community_post 신고 처리 수정**
- 기존: community_post 신고가 '댓글'로 표시, 내용 보기/삭제 불가
- 라벨 '피드 글' / '커뮤니티 글' / '기타' 분기
- 내용 보기 → `CommunityPostDetailScreen` 연결
- 삭제 → `_deleteCommunityPost()` + `CommunityService.getPostById()` 추가

**DB 마이그레이션 Supabase 실행 완료**
- community_posts 기존 테이블 보정 (image_urls, address, lat/lng, updated_at, status check)
- updated_at 자동 갱신 트리거
- auto_hide_on_reports 함수 `set search_path = public` 보정

---

### 한 일 (오후)

**UI 디자인 시스템 전체 적용 (~20개 파일)**
- 모든 화면의 하드코딩된 `Color()`, `Colors.red`, 폰트 크기 등 → `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`, `AppShadows` 상수로 통일
- `AppShadows.card`: 검정 틴트(`0x17000000`) → 갈색 틴트(`0x178D6E63`) 수정
- 주요 적용 파일: `feed_screen`, `post_detail_screen`, `community_screen`, `community_post_detail_screen`, `search_screen`, `notification_screen`, `settings_screen`, `pet_screen`, `reminder_screen`, `calendar_screen`, `login_screen` 외 다수
- `GestureDetector` → `InkWell(splashColor: AppColors.primaryLight)` 터치 피드백 개선

**피드 & 프로필 상단 그라데이션 통일**
- 피드 AppBar, 프로필 3종(ProfileScreen/MyProfileScreen/UserProfileScreen) 모두 동일 그라데이션 적용 `[FFF0DC → FFFAF5]`
- `ProfileBanner`: 아바타+통계 영역 뿐만 아니라 닉네임/팔로우 버튼/펫 칩 영역까지 그라데이션 확장
- `ProfileBannerSkeleton`: 실제 배너와 동일한 그라데이션 구조로 업데이트

**네비게이션 바 아이콘 색상 개선**
- 미선택 아이콘 `AppColors.brownLight(D7CCC8)` → `AppColors.textSecondary(8D6E63)` (더 어둡고 선명하게)

**위치 권한 온보딩 추가**
- `LocationService` 신규 생성 (`core/services/location_service.dart`)
  - `requestOnboardingIfNeeded()`: 최초 로그인 후 1회만 OS 위치 권한 다이얼로그 표시 (SharedPreferences로 중복 방지)
  - `ensurePermission(context, reason:)`: 위치 필요 기능 진입 시 강제 요청, 영구 거부 시 설정 앱 안내
  - `getCurrentPosition()`: 권한 있을 때 현재 위치 반환
- `_PetGate.initState()`에서 `showForceUpdateDialogIfNeeded` 완료 후 위치 권한 요청 연결
- AndroidManifest에 이미 `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` 있었음

---

### 한 일 (오전)

**피드 카드 레이아웃 개편 (뉴스형)**
- 전체 너비 이미지 카드 → 썸네일 우측 88×88 뉴스형으로 변경
- `_ThreadPost` 헤더: 아바타(34px) + 이름 + 펫 칩 + 시간 + ⋮ 인라인
- 사진 1장: 단독 표시 / 여러 장: 썸네일 + "+N" 뱃지
- `post_detail_screen.dart`: 단일 이미지 BoxFit.contain / 다중 PageView 캐러셀 + 도트 인디케이터

**나눔 & 실종 커뮤니티 탭 전체 구현**
- `community_post_model.dart`, `sighting_report_model.dart` 모델 생성
- `community_service.dart`: getPosts / getSightings / addSighting / addPost / updatePost / resolvePost / deletePost
- `community_screen.dart`: 전체/실종/나눔&입양 탭 필터, 카드 목록, FAB 글쓰기
- `add_community_post_screen.dart`: 카테고리 선택(실종/입양보내기/입양원해요), GPS 위치 첨부, 사진 최대 5장
- `community_post_detail_screen.dart`: 이미지 캐러셀, 실종 위치 카드(Google Maps 연동), 목격 신고 목록
- `add_sighting_screen.dart`: 목격 위치(GPS + 수동 입력) + 메모 저장
- `edit_community_post_screen.dart`: 전체 필드 수정, GPS 위치 재설정
- DB: `community_posts` FK를 `auth.users` → `profiles(id)`로 변경 (PostgREST join 오류 수정)

**게시글 옵션 메뉴 (⋮ 버튼)**
- 공유(share_plus) / 수정 / 삭제(확인 다이얼로그) / 신고 — 내 글 vs 남의 글 분기 처리
- 수정 후 화면 즉시 업데이트 (`_post` mutable state)

**이미지 콘텐츠 검열 (Google Cloud Vision SafeSearch)**
- Supabase Edge Function `moderate-images` 배포
- adult / violence LIKELY 이상 → 업로드 이미지 자동 삭제 + 에러 반환
- 피드(`post_service.dart`) + 커뮤니티(`community_service.dart`) 모두 적용
- Vision API 오류 시 무시하고 진행 (서비스 중단 방지)

**GPS 위치 기능**
- `geolocator: ^13.0.1` 추가, AndroidManifest 위치 권한 등록
- 실종 글 작성/수정 시 현재 GPS 좌표 → 주소 필드 자동 채움
- 상세 화면에서 위치 카드 탭 → `geo:` URI로 Google Maps 열기

**이미지 업로드 최적화**
- 순차 업로드(`for await`) → `Future.wait()` 병렬 업로드로 변경
- 피드/커뮤니티 서비스 양쪽 적용, 5장 기준 ~5배 속도 개선

**키워드 필터 + 신고 자동 숨김**
- `content_filter.dart`: 불법 도박·대출·마약·성인광고·스팸 URL 키워드 목록
- `addPost()` 시작 시 이미지 업로드 전에 먼저 검사 (낭비 방지)
- SQL 트리거: 신고 5회 누적 → posts.is_hidden=true / community_posts.status='hidden' 자동 전환
- getPosts 쿼리에 숨김 게시글 제외 필터 추가

### SQL 실행 필요
`supabase/migrations/auto_hide_on_reports.sql` — Supabase SQL Editor에서 실행

---

## 2026-06-01

### 팔로우 / 내 피드 / 피드 필터
- `follows` 테이블 생성 + RLS + 인덱스 — Supabase SQL Editor에서 실행 완료
- `FollowService` 신규: toggleFollow / isFollowing / getFollowCounts(count 쿼리) / getFollowingIds
- `UserProfileScreen` 신규: 팔로우 버튼 + 팔로워/팔로잉 수 + 게시글 그리드
- `MyProfileScreen` 신규: 내 게시글 그리드 + 실제 팔로워/팔로잉 수
- 네브바 변경: `내 펫` → `내 피드` (MyProfileScreen), 프로필 탭 유지
- `ProfileScreen`에 내 펫 관리 항목 추가
- 피드 카드 아바타/닉네임 탭 → UserProfileScreen
- 피드 필터 칩: 전체 / 팔로잉 / 고양이 🐱 / 강아지 🐶
- Future.wait 전체에 try/catch + finally로 무한 스피너 방지

## TODO

### 다음 할 일 (Flutter 모바일)
- [x] 캘린더 홈 화면 — 펫 없을 때 빈 화면 + 등록 유도
- [x] 캘린더 홈 화면 — 펫 있을 때 날짜별 기록 UI
- [x] 기록 추가 기능 — 예방접종(health), 몸무게(weight), 건강 메모(note)
- [x] 내 펫 화면 — 등록된 펫 목록 + 펫 추가 버튼
- [x] 피드 화면 — 스레드 스타일, 전체 유저 공개, 좋아요 + 댓글
- [x] 프로필 화면 — 유저 정보 + 설정 + 로그아웃 + 회원탈퇴 + 수정
- [x] 캘린더 UX — 날짜 탭 시 기록 먼저 표시, 상단 + 버튼으로 기록 추가
- [x] 프로필 통계 카드 탭 → 내 펫 / 전체 기록 화면으로 이동
- [x] 전체 기록 히스토리 화면 (RecordsHistoryScreen)

### 코드 리뷰 반영 완료 (2026-05-30)
- [x] posts 테이블에 `pet_id uuid references pets(id)` 추가 → `supabase_migration.sql` 실행 필요
- [x] `display_name` 통일 — post_model, post_service, profile_service 전부 수정
- [x] 피드 쿼리 join 복구 — `profiles(display_name, avatar_url)` + `pets(name, type)`
- [x] 기록 수 count 쿼리 효율화 — `.count(CountOption.exact)` 사용
- [x] 글 삭제 시 Storage 이미지 함께 삭제 — `_storagePath()` 헬퍼 + `deletePost(imageUrl:)`

### Supabase 대시보드에서 직접 실행 필요
```
-- supabase_migration.sql 내용을 SQL Editor에서 실행
alter table public.posts add column if not exists pet_id uuid references public.pets(id) on delete set null;
create policy if not exists "피드에서 펫 이름 조회 허용" on public.pets for select using (true);
```

### 남은 작업 (다음)
- [ ] **회원탈퇴 — auth.users 삭제** — profiles 삭제만으로는 auth 계정이 남음
  - Supabase Edge Function 필요: `supabase.auth.admin.deleteUser(userId)`
  - 탈퇴 시 Storage 파일(pet-photos, post-images) 정리도 함께
- [ ] **펫 편집 기능** — 내 펫 화면에서 이름/사진/품종 수정 (새 화면 필요)
- [ ] **다중 펫 캘린더 선택 UI** — 현재 첫 번째 펫만 표시, 펫 스위처 필요
- [ ] **피드 이미지 업로드 RLS 확인** — post-images Storage 버킷 정책 테스트

### 나중에 (MVP 이후)
- [ ] **유저 공개 프로필** — 피드에서 이름/아바타 탭 → 해당 유저 게시글 목록 + 통계
- [ ] 광고 (AdMob) 연동
- [ ] 프리미엄 구독 (펫 3마리 이상, 고급 통계)
- [ ] 푸시 알림
- [ ] 브랜드 제휴
- [ ] Firebase App Distribution으로 테스트 배포

### 인프라 — 미디어 스토리지 이전 (규모 성장 시)
- [ ] **Cloudflare R2로 Storage 이전** — Supabase Storage 한계 도달 시
  - **이전 기준**: Storage 사용량 80GB 초과 또는 월 비용 부담 시점
  - **이유**: R2는 egress(다운로드) 무료, AWS S3 대비 압도적 유리
    - S3: 저장 $0.023/GB + 다운로드 $0.09/GB
    - R2: 저장 $0.015/GB + 다운로드 **$0** (사진/동영상 조회가 많은 앱에 핵심)
  - **이전 작업 범위** (어렵지 않음):
    1. R2 버킷 생성 + S3 호환 API 키 발급
    2. 기존 파일 일괄 복사 스크립트 1회 실행
    3. `post_service.dart`, `pet_service.dart` 업로드 URL 변경
    4. DB `image_url`, `photo_url` 컬럼 batch update
  - **동영상 추가 시 주의**: 처음부터 길이 제한(30초~1분) 필수 — 비용 통제
  - Supabase DB(PostgreSQL)는 그대로 유지, Storage만 이전

---

## 2026-05-30 (오후)

### 한 일
- **캘린더 UX 개선**
  - 날짜 탭 → 기록 목록 바로 표시 (바텀시트 자동 노출 제거)
  - 상단 `+` 아이콘 버튼 → 선택된 날짜(없으면 오늘)의 기록 추가
  - 기록 없는 날 빈 상태 UI + "기록 추가" 버튼
  - 기록 목록에 날짜 헤더 + 추가/삭제 버튼
  - `RecordService.getAllRecords()` 추가
  - `RecordsHistoryScreen` 신규 — 전체 기록 날짜별 그룹
- **피드 스레드 스타일 전면 재설계**
  - 카드 제거 → 아바타 좌측 + 콘텐츠 우측 (Threads/Twitter 스타일)
  - 전체 유저 공개 커뮤니티 피드 (앱 사용자 누구나 글/댓글)
  - 글쓰기는 펫 등록 유저만 (FAB, 미등록 시 비활성)
  - 좋아요 optimistic update, 댓글 스레드 스타일
- **프로필 화면 개선**
  - 통계 카드 클릭: 등록한 펫 → PetScreen, 총 기록 → RecordsHistoryScreen
  - 프로필 수정 화면 추가 (이름 + 사진 변경)
  - profiles 테이블 join 에러 → auth 메타데이터만 사용으로 수정
  - ListTile Material 경고 수정
- **기기 빌드 (Galaxy S25+)**
  - posts.pet_id FK 없음, profiles.full_name 컬럼 없음 → 로컬 매칭 + 메타데이터로 우회

---

## 2026-05-30 (오전)

### 한 일
- **캘린더 기록 기능 전체 구현**
  - `record_model.dart` — Record 모델 (type/emoji/label 포함)
  - `record_service.dart` — getRecordsForMonth / addRecord / deleteRecord
  - `add_record_screen.dart` — 기록 입력 화면 (예방접종, 몸무게, 건강 메모)
  - `calendar_screen.dart` — 펫 로딩 + 월별 기록 로딩 + 날짜 마커(점) + 날짜별 기록 목록
  - `record_bottom_sheet.dart` — 탭 시 type string 반환 → AddRecordScreen으로 이동
- **펫 없을 때 빈 화면 + 등록 유도 UI**
- **내 펫 화면 (PetScreen) 구현**
  - 펫 카드 목록 (사진/이모지 아바타, 이름, 종류, 품종, 나이 칩, 성별 칩)
  - 빈 상태 + FAB으로 펫 추가
- **프로필 화면 (ProfileScreen) 구현**
  - 유저 헤더 (소셜 아바타, 이름, 이메일)
  - 통계 (등록한 펫 수, 총 기록 수)
  - 설정: 알림 토글 (SharedPreferences)
  - 정보: 이용약관, 개인정보처리방침, 앱 버전
  - 계정: 로그아웃, 회원탈퇴 (profiles cascade delete)
- **피드 화면 (FeedScreen) 전체 구현**
  - `post_model.dart` — Post / Comment 모델 (profiles·pets join)
  - `post_service.dart` — getPosts / addPost / deletePost / toggleLike / getComments / addComment / deleteComment
  - `feed_screen.dart` — 글 목록 (optimistic 좋아요), 펫 없으면 FAB 비활성, pull-to-refresh
  - `add_post_screen.dart` — 펫 선택 + 내용 + 이미지 첨부 + Supabase Storage
  - `post_detail_screen.dart` — 글 상세 + 댓글 목록 + 댓글 입력 + 내 글/댓글 삭제

### 플로우
날짜 탭 → 바텀시트 → AddRecordScreen → 저장 → 캘린더 오렌지 점
피드 FAB → AddPostScreen → 저장 → 피드 목록 / 탭 → PostDetailScreen → 댓글

### 현재 상태
- 4개 탭 전체 MVP 완성 (캘린더, 피드, 내 펫, 프로필)
- Supabase records / posts / comments / likes / pets / profiles 테이블 연동
- 사진 기록(캘린더)은 미구현 — "곧 추가" 안내

---

## 2026-05-29

### 한 일
- **앱 브랜딩 확정**
  - 앱 이름: **포포와 토토**
  - 컬러: 크림 (#FDFBF5) + 오렌지 (#FF8C42)
  - 캐릭터: 포포(고양이) + 토토(강아지) 공식 채택
  - 슬로건: "매일의 기록이 사랑이 된다"
- **카카오 네이티브 로그인 완성**
  - `loginWithKakaoTalk()` 전환 (KakaoTalk 앱 연동)
  - Android 키 해시 등록 (`rxLZL3QGtmo6gZU1+BbyomM7mdc=`)
  - Supabase Kakao Provider Client ID → 네이티브 앱 키로 교체
  - Supabase Email Confirmation OFF (Kakao unverified email 대응)
- **로딩 화면 완성**
  - 포포&토토 이미지 통통 튀기기 애니메이션
  - 주변 🐾 발바닥 둥둥 떠다니는 효과
  - 배경색 이미지와 완전 매칭 (#FDFBF5)
- **펫 등록 화면 (AddPetScreen) 구현**
  - 상단: 포포/토토 얼굴 + "아이를 소개해주세요!" 헤더
  - 종류 선택: 포포발자국(오렌지)/토토발자국(브라운) 이미지 버튼
  - 프로필 사진 선택 (image_picker)
  - 이름 / 성별 / 생일(캘린더 전용) / 품종 입력
  - 상단 "나중에" 버튼으로 스킵 가능
  - Supabase pets 테이블 저장 성공
- **로그인 후 펫 체크 로직 (PetGate)**
  - 펫 없으면 → 펫 등록 화면
  - 펫 있으면 → 메인 앱

### Supabase pets 테이블 실제 컬럼명
- `birth_date` (birthday 아님)
- `gender` (text, 직접 추가)
- `photo_url` (profile_image_url 아님)
- `type` (text, 직접 추가) — 'cat' | 'dog'

### 현재 상태
- 로그인(Google + 카카오) → 펫 등록 → 메인 앱 진입 플로우 완성
- 메인 앱 내 각 화면은 아직 플레이스홀더

### 다음 할 일
- 캘린더 홈 화면 구현 (기록 핵심 기능)
- 내 펫 화면 (등록된 펫 목록)

---

## 2026-05-28

### 한 일
- GitHub에서 어제 작업 pull (Flutter mobile 코드 포함)
- 갤럭시 S25+ 와이파이 무선 디버깅 연결 (adb tcpip)
- Supabase DB 설계 및 테이블 생성
  - profiles, pets, records, posts, comments, likes 테이블
  - RLS 정책 전체 적용
  - 인덱스 추가 (records, posts, comments, likes)
  - updated_at 트리거 추가
  - Storage 버킷 생성 (pet-photos, post-images)
  - likes/comments count 자동 업데이트 트리거
- Google OAuth 로그인 구현 (Flutter)
  - Google Cloud Console에서 Web + Android OAuth 클라이언트 생성
  - Supabase Google Provider 설정
  - `app_links` 패키지로 딥링크 처리
  - `com.pawprint.mobile://login-callback/` 딥링크 스킴 등록
  - Android intent-filter 추가
  - 실기기(갤럭시 S25+) 로그인 테스트 성공
- 카카오 로그인 구현 (Flutter)
  - `kakao_flutter_sdk_user` ^1.9.9 패키지 추가
  - `KakaoSdk.init()` + native app key 설정
  - `signInWithIdToken(provider: OAuthProvider.kakao)` 로 Supabase 연동
  - AndroidManifest에 Kakao scheme, AuthCodeHandlerActivity, queries 추가
  - Kakao 개발자 콘솔 OpenID Connect 활성화
  - 현재 `loginWithKakaoAccount()` 사용 중 (웹뷰 방식)
  - 프로필 화면 구현 (아바타, 닉네임, 이메일, 로그아웃)

### 현재 상태
- 모바일: Google + 카카오 로그인 완료, 메인 화면(캘린더) 진입 가능
- DB: 전체 스키마 완성, RLS + 인덱스 적용
- 웹: 아직 백엔드 미연결 (다음 작업)

### 다음 할 일
- 카카오 네이티브 로그인 (KakaoTalk 앱 연동) 전환
  - 카카오 개발자 콘솔에서 Android 플랫폼 등록 및 키 해시 등록 필요
  - 디버그 키 해시: `i6yFzEEMq8yQZsAAvEBtIfY6SDo=`
  - 새 콘솔 URL: `https://developers.kakao.com/console/app/1471106/` (플랫폼 메뉴 위치 변경됨)
  - 등록 후 `auth_service.dart`에서 `loginWithKakaoAccount()` → `loginWithKakaoTalk()` 전환

### 메모
- Supabase Google Provider에는 반드시 **Web 클라이언트 ID** 사용 (Android ID 아님)
- Redirect URLs에 `com.pawprint.mobile://login-callback/` 등록 필수
- `config.dart`는 `.gitignore`에 포함됨 (Supabase URL, anon key, Web Client ID, Kakao native key 보관)
- Kakao `User` 클래스 충돌 → `import ... hide User` 로 해결
- `loginWithKakaoTalk()`/`loginWithKakaoAccount()`에 `scopes` 파라미터 없음 (v1.x)

---

## 2026-05-27

### 한 일
- Next.js 16 + Supabase + TypeScript 프로젝트 세팅
- Firebase 계획에서 Supabase + Cloudflare로 스택 변경
- 전체 파일 구조 구축 (components, hooks, lib, types)
- MVP 페이지 전부 작성 (피드, 글 작성, 글 상세, 프로필, 로그인)
- WEB_COMMUNITY_HARNESS.md 하네스 문서 작성
- GitHub push → LeviLee0611/pawprint
- DEVLOG.md 작성
- Flutter 모바일 앱 초기 세팅 (캘린더 UI + Supabase 연동 구조)
  - `mobile/` 디렉토리에 Flutter 프로젝트 생성
  - 일정 관리용 캘린더 화면 컴포넌트 작성
  - Supabase Flutter SDK 연결 준비
- GitHub PAT 인증 설정 완료 (Windows 자격 증명 관리자에 자동 저장)
- GitHub origin에 전체 코드 최종 푸시

### 스택 확정
- **웹:** Next.js 16 (App Router) + Supabase + Tailwind CSS 4 + TypeScript
- **모바일:** Flutter + Supabase
- **배포:** Cloudflare Pages (웹), 추후 앱스토어 (모바일)

### 현재 상태
- 웹: UI 코드 완성, Supabase 테이블/Auth/Storage 설정 미완료 → 백엔드 연결 전
- 모바일: 초기 구조만 잡힌 상태, 기능 개발 전

### 메모
- `.env.local` Supabase URL + anon key 입력 완료
- `@cloudflare/next-on-pages` 패키지가 Next.js 16 아직 미지원 → 배포 시점에 해결
- 다음 우선순위: Supabase 테이블 생성 (DEVLOG TODO 1단계)
