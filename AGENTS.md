# 포포와 토토 — Agent Workflow Rules

## 프로젝트 개요
- **앱:** Flutter + Supabase 반려동물 기록/커뮤니티 앱
- **메인 작업 폴더:** `mobile/lib/`
- **백엔드:** `supabase/migrations/`, `supabase/functions/`
- **웹 (보류):** `src/` — 건드리지 말 것

---

## 병렬 에이전트 워크플로우

### 언제 병렬 에이전트를 쓰나
| 상황 | 방식 |
|---|---|
| 파일 1~2개 수정 | Main 직접 처리 |
| 3개 이상 파일, 다른 Zone | 병렬 에이전트 |
| 크로스 피처 리팩토링 | Zone당 에이전트 1개 |
| 탐색/분석만 필요 | Explore 에이전트 |

### 에이전트 역할
| 타입 | 역할 |
|---|---|
| Plan | 설계, 인터페이스 계약 정의, 의존성 분석 |
| Explore | 파일 탐색, 심볼 검색, 영향 범위 파악 |
| general-purpose | 실제 코드 수정/구현 |

### 병렬 실행 순서
```
1. Plan 에이전트 → 설계 + 인터페이스 계약 확정
2. general-purpose 에이전트 N개 동시 발사 (Zone 기준 파일 소유권 분리)
3. Main → flutter analyze + 결과 취합
```

---

## 파일 소유권 — Zone 지도

병렬 작업 시 에이전트마다 하나의 Zone만 담당. Zone 경계를 넘으면 안 됨.

```
Zone A │ feed + search
       │ mobile/lib/features/feed/
       │ mobile/lib/features/search/

Zone B │ community + chat
       │ mobile/lib/features/community/
       │ mobile/lib/features/chat/

Zone C │ calendar + pet
       │ mobile/lib/features/calendar/
       │ mobile/lib/features/pet/

Zone D │ profile + notification
       │ mobile/lib/features/profile/
       │ mobile/lib/features/notification/

Zone E │ auth + feedback + admin
       │ mobile/lib/features/auth/
       │ mobile/lib/features/feedback/
       │ mobile/lib/features/admin/

Zone F │ 백엔드 전용 (SQL, Edge Functions)
       │ supabase/migrations/
       │ supabase/functions/
       │ backup_schema.sql
       │ database.md
```

---

## Main 전용 파일 (에이전트 절대 수정 금지)

```
mobile/lib/main.dart
mobile/lib/app.dart
mobile/lib/config.dart
mobile/lib/core/theme/app_theme.dart
mobile/lib/features/profile/screens/settings_screen.dart
```

이 파일들은 여러 Zone이 참조하는 허브. 병렬 수정 시 충돌 확정. Main이 직접 처리.

---

## core/ 규칙

`mobile/lib/core/` 는 전체 Zone이 공유하는 공통 레이어.

- **수정 필요 시:** Main이 직접 처리하거나, core 전용 에이전트 1개만 배정
- **에이전트가 core/를 건드려야 한다면:** 반드시 Plan 단계에서 먼저 인터페이스 확정 후 진행

---

## 인터페이스 계약 원칙

병렬 에이전트 발사 전, Plan 단계에서 반드시 확정:
1. 새 함수 시그니처 (파라미터, 반환 타입)
2. 새 모델 필드명 + 타입
3. DB 스키마 변경 내용
4. Zone 간 데이터 흐름

계약이 확정되지 않으면 병렬 에이전트 발사하지 않음.

---

## 검증 게이트

병렬 에이전트 완료 후 반드시:
```
flutter analyze   ← 0 issues 목표
```
issues 있으면 Main이 직접 픽스 후 완료 처리.

---

## Next.js (웹, 보류 중)

`src/` 폴더는 Next.js 16 — 기존 Next.js와 API/컨벤션이 다름.
코드 작성 전 `node_modules/next/dist/docs/` 가이드 확인 필수.
현재 개발 보류 상태 — 지시 없으면 건드리지 말 것.
