# Dart LSP Integration for Claude Code

이 프로젝트는 **dart-lsp MCP 서버**를 통해 Claude Code와 완전 통합됩니다.

## 🛠️ 사용 가능한 MCP 도구

### dart_analyze
Dart 코드를 분석하고 에러/경고/힌트를 반환합니다.
```
코드를 작성하거나 수정한 후 항상 이 도구를 사용하여 문제가 없는지 확인하세요.
```

### dart_complete
특정 위치에서 코드 자동완성 제안을 가져옵니다.
```
클래스, 메서드, 변수 등의 정확한 이름을 모를 때 사용하세요.
Serverpod, Jaspr, Flutter 전용 스니펫도 제공됩니다.
```

### dart_hover
심볼의 문서와 타입 정보를 가져옵니다.
```
메서드의 파라미터나 반환 타입을 확인할 때 사용하세요.
```

### dart_definition
심볼의 정의 위치를 찾습니다.
```
코드의 원본 구현을 확인할 때 사용하세요.
```

### dart_format
Dart 공식 스타일 가이드에 따라 코드를 포맷합니다.
```
코드 작성 완료 후 항상 포맷팅을 실행하세요.
```

### dart_symbols
문서의 심볼 구조(아웃라인)를 가져옵니다.
```
파일의 클래스, 메서드, 변수 목록을 파악할 때 사용하세요.
```

### dart_code_actions
사용 가능한 빠른 수정 및 리팩토링 액션을 가져옵니다.
```
에러를 수정하거나 코드를 개선할 때 사용하세요.
```

### dart_add_workspace
분석할 워크스페이스 폴더를 추가합니다.
```
새 프로젝트를 열 때 먼저 워크스페이스를 추가하세요.
```

### dart_pub
Dart/Flutter 패키지 관리 명령을 실행합니다.
```
의존성 추가, 업데이트, 제거 등 패키지 관리를 직접 처리할 때 사용하세요.
```

**파라미터**:
| 이름 | 타입 | 설명 | 기본값 |
|------|------|------|--------|
| path | string | 프로젝트 디렉토리 경로 (필수) | - |
| command | string | pub 명령 (get/upgrade/outdated/add/remove) (필수) | - |
| package | string | 패키지 이름 (add/remove 시 필수) | - |
| dev | boolean | dev 의존성으로 추가 (add 시) | false |

### dart_test
Dart/Flutter 테스트를 실행합니다.
```
코드 작성 후 테스트를 돌려 정상 동작을 검증할 때 사용하세요.
```

**파라미터**:
| 이름 | 타입 | 설명 | 기본값 |
|------|------|------|--------|
| path | string | 프로젝트 디렉토리 또는 테스트 파일 경로 (필수) | - |
| name | string | 테스트 이름 필터 (정규식) | - |
| reporter | string | 출력 형식 (json/compact/expanded) | json |
| coverage | boolean | 코드 커버리지 수집 | false |

### dart_flutter_outline
Flutter 위젯 트리 아웃라인을 가져옵니다.
```
복잡한 위젯 트리 구조를 이해하거나 리팩토링할 때 사용하세요.
```

**파라미터**:
| 이름 | 타입 | 설명 | 기본값 |
|------|------|------|--------|
| uri | string | 파일 URI (file:///path/to/file.dart) (필수) | - |
| content | string | 파일 내용 (필수) | - |

### dart_logs
서버 실행 중 발생한 로그를 조회합니다.
```
디버깅이나 문제 해결 시 서버 내부 동작을 확인할 때 사용하세요.
```

**파라미터**:
| 이름 | 타입 | 설명 | 기본값 |
|------|------|------|--------|
| level | string | 최소 로그 레벨 (debug/info/warning/error) | info |
| source | string | 소스 필터 (MCP, LSP, DCM 등) | - |
| limit | int | 반환할 최대 로그 수 | 50 |
| since_minutes | int | 최근 N분 이내 로그만 | - |
| search | string | 메시지 검색어 | - |

## 📋 권장 워크플로우

### 코드 작성 시
1. **먼저 워크스페이스 추가**: `dart_add_workspace`로 프로젝트 경로 등록
2. **의존성 관리**: `dart_pub`로 필요한 패키지 추가/업데이트
3. **코드 작성 중**: `dart_complete`로 정확한 API 확인
4. **작성 후**: `dart_analyze`로 에러 체크
5. **테스트**: `dart_test`로 테스트 실행 및 결과 확인
6. **완료 시**: `dart_format`으로 포맷팅

### 기존 코드 수정 시
1. `dart_symbols`로 파일 구조 파악
2. `dart_hover`로 기존 코드 이해
3. 수정 후 `dart_analyze`로 검증
4. `dart_test`로 관련 테스트 실행
5. `dart_code_actions`로 추가 개선 확인

### Flutter 위젯 리팩토링 시
1. `dart_flutter_outline`로 위젯 트리 구조 파악
2. `dart_symbols`로 전체 파일 구조 확인
3. 리팩토링 후 `dart_analyze`로 검증
4. `dart_test`로 위젯 테스트 실행

## 🎯 프레임워크별 지원

### Serverpod
- Endpoint 메서드 자동완성
- Session 파라미터 검증
- DB 쿼리 스니펫 (find, insert, transaction)
- Protocol 클래스 인식

### Jaspr
- StatelessComponent / StatefulComponent 템플릿
- HTML 요소 자동완성
- @css 스타일링 스니펫
- Route 페이지 템플릿

### Flutter
- Widget 템플릿 (StatelessWidget, StatefulWidget)
- Riverpod 패턴 (ConsumerWidget, Provider)
- 라이프사이클 메서드 (initState, dispose)
- 일반적인 문제 감지 (missing dispose, stored BuildContext)

## ⚠️ 중요 규칙

1. **Dart 코드 작성 전** 항상 `dart_add_workspace`로 프로젝트 등록
2. **코드 수정 후** 반드시 `dart_analyze` 실행하여 에러 확인
3. **API 불확실 시** `dart_complete`나 `dart_hover`로 확인
4. **테스트 가능 시** `dart_test`로 테스트 실행하여 검증
5. **최종 저장 전** `dart_format`으로 코드 정리
