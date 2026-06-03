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

## 다음 작업 (우선순위 순)

### 🚀 배포 준비
- [ ] **AAB 빌드 + Play Store 등록** — `flutter build appbundle --release`, 스토어 설명·스크린샷 준비
- [ ] **상표 출원** — patent.go.kr / 약 6만원 / 앱 출시 전 필수
- [ ] **AI 이미지 작가 리터치** — 저작권 등록을 위해 AI 단독 생성물 재작업

### ✨ 미완성 기능
- [ ] **홈 → 피드 사진 연동** — 홈에서 기록 저장 시 "피드에도 올리시겠습니까?" 다이얼로그
- [ ] **검색 전반 개선** — 현재 검색 UX/결과 품질 점검
- [ ] **댓글 답글 UI** — parent_id는 DB에 있음, 화면만 없음
- [ ] **피드 필터 서버사이드 전환** — 현재 클라이언트 필터라 20개 중에서만 걸림

### 🛠 운영
- [ ] **관리자 도구** — 신고 처리 화면, 유저 관리
- [ ] **다크모드**
- [ ] **로딩 스켈레톤 UI**

---
