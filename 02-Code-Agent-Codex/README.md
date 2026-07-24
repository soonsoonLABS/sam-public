# SAM Codex CLI

**언어:** 한국어 | [English](README.en.md)

SAM 모델과 MCP 도구를 기존 Codex와 분리된 환경에서 사용하는 설치 패키지입니다.
일반 `codex`와 기존 ChatGPT/Codex 계정 설정은 바꾸지 않습니다.

## 제공 범위

- V2 OpenAI Responses: `https://sam.soonsoon.ai/v2/openai`
- Azure Foundry 및 AWS Bedrock Mantle 모델 선택
- SAM MCP: 웹 검색, 공개 페이지 읽기, 페이지 내 찾기, 월간 사용량 조회
- 전용 실행 명령: `sam-codex`

기본 Codex의 provider-hosted 검색은 의도적으로 끕니다. 검색은 SAM MCP가
수행하고, 검색 사용량은 SAM에 기록됩니다.

## 설치

먼저 Code Agent 권한이 있는 SAM API 키를 준비하고 Codex CLI를 설치합니다.

```bash
codex --version
git clone https://github.com/soonsoonLABS/sam-public.git
cd sam-public/02-Code-Agent-Codex
bash install-macos.sh
```

Windows PowerShell에서는 다음을 실행합니다.

```powershell
git clone https://github.com/soonsoonLABS/sam-public.git
Set-Location sam-public\02-Code-Agent-Codex
PowerShell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

설치 프로그램은 키를 숨김 입력으로 받고 다음만 만듭니다.

```text
~/.sam/
  env                         # SAM_CODEX_API, macOS/Linux
  env.ps1                     # SAM_CODEX_API, Windows
  skills/sam/SKILL.md          # 공통 SAM 스킬 원본

~/.codex-sam/
  config.toml                 # V2 provider와 SAM MCP
  skills/sam/SKILL.md          # Codex가 읽는 복사본
```

키 파일은 사용자만 읽을 수 있게 저장됩니다. Git, 스크린샷, URL, 명령행 인수에
API 키를 넣지 마세요.

## 실행과 첫 확인

```bash
sam-codex
```

Codex 안에서 다음을 요청합니다.

```text
sam_account_usage를 사용해서 이번 달 SAM 사용량과 남은 SSAM을 짧게 보여줘.
```

`sam_account_usage`는 읽기 전용이며 SAM 사용량을 차감하지 않습니다. 모델에
보내는 요청은 일반 모델 토큰 사용량으로 기록됩니다.

## 모델 선택

Codex 안에서 `/model`을 입력해 모델을 바꿉니다.

| 모델 | 경로 | 권장 용도 |
| --- | --- | --- |
| `azure.gpt-5.6-sol` | Azure Foundry | 고난도 코딩·복잡한 에이전트 작업 |
| `azure.gpt-5.6-terra` | Azure Foundry | 기본 코딩·분석 |
| `azure.gpt-5.6-luna` | Azure Foundry | 가벼운 작업 |
| `azure.gpt-5.4` | Azure Foundry | 범용 작업 |
| `aws.gpt-5.6-sol` | AWS Bedrock Mantle | 고난도 코딩·복잡한 에이전트 작업 |
| `aws.gpt-5.6-terra` | AWS Bedrock Mantle | 기본 코딩·분석 |
| `aws.gpt-5.6-luna` | AWS Bedrock Mantle | 가벼운 작업 |
| `aws.gpt-5.5` / `aws.gpt-5.4` | AWS Bedrock Mantle | 범용 작업 |

기본값은 `azure.gpt-5.6-terra`입니다. 모델 목록이 갱신되지 않으면 Codex를
완전히 종료한 뒤 `sam-codex`로 새 세션을 시작하세요.

## 검색과 페이지 읽기

SAM MCP를 명시적으로 요청하면 도구 사용이 더 예측 가능합니다.

```text
SAM 웹 검색으로 최신 공식 문서를 찾아 핵심만 정리해줘.
```

```text
방금 찾은 공식 문서를 열고, tool calling 부분을 찾아 요약해줘.
```

| MCP 도구 | 역할 | SAM 사용량 |
| --- | --- | --- |
| `sam_web_search` | 웹 검색 | 검색 사용량으로 기록 |
| `sam_open_page` | 공개 페이지 열기 | 도구 자체는 검색 과금 없음 |
| `sam_find_in_page` | 열린 페이지에서 텍스트 찾기 | 도구 자체는 검색 과금 없음 |
| `sam_account_usage` | 월간 사용량·잔여 SSAM 조회 | 무료·읽기 전용 |

페이지 본문이 모델의 대화에 들어가면 일반 입력 토큰은 발생할 수 있습니다.

## 문제 해결

- `SAM_CODEX_API` 오류: 설치 프로그램을 다시 실행하거나 `~/.sam/env` 또는
  `~/.sam/env.ps1`이 있는지 확인합니다.
- 모델 접근 오류: API 키에 Code Agent 권한이 있는지 SAM 관리자에게 확인합니다.
- `sam-codex` 명령을 찾지 못함: macOS/Linux는 `~/.local/bin`을 PATH에 추가하고,
  Windows는 새 PowerShell 창을 엽니다.
- 일반 Codex로 돌아가기: `sam-codex` 대신 평소처럼 `codex`를 실행합니다.

더 자세한 오류 진단은 [문제 해결](docs/troubleshooting.md)을 참고하세요.

## 현재 범위

이 패키지는 Codex CLI를 지원합니다. 기존 Codex Desktop 앱의 provider를 직접
전환하는 기능은 계정·설정 충돌 위험 때문에 제공하지 않습니다.
