# SAM Codex 문제 해결

## `sam-codex: command not found`

macOS/Linux에서는 설치기가 안내한 대로 `~/.local/bin`을 PATH에 추가한 뒤 새
터미널을 여세요.

```bash
export PATH="$HOME/.local/bin:$PATH"
sam-codex
```

Windows에서는 설치 후 새 PowerShell 창을 엽니다.

## `SAM_CODEX_API`가 없다는 오류

키 파일 위치는 하나입니다.

```text
macOS/Linux: ~/.sam/env
Windows:     ~/.sam/env.ps1
```

키를 파일에 직접 붙여 넣지 말고 설치기를 다시 실행하세요. 키를 교체하면 이미
실행 중인 Codex 세션을 종료하고 다시 열어야 합니다.

## 모델 또는 MCP 도구가 보이지 않음

`sam-codex`로 완전히 새 Codex 세션을 엽니다. 일반 `codex`는 `~/.codex`의
기존 설정을 사용하므로 SAM 모델과 MCP를 보장하지 않습니다.

## 웹 검색을 요청했는데 Codex 검색이 꺼져 있다고 나옴

정상입니다. `web_search = "disabled"`는 Codex provider-hosted 검색을 끈
설정입니다. “SAM 웹 검색으로 … 찾아줘”라고 요청해 SAM MCP 도구를 사용하세요.

## 공개 페이지 열기가 실패함

SAM은 내부망·메타데이터 주소와 안전하지 않은 리디렉션을 열지 않습니다. 공개
HTTPS 페이지인지 확인하고, 검색 결과를 통해 다시 요청하세요.

## 사용량 차이가 걱정됨

`sam_account_usage`는 무료입니다. 반면 모델과의 대화, 검색 결과·페이지 본문이
대화에 포함되는 작업은 토큰 또는 검색 사용량을 만들 수 있습니다.
