# Dart LSP MCP Server

Claude Code를 위한 Dart Language Server MCP 구현체입니다.

## 🚀 설치

### 원격 설치 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/coco-de/dart-lsp/main/install.sh | bash
```

자동으로 다음을 수행합니다:
- OS/아키텍처에 맞는 바이너리 다운로드
- `~/.local/bin/dart-lsp-mcp`에 설치
- Claude Code 설정에 MCP 서버 등록

**지원 플랫폼**:
| 플랫폼 | 아키텍처 | 상태 |
|--------|----------|------|
| macOS | arm64 (Apple Silicon) | ✅ |
| Linux | x64 | ✅ |
| macOS | x64 (Intel) | 🚧 (소스 빌드 필요) |
| Windows | x64 | 🚧 (소스 빌드 필요) |

### 설치 확인

```bash
# 바이너리 확인
~/.local/bin/dart-lsp-mcp --version

# MCP 도구 목록 확인
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | ~/.local/bin/dart-lsp-mcp
```

### 업데이트

설치 스크립트를 다시 실행하면 최신 버전으로 업데이트됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/coco-de/dart-lsp/main/install.sh | bash
```

### 소스에서 빌드

```bash
git clone https://github.com/coco-de/dart-lsp.git
cd dart-lsp
make install
```

**요구사항**: Dart SDK 3.10.3+

## 🎯 특징

- **실시간 에러 검출**: 코드 작성 중 즉시 문제 발견
- **스마트 자동완성**: 프레임워크별 맞춤 제안
- **문서 호버**: API 문서 즉시 확인
- **코드 포맷팅**: Dart 공식 스타일 자동 적용
- **프레임워크 지원**: Flutter, Serverpod, Jaspr, Riverpod

## 🛠️ MCP 도구

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

```
1. 프로젝트 열기
   → dart_add_workspace로 워크스페이스 등록

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
class HomePage extends StatelessComponent {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(classes: 'container', [
      // HTML 요소 자동완성
    ]);
  }
}
```

### Flutter + Riverpod
```dart
class MyWidget extends ConsumerWidget {
  // 'provider', 'futureprovider' 템플릿 제안
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    return Container();
  }
}
```

## 📁 프로젝트 구조

```
dart-lsp/
├── bin/
│   ├── mcp_server.dart      # MCP 서버 진입점
│   └── server.dart          # LSP 서버 (독립 실행용)
├── lib/src/
│   ├── analyzer_service.dart
│   ├── document_manager.dart
│   ├── completions/         # 자동완성
│   ├── diagnostics/         # 진단
│   ├── navigation/          # 코드 탐색
│   ├── formatting/          # 포맷팅
│   ├── serverpod/           # Serverpod 지원
│   ├── jaspr/               # Jaspr 지원
│   ├── flutter/             # Flutter 지원
│   └── dcm/                 # DCM 규칙
├── .github/workflows/
│   └── release.yml          # 자동 빌드/릴리스
├── install.sh               # 원격 설치 스크립트
├── build.sh                 # 로컬 빌드 스크립트
└── Makefile                 # 빌드 자동화
```

## 🐛 문제 해결

### MCP 서버가 응답하지 않음

```bash
# 바이너리 위치 확인
which dart-lsp-mcp

# 수동 테스트
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | ~/.local/bin/dart-lsp-mcp
```

### Claude Code 설정 확인

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "dart-lsp": {
      "command": "/Users/yourname/.local/bin/dart-lsp-mcp",
      "args": [],
      "env": {}
    }
  }
}
```

### 설정 변경 후 재시작

```bash
# Claude Code 재시작 필요
```

## 📄 라이선스

BSD-3-Clause

---

Made with ❤️ by [Cocode](https://github.com/coco-de)
