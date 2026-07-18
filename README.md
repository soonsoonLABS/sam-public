# SAM Public

**언어:** 한국어 | [English](README.en.md)

SAM(SoonSoon AI Management)을 지원 클라이언트에서 사용할 수 있도록 돕는
공개 도구, 설치 파일, 문서 모음입니다.

## 처음 시작

먼저 [`00-sam-setup/`](00-sam-setup/)에서 SAM API 키를 입력하고, 키
앞부분만 확인한 뒤, `Hello SAM` 테스트 호출까지 진행하세요.

SAM 사용 키의 표준 로컬 위치는 `~/.sam/`입니다. 다른 에이전트도 이 경로의
`env` 또는 `env.ps1`만 읽게 맞추면 키가 서로 달라지는 문제를 줄일 수
있습니다.

## 문서

- [`00-sam-setup/`](00-sam-setup/): macOS와 Windows에서 처음 SAM 환경을
  설정하는 가장 짧은 가이드
- [`01-sam-skills/`](01-sam-skills/): AI 에이전트가 전역 설정에서 읽을
  SAM API 기본 사용 스킬 문서
- [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/): Codex CLI/Desktop을 SAM
  Code Agent로 연결하는 도구와 가이드

## 보안

이 저장소에는 SAM 서버 코드, 운영 설정, 인증 정보가 들어가지 않습니다.
API 키를 Git 추적 파일, 공유 문서, 이슈, 명령 기록, URL에 넣지 마세요.

사용자 기기의 로컬 키 파일은 Git 저장소 밖의 `~/.sam/`에만 둡니다. 키를
교체한 뒤에는 이미 실행 중인 CLI나 에이전트 프로세스를 다시 시작하세요.
