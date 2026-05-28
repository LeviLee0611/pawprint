# Codex 리뷰 프롬프트

아래 프롬프트를 Codex에 붙여넣어 코드 리뷰를 요청하세요.

---

## 프롬프트 템플릿

```
아래는 "냥발도장" 앱의 오늘 작업 내용입니다.
DEVLOG.md의 [날짜] 섹션과 관련 코드를 검토해주세요.

검토 항목:
1. **보안** — RLS 정책 허점, 인증 우회 가능성, API 키 노출 위험
2. **최적화** — 불필요한 쿼리, 인덱스 누락, N+1 문제
3. **효율성** — 코드 중복, 더 나은 패턴, 불필요한 패키지
4. **법적/정책** — Google OAuth 정책 준수, 개인정보 처리, 앱스토어 정책
5. **안정성** — 에러 처리 누락, 예외 케이스, 크래시 가능성

검토할 파일:
- mobile/lib/main.dart
- mobile/lib/features/auth/services/auth_service.dart
- mobile/lib/features/auth/screens/login_screen.dart
- mobile/supabase_setup.sql
- mobile/supabase_indexes.sql

각 항목별로 문제점과 수정 방법을 구체적으로 알려주세요.
```

---

## 사용 방법

1. 위 프롬프트 복붙
2. 검토할 파일 내용을 프롬프트 아래에 첨부
3. Codex에 전송
