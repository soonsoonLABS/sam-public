# 1. SAM 필수 스킬 문서

**언어:** 한국어 | [English](README.en.md)

이 폴더는 Codex, Kiro, Copilot, Claude Code 같은 AI 에이전트가 전역 설정에서
읽고 SAM API 사용법을 익히도록 만드는 공용 스킬 문서입니다.

## 파일

- [`sam-skills.md`](sam-skills.md): 한글 기본 스킬 문서
- [`sam-skills.en.md`](sam-skills.en.md): 영문 스킬 문서

## 사용 방식

사용자 환경의 에이전트 전용 설정 폴더에 이 폴더를 두고, 에이전트 지침에서
필요할 때 `sam-skills.md`를 읽게 하세요.

예시 지침:

```text
SAM API를 사용할 때는 sam-skills.md를 먼저 읽고, SAM_API_KEY 환경변수로
인증해서 요청하세요. 키를 출력하거나 파일에 저장하지 마세요.
```

## 전제

먼저 [`00-sam-setup/`](../00-sam-setup/)에서 `SAM_API_KEY`를 현재 터미널에
설정하고 `Hello SAM` 테스트가 성공해야 합니다.
