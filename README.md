# SAM Public

**언어:** 한국어 | [English](README.en.md)

SAM(SoonSoon AI Management)을 로컬 CLI에서 안전하게 사용하는 공개 가이드와
설치 도구입니다. 기본 원칙은 **공식 CLI는 그대로 두고, SAM 전용 명령만
별도로 추가**하는 것입니다.

## 권장 진행 순서

1. [`00-sam-setup/`](00-sam-setup/)에서 SAM 서비스와 공용 API 키를 비용
   없는 discovery 호출로 확인합니다.
2. [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/)에서 기존 `codex`와
   분리된 `sam-codex`를 설치합니다.
3. [`03-Code-Agent-Claude/`](03-Code-Agent-Claude/)에서 기존 `claude`와
   분리된 `sam-claude`를 설치합니다.
4. 필요하면 [`04-AionUI-Add-on/`](04-AionUI-Add-on/)에서 두 wrapper를 AionUI
   앱의 코딩 에이전트로 등록합니다.
5. 필요 없어진 전용 명령을 개별 해제하고, 마지막에만 공용 키 파일을
   삭제합니다.

## 명령과 설정의 분리

| 명령 | 연결 대상 | 로컬 설정 | 인증 |
| --- | --- | --- | --- |
| `codex` | OpenAI / ChatGPT | `~/.codex` | 기존 OpenAI 로그인 또는 키 |
| `sam-codex` | SAM V2 OpenAI | `~/.codex-sam` | 공용 `SAM_API_KEY` |
| `claude` | Anthropic | `~/.claude` | 기존 Anthropic 로그인 또는 키 |
| `sam-claude` | SAM V2 Anthropic | `~/.claude-sam` | 같은 `SAM_API_KEY` |

SAM 키의 표준 로컬 위치는 `~/.sam/`입니다. `sam-codex`와 `sam-claude`는
이 폴더의 같은 키를 읽습니다. 한쪽을 해제해도 다른 명령이 계속 쓸 수
있도록 공용 키 파일은 자동으로 삭제하지 않습니다.

## 문서

- [`00-sam-setup/`](00-sam-setup/): 환경·네트워크·공용 키·권한 테스트
- [`01-sam-skills/`](01-sam-skills/): AI 에이전트용 SAM API 운용 지침
- [`02-Code-Agent-Codex/`](02-Code-Agent-Codex/): 공식 Codex와
  `sam-codex` 설치·검증·해제
- [`03-Code-Agent-Claude/`](03-Code-Agent-Claude/): 공식 Claude Code와
  `sam-claude` 설치·검증·해제
- [`04-AionUI-Add-on/`](04-AionUI-Add-on/): 설치한 두 wrapper를 AionUI 앱의
  코딩 에이전트로 등록 (선택)

## 보안과 비용

- 키 값을 Git 추적 파일, 문서, 이슈, URL, 스크린샷 또는 명령 기록에 직접
  넣지 마세요.
- `/health`와 모델 discovery는 모델을 생성하지 않으므로 모델 사용량이
  발생하지 않습니다.
- `sam-codex exec ...`와 `sam-claude -p ...` 같은 실제 생성 테스트부터
  SAM 사용량과 비용이 기록될 수 있습니다.
- 공식 `codex`/`claude` 트래픽은 SAM을 거치지 않으며 SAM 사용량에도
  기록되지 않습니다.
