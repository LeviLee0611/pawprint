@AGENTS.md

## 작업 규칙

- 커밋/푸시는 명시적 요청 시에만
- 기술적 세부사항은 자율 결정, 근본적인 제품 방향 변경 시에만 질문
- 응답은 간결하게

## 핵심 파일 위치

- Flutter 앱: `mobile/lib/`
- Supabase 설정: `mobile/lib/config.dart` (gitignore)
- DB 스키마 백업: `backup_schema.sql`
- 개발 기록: `DEVLOG.md`
- TODO: `TODO.md`

## 디버깅 환경

- 기기: 갤럭시 S25+ 무선 ADB (포트 매번 변경)
- 연결: `adb connect <기기IP>:<포트>` (무선 디버깅 설정 화면에서 IP/포트 확인)

## 병렬 에이전트 사용 기준

3개 이상 파일을 다른 Zone에서 수정해야 할 때 자동으로 병렬 에이전트 적용.
Zone 정의와 파일 소유권 규칙은 AGENTS.md 참조.
