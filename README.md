# Chronicae Windows

Chronicae는 개인 노트 관리를 위한 크로스 플랫폼 애플리케이션입니다. 이 저장소는 기존 macOS/Swift 버전을 .NET 8과 C#으로 포팅한 Windows 네이티브 버전을 포함합니다.

## 프로젝트 개요

Chronicae Windows는 다음과 같은 아키텍처로 구성됩니다:

- **Chronicae.Core**: 플랫폼 독립적 비즈니스 로직 및 도메인 모델
- **Chronicae.Data**: Entity Framework Core 기반 데이터 액세스 계층
- **Chronicae.Server**: ASP.NET Core HTTP 서버 및 REST API
- **Chronicae.Desktop**: WPF 기반 Windows 네이티브 데스크톱 애플리케이션
- **Chronicae.Tests**: 단위 테스트 및 통합 테스트

## 주요 기능

### 📝 노트 관리
- 마크다운 기반 노트 작성 및 편집
- 프로젝트별 노트 구조화
- 태그 기반 분류 시스템
- 자동 발췌문 생성

### 🔍 검색 및 탐색
- 전체 텍스트 검색 (제목, 내용, 태그)
- 커서 기반 페이지네이션
- 관련성 점수 기반 결과 정렬
- 검색 결과 스니펫 표시

### 📚 버전 관리
- 자동 버전 스냅샷 생성
- 버전 기록 조회 및 복원
- 버전 충돌 감지 및 해결
- 선택적 버전 삭제

### 🌐 웹 클라이언트 지원
- 내장 HTTP 서버
- REST API 엔드포인트
- SignalR 기반 실시간 동기화
- React 기반 웹 인터페이스

### 💾 백업 및 내보내기
- 자동 ZIP 백업 생성
- 다양한 형식 내보내기 (Markdown, PDF, TXT)
- 백업 기록 관리
- 프로젝트별 내보내기

### 🔐 보안 및 인증
- Bearer 토큰 기반 API 인증
- 보안 토큰 생성 및 관리
- 로컬/외부 접속 제어
- 요청 로깅 및 모니터링

### 🖥️ Windows 통합
- 시스템 트레이 지원
- 시작 프로그램 등록
- Windows 11 스타일 UI
- 백그라운드 서버 실행

## 설치 방법

### MSI 설치 관리자 (권장)

1. [Releases](https://github.com/your-repo/chronicae-windows/releases) 페이지에서 최신 `Chronicae-Setup.msi` 다운로드
2. MSI 파일을 실행하여 설치 마법사 따라하기
3. 설치 완료 후 시작 메뉴에서 "Chronicae" 실행

### 수동 설치

1. [Releases](https://github.com/your-repo/chronicae-windows/releases) 페이지에서 `Chronicae-Portable.zip` 다운로드
2. 원하는 폴더에 압축 해제
3. `Chronicae.Desktop.exe` 실행

### 시스템 요구사항

- **운영체제**: Windows 10 버전 1809 이상 또는 Windows 11
- **런타임**: .NET 8 Runtime (자체 포함 배포 시 불필요)
- **메모리**: 최소 512MB RAM
- **저장공간**: 최소 100MB 여유 공간
- **네트워크**: 웹 클라이언트 사용 시 로컬 네트워크 접근

## 빌드 방법 (개발자용)

### 필수 요구사항

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) 또는 [Visual Studio Code](https://code.visualstudio.com/)
- [Node.js 18+](https://nodejs.org/) (웹 클라이언트 빌드용)
- [WiX Toolset v4](https://wixtoolset.org/) (설치 관리자 빌드용, 선택사항)

### 소스 코드 복제

```bash
git clone https://github.com/your-repo/chronicae-windows.git
cd chronicae-windows
```

### 의존성 복원

```bash
# .NET 패키지 복원
dotnet restore

# 웹 클라이언트 의존성 설치
cd vision-spa
npm install
cd ..
```

### 개발 빌드

```bash
# 전체 솔루션 빌드
dotnet build

# 웹 클라이언트 빌드
cd vision-spa
npm run build
cd ..
```

### 테스트 실행

```bash
# 단위 테스트 실행
dotnet test

# 특정 테스트 프로젝트만 실행
dotnet test Chronicae.Tests
```

### 개발 서버 실행

```bash
# 데스크톱 앱 실행
dotnet run --project Chronicae.Desktop

# 또는 서버만 실행
dotnet run --project Chronicae.Server
```

### 배포 빌드

```bash
# 자체 포함 배포 (Windows x64)
dotnet publish Chronicae.Desktop -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# MSI 설치 관리자 빌드 (WiX 필요)
cd Chronicae.Installer
dotnet build -c Release
```

### 프로젝트 구조

```
Chronicae.Windows/
├── Chronicae.Core/              # 비즈니스 로직 및 도메인 모델
│   ├── Models/                  # 엔터티 및 DTO
│   ├── Services/                # 비즈니스 서비스
│   ├── Interfaces/              # 추상화 인터페이스
│   └── Utilities/               # 공통 유틸리티
├── Chronicae.Data/              # 데이터 액세스 계층
│   ├── Repositories/            # 리포지토리 구현
│   ├── Migrations/              # EF Core 마이그레이션
│   └── ChronicaeDbContext.cs    # 데이터베이스 컨텍스트
├── Chronicae.Server/            # HTTP 서버 및 API
│   ├── Controllers/             # REST API 컨트롤러
│   ├── Middleware/              # 인증, 로깅 미들웨어
│   ├── Hubs/                    # SignalR 허브
│   └── wwwroot/                 # 정적 웹 자산
├── Chronicae.Desktop/           # WPF 데스크톱 애플리케이션
│   ├── Views/                   # XAML 뷰
│   ├── ViewModels/              # MVVM 뷰모델
│   ├── Services/                # UI 서비스
│   └── Resources/               # 리소스 파일
├── Chronicae.Tests/             # 테스트 프로젝트
├── Chronicae.Installer/         # WiX 설치 관리자
├── vision-spa/                  # React 웹 클라이언트
└── docs/                        # 문서
```

## 사용법

### 기본 사용법

1. **서버 시작**: 데스크톱 앱 실행 시 자동으로 HTTP 서버가 시작됩니다
2. **프로젝트 생성**: "저장소 관리" 섹션에서 새 프로젝트를 생성합니다
3. **노트 작성**: 프로젝트를 선택하고 노트를 생성/편집합니다
4. **웹 접속**: 브라우저에서 `http://localhost:8843/web-app` 접속

### 고급 설정

- **포트 변경**: 설정 > 서버 포트에서 변경 가능
- **외부 접속**: 설정 > 외부 접속 허용 체크박스
- **인증 토큰**: 설정 > 액세스 토큰에서 생성/관리
- **시작 프로그램**: 설정 > 시작 프로그램 등록

자세한 사용법은 [사용자 가이드](docs/user-guide.md)를 참조하세요.

## API 문서

REST API 및 SignalR 이벤트에 대한 자세한 정보는 [API 참조 문서](docs/api-reference.md)를 확인하세요.

## 기여하기

1. 이 저장소를 포크합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/amazing-feature`)
3. 변경사항을 커밋합니다 (`git commit -m 'Add some amazing feature'`)
4. 브랜치에 푸시합니다 (`git push origin feature/amazing-feature`)
5. Pull Request를 생성합니다

### 개발 가이드라인

- 모든 새 기능에 대해 단위 테스트 작성
- 코드 스타일 가이드 준수 (EditorConfig 설정 참조)
- 커밋 메시지는 [Conventional Commits](https://www.conventionalcommits.org/) 형식 사용
- Pull Request 전에 `dotnet test` 실행하여 모든 테스트 통과 확인

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 지원 및 문의

- **이슈 리포트**: [GitHub Issues](https://github.com/your-repo/chronicae-windows/issues)
- **기능 요청**: [GitHub Discussions](https://github.com/your-repo/chronicae-windows/discussions)
- **보안 취약점**: security@yourcompany.com

## 변경 로그

주요 변경사항은 [CHANGELOG.md](CHANGELOG.md)에서 확인할 수 있습니다.

## 감사의 말

- [ModernWpf](https://github.com/Kinnara/ModernWpf) - Windows 11 스타일 WPF 컨트롤
- [CommunityToolkit.Mvvm](https://github.com/CommunityToolkit/dotnet) - MVVM 패턴 구현
- [Markdig](https://github.com/xoofx/markdig) - 마크다운 파싱 및 렌더링
- [Serilog](https://serilog.net/) - 구조화된 로깅
- [Entity Framework Core](https://docs.microsoft.com/en-us/ef/core/) - ORM 및 데이터베이스 액세스