# SAM 에이전트 전역 지시문

아래 블록을 Codex, Kiro, Copilot, Claude Code 등 각 에이전트가 읽는 전역
지시 파일에 붙여넣으세요. 예: `AGENTS.md`, `CLAUDE.md`, Copilot custom
instructions, Kiro steering 문서.

```text
## SAM API 사용 규칙

사용자가 "SAM으로", "샘으로", "SAM API로", "SAM Search로", "SAM 이미지로",
"SAM 모델로" 같은 요청을 하면 먼저 SAM 스킬 문서를 읽고 그 규칙을 따른다.

스킬 문서 우선순위:
1. 로컬에 있으면 ~/.sam/skills/sam-skills.md 를 읽는다.
2. 없으면 sam-public 저장소의 01-sam-skills/sam-skills.md 를 읽는다.

키 로드 규칙:
- macOS/Linux: SAM_API_KEY가 현재 프로세스에 없으면 ~/.sam/env 를 source 한다.
- Windows PowerShell: SAM_API_KEY가 현재 프로세스에 없으면 ~/.sam/env.ps1 을 dot-source 한다.
- ~/.config/sam/.env, 프로젝트 .env, 에이전트별 임의 키 파일을 새로 만들거나 우선하지 않는다.
- 현재 셸의 임시 SAM_API_KEY와 표준 키 파일 값이 다르면 표준 키 파일을 로드한 값을 기준으로 한다.
- 키를 출력하지 않는다. 확인이 필요하면 앞 12자리만 보여준다.
- 키 교체 후에는 실행 중인 CLI/에이전트 프로세스를 재시작해야 새 키를 읽는다고 안내한다.

호출 규칙:
- Base URL은 https://sam.soonsoon.ai 이다.
- 새 SAM 통합은 /v1/* 네이티브 API를 우선 사용한다.
- OpenAI 호환 클라이언트는 https://sam.soonsoon.ai/openai/v1 을 사용한다.
- /api/* legacy 경로는 새 작업에 사용하지 않는다.
- 비용이 발생할 수 있는 모델/이미지/검색 호출은 사용자의 의도 범위 안에서만 실행한다.
- 실패 시 HTTP 상태, 사용한 SAM 기능, 다음 조치를 간단히 보고한다.
```

## 설치 예시

macOS/Linux에서 스킬 문서를 로컬 표준 위치에 복사:

```bash
mkdir -p "$HOME/.sam/skills"
cp 01-sam-skills/sam-skills.md "$HOME/.sam/skills/sam-skills.md"
```

Windows PowerShell에서 스킬 문서를 로컬 표준 위치에 복사:

```powershell
$SkillHome = Join-Path $HOME ".sam\skills"
New-Item -ItemType Directory -Force -Path $SkillHome | Out-Null
Copy-Item "01-sam-skills\sam-skills.md" (Join-Path $SkillHome "sam-skills.md") -Force
```

## 에이전트별 적용 위치

- Codex: 전역 또는 프로젝트 `AGENTS.md`
- Claude Code: 전역 또는 프로젝트 `CLAUDE.md`
- GitHub Copilot: Copilot custom instructions 또는 저장소 지시 파일
- Kiro: Kiro가 읽는 steering 또는 rules 문서

각 에이전트의 정확한 전역 설정 경로는 버전과 설치 방식에 따라 다를 수
있습니다. 중요한 기준은 모든 에이전트가 `~/.sam/env`,
`~/.sam/env.ps1`, `~/.sam/skills/sam-skills.md`만 공통으로 참조하게 하는
것입니다.
