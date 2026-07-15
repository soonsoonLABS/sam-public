# SAM Code Agent

**언어:** [English](README.md) | 한국어

`sam-codex` 하나의 전용 명령으로 Codex를 SAM 경유로 실행합니다.

이 설치 도구는 기존 ChatGPT/Codex 환경과 SAM 환경을 분리합니다. 일반
`codex` 명령을 바꾸지 않으며, SAM을 사용할 때만 `sam-codex`를 실행하면
됩니다.

## 제공 기능

- `sam-codex-agent`를 사용하는 전용 `sam-codex` 터미널 명령
- SAM 세션에서만 불러오는 로컬 SAM API 키 파일
- 일반 Codex 설정이 SAM 세션을 덮어쓰지 못하는 별도 설정 공간
- 키·네트워크를 확인하는 SAM 직접 호출과 Codex 스모크 테스트
- macOS·Windows용 선택적 데스크톱 바로가기

## 시작 전 준비

저장소를 내려받기 전에 다음 공통 도구를 설치해야 합니다.

1. Git
2. Node.js LTS(npm 포함)
3. Codex CLI

운영체제별 가이드에 PATH와 PowerShell 실행 정책 문제를 포함한 정확한
명령어가 있습니다.

## 운영체제 선택

- [macOS: 설치·키 관리·테스트·바로가기](docs/ko/macos.md)
- [Windows: 설치·키 관리·테스트·바로가기](docs/ko/windows.md)
- [macOS English guide](docs/macos.md)
- [Windows English guide](docs/windows.md)

## 일상 사용

```text
sam-codex
```

SAM 세션에서는 일반 `codex` 대신 항상 `sam-codex`를 사용합니다.
비대화형 요청은 `sam-codex exec ...`로 실행합니다.

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

키 소유자에게 `agent:codex` 또는 `agent:coding_agents` 권한이 있어야
합니다. 실제 키는 Git, 문서, 스크린샷, 셸 히스토리 명령, 프로젝트 `.env`
파일에 절대 넣지 마세요.

운영체제별 가이드는 키를 안전하게 바꾸는 방법, SAM 직접 호출 테스트,
그리고 `sam-codex` 스모크 테스트를 각각 안내합니다.

## 데스크톱 앱 참고

전용·권장 경로는 터미널의 `sam-codex`입니다. macOS의 `sam-codex app`은
ChatGPT 데스크톱 앱을 열 수 있지만, 별도의 신뢰할 수 있는 SAM 프로필을
매번 보장하지는 않습니다. Windows는 CLI 테스트 성공 후에만 선택적으로
데스크톱 전환기를 사용하세요. 이는 별도 SAM-Codex 앱을 설치하는 기능이
아니라 기존 Windows Codex 데스크톱 앱의 사용자 설정을 임시 변경하는
기능입니다. Windows 가이드에 한 줄 복원 명령과 복구 안내가 있습니다.

## 현재 범위

이 디렉터리는 Codex를 대상으로 합니다. Claude Code와 MCP 설정은 설치
경로가 안정된 뒤 별도 가이드로 제공합니다.
