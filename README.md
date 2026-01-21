# Dart LSP for Claude Code

Claude Code와 완전 통합되는 Dart Language Server Protocol 구현체입니다.

## 🚀 빠른 시작

```bash
# 전체 설치 (빌드 + 플러그인 + MCP + 마켓플레이스)
make install

# PATH 설정 (처음 한 번만)
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.zshrc && source ~/.zshrc

# Claude Code 재시작
```

### Makefile 타겟

| 타겟 | 설명 |
|------|------|
| `make install` | 전체 설치 (권장) |
| `make build` | 바이너리만 빌드 |
| `make install-zed` | Zed 에디터용 설치 |
| `make clean` | 빌드 파일 정리 |
| `make uninstall` | 전체 제거 |
| `make info` | 설치 상태 확인 |

## 🎯 특징

- **실시간 에러 검출**: 코드 작성 중 즉시 문제 발견
- **스마트 자동완성**: 프레임워크별 맞춤 제안
- **문서 호버**: API 문서 즉시 확인
- **코드 포맷팅**: Dart 공식 스타일 자동 적용
- **프레임워크 지원**: Serverpod, Jaspr, Flutter, BloC

## 📦 설치 옵션

### Option A: Claude Code (권장) 🎯

```bash
make install
```

**Plugin 기능:**
- ✅ 실시간 진단 (lint 에러/경고 자동 표시)
- ✅ 코드 탐색 (go to definition, find references)
- ✅ 자동완성 (`.` 입력 시 자동 제안)
- ✅ Hover 문서 (심볼 위에서 정보 표시)
- ✅ Quick Fix (자동 수정 제안)

**MCP 기능:**
- `dart_analyze` - 코드 분석 명령
- `dart_complete` - 자동완성 제안
- `dart_hover` - 문서/타입 정보
- `dart_definition` - 정의 위치 찾기
- `dart_format` - 코드 포맷팅

### Option B: Zed 에디터

```bash
make install-zed
```

또는 수동 설정:

**~/.config/zed/settings.json**
```json
{
  "lsp": {
    "dart-lsp": {
      "binary": {
        "path": "~/bin/dart-lsp"
      }
    }
  },
  "languages": {
    "Dart": {
      "language_servers": ["dart-lsp"]
    }
  }
}
```

**Zed 기능:**
- ✅ 실시간 진단 (에러/경고 표시)
- ✅ 자동완성 (IntelliSense)
- ✅ Go to Definition
- ✅ Hover 문서
- ✅ 코드 포맷팅

### Option C: 기타 LSP 클라이언트

LSP 프로토콜을 지원하는 에디터에서 사용 가능합니다:

```bash
# 빌드 및 바이너리 설치
make build install-binary

# LSP 서버 경로
~/bin/dart-lsp
```

**지원 에디터:**
- VS Code (with generic LSP extension)
- Neovim (with nvim-lspconfig)
- Emacs (with lsp-mode)
- Sublime Text (with LSP package)

## 🛠️ 사용 가능한 도구 (MCP)

| 도구 | 설명 |
|------|------|
| `dart_analyze` | 코드 분석 및 에러/경고 반환 |
| `dart_complete` | 자동완성 제안 |
| `dart_hover` | 심볼 문서/타입 정보 |
| `dart_definition` | 정의로 이동 |
| `dart_format` | 코드 포맷팅 |
| `dart_symbols` | 문서 구조(아웃라인) |
| `dart_code_actions` | 빠른 수정/리팩토링 |
| `dart_add_workspace` | 워크스페이스 추가 |

## 📋 워크플로우

### Claude Code에서 Dart 코드 작성 시

```
1. 프로젝트 열기
   → Claude가 자동으로 dart_add_workspace 실행

2. 코드 작성 중
   → dart_complete로 정확한 API 확인
   → dart_hover로 문서 확인

3. 작성 완료
   → dart_analyze로 에러 검증
   → dart_format으로 포맷팅

4. 문제 발견 시
   → dart_code_actions로 빠른 수정
```

## 🎨 프레임워크별 지원

### Serverpod
```dart
// 자동완성 예시
class BookEndpoint extends Endpoint {
  // 'endpoint-method' 입력 시 템플릿 제안
  Future<Book> getBook(Session session, int id) async {
    // 'db-find' 입력 시 쿼리 템플릿 제안
    return await Book.db.findById(session, id);
  }
}
```

### Jaspr
```dart
// 자동완성 예시
class HomePage extends StatelessComponent {
  // HTML 요소 자동완성
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(classes: 'container', [
      // 'text', 'span', 'button' 등 제안
    ]);
  }
}
```

### Flutter
```dart
// 자동완성 예시
class MyWidget extends ConsumerWidget {
  // 'provider', 'futureprovider' 템플릿 제안
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    // ...
  }
}
```

## 📁 프로젝트 구조

```
dart-lsp/
├── .claude-plugin/
│   └── plugin.json          # Claude Code 플러그인 매니페스트
├── bin/
│   ├── mcp_server.dart      # MCP 서버 소스
│   ├── server.dart          # LSP 서버 소스
│   ├── dart-lsp-mcp         # 컴파일된 MCP 바이너리
│   └── dart-lsp             # 컴파일된 LSP 바이너리
├── lib/
│   └── src/
│       ├── analyzer_service.dart    # 분석 서비스
│       ├── document_manager.dart    # 문서 관리
│       ├── completions/             # 자동완성
│       ├── diagnostics/             # 진단
│       ├── navigation/              # 코드 탐색
│       ├── formatting/              # 포맷팅
│       ├── serverpod/               # Serverpod 지원
│       ├── jaspr/                   # Jaspr 지원
│       ├── flutter/                 # Flutter 지원
│       └── dcm/                     # DCM 규칙
├── Makefile                 # 설치 자동화
├── build.sh                 # 빌드 스크립트
├── install-plugin.sh        # Plugin 설치 스크립트
├── install-mcp.sh           # MCP 서버 설치 스크립트
└── CLAUDE.md                # Claude Code 지침
```

## 🐛 문제 해결

### "dart-lsp not found" / PATH 문제

```bash
# PATH 확인
echo $PATH | tr ':' '\n' | grep -E "(bin|local)"

# 바이너리 위치 확인
which dart-lsp

# PATH에 추가 (zsh)
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Claude Code: 플러그인이 작동하지 않음

```bash
# 설치 상태 확인
make info

# 플러그인 목록 확인
claude plugin list

# 재설치
make uninstall
make install
```

### Claude Code: MCP 서버가 응답하지 않음

```bash
# 로그 확인
tail -f ~/Library/Logs/Claude/mcp-dart-lsp.log

# 수동 테스트
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | ./bin/dart-lsp-mcp
```

### Zed: LSP가 시작되지 않음

```bash
# 바이너리 직접 테스트
~/bin/dart-lsp
# "[Dart LSP] Starting server..." 메시지가 표시되어야 함

# Zed 로그 확인 (macOS)
tail -f ~/Library/Logs/Zed/Zed.log

# settings.json 확인
cat ~/.config/zed/settings.json | jq '.lsp'
```

### 공통: 워크스페이스 분석 안됨

```bash
# dart_add_workspace를 먼저 실행했는지 확인
# 또는 프로젝트 루트에 pubspec.yaml이 있는지 확인
```

### 공통: 재시작

설정 변경 후 항상 에디터를 재시작하세요:

```bash
# Claude Code (macOS)
killall "Claude Code" 2>/dev/null; open -a "Claude Code"

# Zed (macOS)
killall "Zed" 2>/dev/null; open -a "Zed"
```

## 🔧 수동 설정

### Claude Code MCP 설정

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "dart-lsp": {
      "command": "/Users/dongwoo/bin/dart-lsp-mcp",
      "args": [],
      "env": {}
    }
  }
}
```

### Zed LSP 설정

**~/.config/zed/settings.json**

```json
{
  "lsp": {
    "dart-lsp": {
      "binary": {
        "path": "/Users/dongwoo/bin/dart-lsp"
      },
      "initialization_options": {}
    }
  },
  "languages": {
    "Dart": {
      "language_servers": ["dart-lsp"],
      "format_on_save": "on",
      "tab_size": 2
    }
  }
}
```

## 📝 다른 프로젝트에서 사용

다른 Dart 프로젝트에서 이 LSP를 활용하려면, 프로젝트 루트에 `CLAUDE.md` 파일을 생성하세요:

```markdown
# My Dart Project

이 프로젝트는 dart-lsp MCP를 통해 Dart 분석을 지원합니다.

## 권장 워크플로우
1. 코드 작성 전: dart_add_workspace로 프로젝트 등록
2. 코드 작성 후: dart_analyze로 검증
3. 완료 시: dart_format으로 포맷팅
```

## 📄 라이선스

BSD-3-Clause

---

Made with ❤️ by 코코드
