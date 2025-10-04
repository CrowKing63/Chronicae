# Web Note Editor Enhancement Plan
_Last updated: 2025-10-03_

## Scope
- 목표: 기존 경량 웹 편집기에 계획된 기능을 단계적으로 추가하여 문서화된 REST/SSE 사양과 비전 프로 SPA 로드맵을 충족한다.
- 우선순위: 인증 유지, 충돌 방지, 검색·태그 도구 고도화, 내보내기·AI 통합 순으로 진행한다.

## Milestone 분류
1. **Milestone A — API 파리티 확보 (주차 1)**
   - 서버 라우터와 데이터 스토어가 `docs/api-spec.md`에 정의된 노트/프로젝트 엔드포인트를 모두 지원하도록 확장.
   - 자동 저장 대비를 위해 버전 충돌 감지와 부분 업데이트 경로를 구현.
2. **Milestone B — 웹 편집 UX 향상 (주차 2)**
   - SPA에서 검색/필터/태그 추천을 고도화하고 자동 저장 루프를 도입.
   - Vision Pro 홈 추가를 위한 PWA 구조(manifest, 아이콘) 확립.
3. **Milestone C — 확장 기능 연결 (주차 3 이후)**
   - 내보내기/백업 흐름을 UI에 노출하고 AI/RAG 백엔드 준비.

## 작업 백로그
| 순번 | 카테고리 | 작업 | 세부 설명 | 선행 조건 | 상태 |
|---|---|---|---|---|---|
| A1 | Server/API | `GET /projects/{id}`, `PUT /projects/{id}`, `?includeStats` 구현 | `APIRouter.handleProjectsRequest`에 상세 조회/갱신을 추가하고 `ProjectResponsePayload` 확장 | Core Data 모델 검토 | 완료 |
| A2 | Server/API | 노트 목록 페이지네이션/검색 지원 | 쿼리 파라미터(`cursor`, `limit`, `search`) 파싱 후 `ServerDataStore.listNotes` 보강, 응답에 `nextCursor` 포함 | A1 | 완료 |
| A3 | Server/API | 충돌 감지 & 부분 업데이트 | `NoteUpdatePayload`에 `lastKnownVersion` 추가, `If-Match`/버전 비교 도입, `PATCH`에서 변경 필드만 반영 | A1 | 완료 |
| A4 | Server/API | 버전/내보내기/검색/AI 라우트 추가 | `docs/api-spec.md` 121-200 라우트를 `APIRouter` 및 `ServerDataStore`에 구현 | A1-A3 | 완료 |
| B1 | Web SPA | 자동 저장 루프 | `useEffect` 기반 디바운스 저장, 409 응답 시 병합 전략 정의 | A3 | 완료 |
| B2 | Web SPA | 고급 태그 추천 | 사용 빈도/최근 사용 메타를 저장하고 추천 알고리즘 구현 | B1 | 대기 |
| B3 | Web SPA | 검색·필터 UI 개선 | 서버 검색 API 연결, 필터 저장 UI 정비, 다중 조건 하이라이트 | A2, A4 | 대기 |
| B4 | Web SPA | Web App Manifest & 아이콘 | `vision-spa/public/manifest.webmanifest`, 아이콘 세트, `index.html` 링크 추가 | 없음 | 대기 |
| B5 | Web SPA | 프로젝트 전환 UI 검증 | 다중 프로젝트 셀렉터 UX, 통계 갱신, 이벤트 처리 QA | A1 | 완료 |
| C1 | Cross | 내보내기/백업 UI 통합 | SSE `note.export.queued`, `backup.completed`를 UI 배지/히스토리에 표시 | A4 | 대기 |
| C2 | Cross | RAG/AI 준비 | `ai-integration-roadmap` 단계 반영하여 API 및 UI 시나리오 설계 | A4 | 대기 |

### 2025-10-04 업데이트 메모
- 프로젝트 전환 시 `project.switched` SSE 이벤트를 발송하고 클라이언트에서 구독하도록 반영.
- 노트 버전 상세 조회(`GET /projects/{projectId}/notes/{noteId}/versions/{versionId}`)가 스냅샷+본문을 반환하도록 확장.
- 노트 삭제 시 `?purgeVersions=true`로 버전 일괄 삭제 옵션을 제공.
- Vision SPA 자동 저장 루프(1.5초 디바운스, 409 충돌 시 서버 버전 병합 및 토스트 알림) 적용.

### B2~B4 세부 일정 재조정
- **10월 07~09일 — B2 태그 추천**
  - B2-1: 태그 사용/최근 메타 저장을 위한 서버 이벤트 로깅 및 캐시 필드 추가 (`ServerDataStore` 메타 필드, API 응답 확장).
  - B2-2: Vision SPA에 태그 추천 패널 도입, 추천 API 연동, 키보드 네비게이션/선택 UX 설계.
  - B2-3: 추천 품질 QA(빈 프로젝트, 다국어 태그, 100+ 태그 케이스) 및 회귀 체크리스트 작성.
- **10월 10~14일 — B3 검색·필터 UI**
  - B3-1: `/api/search` 통합, 모드 전환(keyword/semantic) 토글 및 검색 로딩 상태 표시.
  - B3-2: 다중 조건 필터 칩, 저장 필터 편집/삭제 UI, 로컬 스토리지 스키마 마이그레이션.
  - B3-3: 본문·태그 하이라이트 구현과 가상 리스트 성능 검증(200+ 노트 기준).
- **10월 15~18일 — B4 PWA 준비**
  - B4-1: `manifest.webmanifest` 작성, 아이콘 세트(192/512/1024) 제작 및 참조 경로 정리.
  - B4-2: Service Worker 기본 캐시 전략 정리(정적 자산 precache, API bypass)와 Vision Pro 설치 플로우 점검.
  - B4-3: Lighthouse PWA 진단, 설치 가이드 문서화(`docs/vision-spa-pwa.md` 초안).

## Project Stats UI 가이드
- **지표 구성**: `versionCount`(프로젝트 내 전체 버전 스냅샷 수), `uniqueTagCount`(사용 중인 고유 태그 수), `averageNoteLength`(노트 평균 글자 수), `latestNoteUpdatedAt`(가장 최근 편집 시간)을 `ProjectSummary.Stats`에 포함한다.
- **백엔드 계산 규칙**: Core Data의 `CDNote` 컬렉션을 순회해 버전 수와 최신 수정 시각을 누적하고, 태그는 JSON 문자열을 복호화 후 `Set<String>`으로 집계한다. 평균 글자 수는 총 본문 길이를 노트 수로 나눠 산출한다.
- **웹 UI 배치**: 상단에 `project-bar` 컨테이너를 두고 프로젝트 이름, 새로고침/이름 변경 버튼을 배치하며, 우측에는 네 개의 `metric-card`를 그리드로 정렬한다. 각 카드에는 레이블(`metric-card__label`)과 값(`metric-card__value`)을 표시하고 값이 없을 경우 `—`를 출력한다.
- **상호작용**: “이름 변경”은 `PUT /api/projects/{id}?includeStats=true`를 호출하고, “새로고침”은 `GET /api/projects?includeStats=true`로 통계를 갱신한다. 각 요청이 완료되면 토스트로 결과를 알려준다.
- **형식**: 날짜 및 시간은 `toLocaleString()`을 사용해 현지화하고, 평균 글자 수는 반올림 후 `자` 단위를 붙인다.

## 단계별 진행 순서
1. **세션 1** — Milestone A의 A1-A3 구현.
   - `APIRouter`와 `ServerDataStore`에 필요한 분기와 모델을 추가.
   - Unit test 혹은 `xcodebuild test`로 기본 회귀 확인.
2. **세션 2** — Milestone A 마무리 및 Milestone B 착수.
   - A4 라우트 확장, `/events`에 새 이벤트 타입 전송 확인.
   - B1 자동 저장 도입 후 충돌 처리를 QA.
3. **세션 3** — Milestone B 완성.
   - B2, B3, B4를 순차적으로 적용하고 Vision Pro에서 PWA 등록 검증.
4. **세션 4 이후** — Milestone C 병행.
   - 내보내기/백업 UI( C1 )와 AI 파이프라인 설계(C2)를 진행.

## 테스트 & 검증 체크리스트
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" build`
- REST 새 엔드포인트 수동 검증: `curl` 스크립트로 CRUD, 검색, 내보내기 확인.
- Vision SPA: `npm run dev` → 브라우저 테스트, Service Worker/Manifest Lighthouse 검사.
- SSE 이벤트: 다중 디바이스 시나리오에서 `note.updated`, `note.export.queued` 수신 확인.

## 다음 세션 준비 사항
- Server/API 작업을 위한 Core Data 모델 (`CDProject`, `CDNote`, `CDNoteVersion`, `CDExportJob`) 구조 검토.
- API 스펙 변경 사항을 반영할 단위 테스트 케이스 초안 작성.
- 자동 저장 UX에 필요한 에디터 상태/디바운스 전략 리서치 (예: 1.5초 간 입력 없을 때 저장).
