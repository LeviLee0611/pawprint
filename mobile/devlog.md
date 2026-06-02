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
