# 1. SAM 필수 스킬 문서

**언어:** 한국어 | [English](README.en.md)

이 폴더는 Codex, Kiro, Copilot, Claude Code 같은 AI 에이전트가 전역 설정에서
읽고 SAM API 사용법을 익히도록 만드는 공용 스킬 문서입니다.

## 파일

- [`sam-skills.md`](sam-skills.md): 한글 기본 스킬 문서
- [`sam-skills.en.md`](sam-skills.en.md): 영문 스킬 문서
- [`AGENT_INSTRUCTIONS.md`](AGENT_INSTRUCTIONS.md): 다른 에이전트의 전역
  지시문에 붙여넣을 한글 부트스트랩 문구
- [`AGENT_INSTRUCTIONS.en.md`](AGENT_INSTRUCTIONS.en.md): 영문 부트스트랩 문구

## 사용 방식

사용자 환경의 에이전트 전용 설정 폴더에 이 폴더를 두고, 에이전트 지침에서
필요할 때 `sam-skills.md`를 읽게 하세요.

권장 로컬 복사 위치:

```bash
mkdir -p "$HOME/.sam/skills"
cp sam-skills.md "$HOME/.sam/skills/sam-skills.md"
```

예시 지침:

```text
SAM API를 사용할 때는 sam-skills.md를 먼저 읽고, SAM_API_KEY 환경변수로
인증해서 요청하세요. 키를 출력하거나 임의 파일에 저장하지 마세요.
SAM 키는 ~/.sam/env 또는 ~/.sam/env.ps1만 로드하세요.
```

에이전트별 전역 지시 파일에는 [`AGENT_INSTRUCTIONS.md`](AGENT_INSTRUCTIONS.md)의
공통 부트스트랩 문구를 붙여넣으세요.

## 전제

먼저 [`00-sam-setup/`](../00-sam-setup/)에서 `SAM_API_KEY`를 `~/.sam/` 표준
폴더에 저장하고 `Hello SAM` 테스트가 성공해야 합니다.
