# 포포와 토토 Dev Log

---

## 2026-06-02

### 신규 기능
- **검색** — 유저 이름 / 게시글 내용 검색, 400ms 디바운스, race condition 방어
- **알림 화면** — Supabase DB 트리거 기반 (좋아요·댓글·팔로우 자동 생성/삭제), 읽음 처리, 배지
- **강제 업데이트 / 점검 모드** — `app_config` 테이블 연동, storeUrl 없을 때 차단 방지
- **게시글 수정** — EditPostScreen, 이미지 교체/삭제 지원 (DB 성공 후 기존 이미지 삭제)
- **펫 공개/비공개** — `is_public` 컬럼, 비공개 펫은 타인 프로필에서 제외
- **목욕(bath) 기록 타입 추가** — record_type enum 확장
- **차단 기능** — `blocks` 테이블, `block_user` RPC(팔로우 관계 정리), 피드 필터링

### 개선
- `cached_network_image` + Supabase Transform URL 도입 (이미지 로딩 최적화)
- 피드 이미지 Image.network 원복 (220px, BoxFit.cover)
- 피드 페이지네이션 `_rawOffset` 별도 추적 (차단 필터 후 offset 불일치 수정)
- 새 상태 이미지 적용 (로딩·알림·에러·검색·업데이트·점검)
- 네브바 5탭으로 확장 (홈 / 피드 / 검색 / 내피드 / 프로필)

### 버그 수정 (코드 리뷰 반영)
- 검색 clear 버튼 즉시 반영
- `markAllRead` await + 로컬 상태 즉시 갱신
- `_originals` 폴더 앱 번들 제외
- `force_update_service.dart` storeUrl 빈 값 탈출 불가 버그 수정

### DB 마이그레이션
- `notifications` 테이블 + 트리거 5개
- `app_config` 테이블
- `pets.is_public` 컬럼
- `record_type` enum에 `bath` 추가
- `blocks` 테이블 + `block_user` RPC

---

## 2026-06-03 완료

### 🔔 알림
- [x] 팔로우/좋아요/댓글/새 게시글/신고 FCM 푸시 알림 — send-notification Edge Function + pg_net 트리거
- [x] 알림 설정 화면 — 종류별 on/off, notification_settings 테이블

### 🐛 버그 수정
- [x] 팔로워/팔로잉 목록 오류 — FK 조인 실패 → 2단계 쿼리로 수정
- [x] 아바타 불일치 — userMetadata → profiles 테이블로 소스 통일, 소셜 로그인 시 자동 동기화
- [x] 알림 배지 잘림 — Badge를 Icon만 감싸도록 변경
- [x] 아바타 규격 — resize=cover로 정사각형 크롭 (피드/프로필/팔로우 목록 전체)

### ✨ 신규 기능
- [x] 게시글 공유 — share_plus, 피드 ⋯ 바텀시트에 공유하기/신고하기 분리
- [x] 닉네임 중복 방지 — 저장 전 중복 체크 + DB unique 제약

### 🔧 기술
- [x] Keystore 릴리즈 서명 설정 (key.properties 없으면 debug 폴백)
- [x] Codex 피드백 반영: JWT 검증, unawaited 패턴, AuthGate StatefulWidget, updated_at 트리거

---

## 2026-06-04 완료

### ✅ FCM / 알림
- [x] **FCM 멀티 디바이스 지원** — fcm_tokens 구조 변경 (owner_id PK → id PK + token UNIQUE), 기기별 토큰 독립 관리
- [x] **로그아웃 시 토큰 삭제** — signOut() 전 clearToken() 호출, 리스너 StreamSubscription 관리로 중복 등록 방지
- [x] **알림 설정 화면 연결** — 프로필 → 알림 설정 (종류별 on/off)

### ✅ 피드
- [x] **게시글 저장 기능** — 북마크 버튼, SavedPostsScreen, saves 테이블 + RLS
- [x] **인기 게시글 탭 🔥** — 좋아요 많은 순, 차단 유저 제외

### ✅ 건강 기록
- [x] **체중 변화 그래프** — fl_chart, 요약 카드 + 라인 차트, 내 펫 → ⋯ → 체중 그래프
- [x] **펫 생일 FCM 알림** — send-birthday Edge Function, get_birthday_pets RPC, 당일 중복 방지 테이블, CRON_SECRET 보호

### ✅ 기타
- [x] **구버전 폴더 정리** — web/, nyang_pawprint/ 삭제, pawprint/ 단일 작업 폴더로 통일

---

## 2026-06-05 작업 예정

### 🎨 UX 인터랙션
- [ ] **좋아요/저장 버튼 애니메이션** — 탭 시 하트·북마크가 살랑살랑 튀기는 효과 (ScaleTransition or AnimationController)

### 💬 댓글
- [ ] **이모지 리액션** — 좋아요 외 다양한 이모지 반응 (❤️ 😂 😮 😢 👍)
- [ ] **댓글 답글 UI** — parent_id는 DB에 있음, 화면만 없음

### 🚀 배포 준비
- [ ] **AAB 빌드 + 정식 서명 키 적용** — upload-keystore.jks 연결, `flutter build appbundle --release`
- [ ] **Play Store 등록** — 스토어 설명·스크린샷·심사 제출

### ✨ 기능 개선
- [ ] **피드 필터 서버사이드 전환** — 현재 클라이언트 필터라 20개 중에서만 걸림
- [ ] **검색 개선 (보류)** — 유저 피드백 보고 방향 결정 (태그 vs 벡터 검색)

### 🛠 운영
- [ ] **다크모드**
- [ ] **상표 출원** — patent.go.kr / 약 6만원 / 앱 출시 전 필수

---
