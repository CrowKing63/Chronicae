# Chronicae for Windows 개발 가이드

## 프로젝트 구조

```
Chronicae/
├── Chronicae.sln                    # 솔루션 파일
├── Chronicae.Server.Windows/       # 서버 컴포넌트
│   ├── Program.cs                  # 서버 API 정의
│   ├── Chronicae.Server.Windows.csproj
│   ├── Data/                       # Entity Framework DbContext
│   ├── Models/                     # 데이터 모델
│   └── Services/                   # 서비스 클래스
├── Chronicae.Windows/              # 클라이언트 애플리케이션
│   ├── MauiProgram.cs              # .NET MAUI 초기화
│   ├── App.xaml/App.xaml.cs        # 앱 시작점
│   ├── AppShell.xaml/AppShell.xaml.cs # 네비게이션 쉘
│   ├── MainPage.xaml/MainPage.xaml.cs # 메인 화면
│   ├── SettingsPage.xaml/SettingsPage.xaml.cs # 설정 화면
│   ├── Services/                   # 클라이언트 서비스
│   ├── Models/                     # 공유 모델
│   └── Platforms/Windows/          # Windows 플랫폼 전용 코드
└── docs/                           # 문서
```

## 기술 스택

- **서버**: ASP.NET Core Web API, .NET 8, Entity Framework Core, SQLite
- **클라이언트**: .NET MAUI, C#
- **데이터베이스**: SQLite (파일 기반)
- **API 문서**: Swagger/OpenAPI
- **테스트**: xUnit

## 주요 기능

1. **프로젝트 관리**: 프로젝트 생성, 수정, 삭제
2. **노트 관리**: 노트 생성, 수정, 삭제, 버전 관리
3. **버전 추적**: 노트의 변경 이력을 저장하고 이전 버전으로 복원
4. **실시간 업데이트**: Server-Sent Events (SSE)를 통한 실시간 업데이트
5. **AI 통합**: AI 기반 쿼리 및 검색 기능
6. **설정 기능**: 서버 포트 설정, 외부 액세스 제어 등
7. **Windows 통합**: 시스템 트레이, 알림, 설정 화면 등

## 로컬에서 실행하기

### 전제 조건
- .NET 8 SDK
- Visual Studio 2022 또는 VS Code
- (선택) SQLite 도구

### 실행 방법

1. **서버 실행**:
```bash
cd Chronicae.Server.Windows
dotnet run
```

2. **클라이언트 실행**:
```bash
cd Chronicae.Windows
dotnet run
```

## API 엔드포인트

API 명세서는 `docs/api-spec.md` 파일을 참조하세요.

## 데이터 모델

### Project
- `Id`: 프로젝트 식별자 (GUID)
- `Name`: 프로젝트 이름
- `CreatedAt`: 생성 시간
- `UpdatedAt`: 수정 시간
- `NoteCount`: 노트 개수
- `VectorStatus`: 벡터 인덱싱 상태

### Note
- `Id`: 노트 식별자 (GUID)
- `ProjectId`: 소속 프로젝트 ID
- `Title`: 노트 제목
- `Tags`: 태그 배열
- `CreatedAt`: 생성 시간
- `UpdatedAt`: 수정 시간
- `Excerpt`: 노트 요약
- `Content`: 노트 본문
- `Version`: 버전 번호

### VersionSnapshot
- `Id`: 스냅샷 식별자 (GUID)
- `NoteId`: 관련 노트 ID
- `Content`: 스냅샷 시점의 노트 내용
- `CreatedAt`: 스냅샷 생성 시간
- `VersionNumber`: 버전 번호

## 테스트

### 단위 테스트 실행
```bash
dotnet test
```

### 테스트 커버리지
- `Chronicae.Server.Windows.Tests` 프로젝트에 API 로직에 대한 단위 테스트 포함
- 실제 데이터베이스 대신 In-Memory 데이터베이스 사용

## 설정

### Windows 클라이언트 설정
- 서버 포트: 기본값 5000, 설정 페이지에서 변경 가능
- 외부 액세스: 기본값 비활성화, 설정 페이지에서 활성화 가능

### 데이터 저장 위치
- SQLite 데이터베이스: 앱 데이터 디렉토리에 `chronicae.db` 파일로 저장

## 빌드 및 배포

### 빌드
```bash
dotnet build
```

### 출시 빌드
```bash
dotnet publish -c Release -r win-x64 --self-contained
```

## 확장 지침

1. **새 API 엔드포인트 추가**:
   - `Program.cs`에 새로운 엔드포인트 등록
   - 적절한 모델 클래스 생성
   - 인증/인가 필요 시 처리

2. **새 UI 페이지 추가**:
   - XAML로 페이지 정의
   - 코드 비하인드에서 로직 구현
   - `AppShell.xaml.cs`에서 라우트 등록

3. **서비스 확장**:
   - `Chronicae.Server.Windows/Services`에 서버 서비스 추가
   - `Chronicae.Windows/Services`에 클라이언트 서비스 추가
   - `MauiProgram.cs`에서 DI 컨테이너에 등록