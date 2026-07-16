# SAM Code Agent

**언어:** 한국어 | [English](README.en.md)

`sam-codex` 하나의 전용 명령으로 Codex를 SAM 경유로 실행합니다.

## 먼저: 수동 설정

설치형 배포보다 먼저 아래 수동 단계로 키·연결·분리된 CLI·기본 앱 전환과
복원을 하나씩 확인하세요.

- [macOS 수동 설정](MANUAL_SETUP.md)
- [macOS manual setup (English)](MANUAL_SETUP.en.md)

## 자동화 설치 안내

1. SAM 웹의 **API Keys**에서 `Code Agent - 내 기기`처럼 구분되는 전용 키를
   하나 만듭니다. 일반 서비스 키와 섞어 쓰지 않는 것을 권장합니다.
2. 이 저장소의 운영체제별 설치 프로그램을 한 번 실행하고, 숨김 입력창에 그
   전용 키만 붙여 넣습니다. 직접 `.env`나 `config.toml`을 만들 필요가 없습니다.
3. 이후에는 `sam-codex`만 실행합니다.

```text
sam-codex
```

설치 프로그램은 키를 해당 기기의 `~/.sam-code-agent/`에만 저장하고, Codex
설정은 `~/.codex-sam/`에 분리합니다. 키를 바꾸려면 설치 프로그램을 다시
실행해 새 Code Agent 전용 키를 입력하면 됩니다.

Code Agent는 `SAM_CODE_API_KEY`만 사용합니다. 이전에 `SAM_API_KEY`로 설정한
사용자는 수동 설정 2~5단계 또는 설치 프로그램을 한 번 다시 실행해 키 파일을
갱신하세요.

## Codex 사용 방식 2가지

| 방식 | 실행 명령 | 설정 홈 | 용도 |
| --- | --- | --- | --- |
| 기본 Codex | `codex` 또는 `codex app` | `~/.codex` | 기존 ChatGPT/Codex 계정과 일반 OpenAI 설정 |
| SAM Codex | `sam-codex` | `~/.codex-sam` | SAM API 키와 `sam-codex-agent`를 사용하는 터미널 세션 |

두 방식은 같은 설정 파일을 공유하지 않습니다. `sam-codex`는 일반 `codex`를
바꾸지 않으며, SAM을 사용할 때만 실행합니다.

## 제공 기능

- `sam-codex-agent`를 사용하는 전용 `sam-codex` 터미널 명령
- SAM 세션에서만 불러오는 로컬 SAM API 키 파일
- 일반 Codex 설정이 SAM 세션을 덮어쓰지 못하는 별도 설정 공간
- 키·네트워크를 확인하는 SAM 직접 호출과 Codex 스모크 테스트
- macOS·Windows용 선택적 터미널 바로가기

## 시작 전 준비

저장소를 내려받기 전에 다음 공통 도구를 설치해야 합니다.

1. Git
2. Node.js LTS(npm 포함)
3. Codex CLI

운영체제별 가이드에 PATH와 PowerShell 실행 정책 문제를 포함한 정확한
명령어가 있습니다.

## 운영체제 선택

- [macOS: 설치·키 관리·테스트·바로가기](docs/macos.md)
- [Windows: 설치·키 관리·테스트·바로가기](docs/windows.md)
- [macOS English guide](docs/macos.en.md)
- [Windows English guide](docs/windows.en.md)

## 일상 사용

```text
codex       # 기본 Codex: ~/.codex
sam-codex   # SAM Codex: ~/.codex-sam
```

SAM 세션에서는 일반 `codex` 대신 항상 `sam-codex`를 사용합니다. 비대화형
요청은 `sam-codex exec ...`로 실행합니다.

## 분리 방식

설치 프로그램은 기존 Codex 홈과 별도로 다음 파일을 만듭니다.

- `~/.codex-sam/config.toml`: SAM provider·모델 설정
- `~/.sam-code-agent/env`(macOS) 또는 `~/.sam-code-agent/env.ps1`(Windows):
  로컬 SAM API 키 파일
- `sam-codex`: 키를 불러오고 실행 프로세스에만
  `CODEX_HOME=~/.codex-sam`을 설정하는 전용 wrapper

wrapper는 SAM provider 설정도 Codex 실행 옵션으로 직접 전달하므로,
일반 `~/.codex/config.toml`이 SAM 세션을 조용히 덮어쓸 수 없습니다.

## API 키 보안

Code Agent 전용 키 소유자에게 `agent:codex` 또는 `agent:coding_agents`
권한이 있어야 합니다. 실제 키는 Git, 문서, 스크린샷, 셸 히스토리 명령,
프로젝트 `.env` 파일에 절대 넣지 마세요.

운영체제별 가이드는 키를 안전하게 바꾸는 방법, SAM 직접 호출 테스트,
그리고 `sam-codex` 스모크 테스트를 각각 안내합니다.

## 기본 Codex 데스크톱 앱을 SAM으로 전환하기

기본 ChatGPT/Codex 데스크톱 앱도 `~/.codex`를 SAM provider로 **일시 전환**해
사용할 수 있습니다. 이 방식은 기존 계정 모드와 동시에 쓰는 기능이 아니라,
기본 앱의 provider를 바꿨다가 복원하는 방식입니다. 먼저 `sam-codex` 스모크
테스트가 성공한 뒤에만 운영체제별 전환기를 사용하세요.

- macOS: [기본 데스크톱 앱 전환·복원](docs/macos.md#선택-기본-codex-데스크톱-앱을-sam으로-일시-전환)
- Windows: [기본 데스크톱 앱 전환·복원](docs/windows.md#선택-기본-windows-codex-데스크톱-모드를-sam으로-일시-전환)

전환 뒤에는 앱 창만 닫지 말고 `Cmd-Q`(macOS) 또는 완전 종료(Windows) 후
다시 여세요. macOS의 GUI 세션 키는 로그아웃·재부팅 뒤 사라지므로, 그때는
앱을 열기 전에 전환 명령을 한 번 더 실행해야 합니다. `sam-codex app`은 별도
SAM-Codex 앱을 만들거나 기존 데스크톱 앱을 안전하게 전환하는 명령이 아닙니다.

## 현재 범위

이 디렉터리는 Codex를 대상으로 합니다. Claude Code와 MCP 설정은 설치
경로가 안정된 뒤 별도 가이드로 제공합니다.
