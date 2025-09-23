# 벡터 DB 및 Apple FM API 통합 로드맵

## 목표
- 로컬 RAG 파이프라인 구축 (문서 임베딩, 검색, 재랭크).
- Apple Foundation Model API / Apple Intelligence 글쓰기 도구 연동.
- 클라우드 LLM 백업 경로 빌드.

## 단계별 로드맵

### Phase 1. 데이터 레이어 준비 (주차 1)
1. **스키마 정의**
   - SQLite `notes`, `chunks`, `embeddings`, `metadata` 테이블 설계.
   - 벡터 컬럼은 SQLite-VSS 사용, 대안으로 Chroma 임베디드 서버.
2. **인덱싱 파이프라인**
   - 노트 저장 → Markdown → 청크(512 tokens) 분할 → 임베딩 추출.
   - 임베딩 저장 + `chunks` 테이블과 연동.
   - 백그라운드 작업 큐 (`OperationQueue` or `AsyncStream`).
3. **버전 연동**
   - 최신 노트만 임베딩, 이전 버전은 Delta 보관.
   - 롤백 시 재인덱싱 트리거.

### Phase 2. 로컬 RAG 구현 (주차 2)
1. **임베딩 모델 선택**
   - Apple FM `Embedding` 엔드포인트 (macOS 15+ 지원) 우선.
   - 대안: `sentence-transformers/all-mpnet-base-v2` CoreML 변환.
2. **검색 API**
   - `GET /search?mode=semantic` → 벡터 유사도 쿼리.
   - 상위 k개 결과를 rerank (`cosine`, ML reranker).
3. **응답 생성**
   - Apple FM `Summarization/Answer` API 호출.
   - 컨텍스트 제한 4k 토큰, 필요 시 chunk trimming.
4. **평가 & 튜닝**
   - 사용자 피드백 로깅.
   - 히트율/응답 품질 메트릭 수집.

### Phase 3. Apple Intelligence / 글쓰기 도구 (주차 3)
1. **VisionOS 인증 플로우**
   - Vision Pro에서 `Sign in with Apple ID` 통한 Apple Intelligence 자격 획득.
   - 토큰을 iMac 서버로 안전 전송.
2. **글쓰기 도우미 연동**
   - Apple Intelligence Draft/Rewrite 엔드포인트 호출 래퍼.
   - 응답을 Markdown으로 조정, 에디터 삽입.
3. **프롬프트 템플릿 관리**
   - 서버 측 프롬프트 라이브러리 (요약, 번역, 톤 조정).
   - Vision Pro 클라이언트에서 프리셋 선택 UI 제공.

### Phase 4. 클라우드 컴퓨팅 백업 라인 (주차 4)
1. **추상화 레이어**
   - `AIClient` 프로토콜: `query(_:)`, `stream(_:)`, `metadata`.
   - 로컬 RAG, Apple Intelligence, 클라우드 LLM 구현체.
2. **클라우드 LLM 연결**
   - OpenAI/Gemini/Anthropic 중 선택, 키 관리.
   - Rate limit / 비용 모니터링.
3. **Failover 로직**
   - 로컬 RAG 실패 → Apple Intelligence → 클라우드 순으로 폴백.
   - SLA/Latency 기준 설정.
4. **감사 로그**
   - 모든 외부 API 호출 로그 → `logs/ai/<date>.jsonl`.

### Phase 5. 보안 및 개인정보 (주차 5)
1. **비식별화 단계**
   - 외부 전송 전에 민감 정보 마스킹.
2. **Keychain/보안 저장소**
   - API 키, 토큰을 macOS Keychain에 저장.
3. **감사 UI**
   - 서버 대시보드에서 호출 내역 확인 및 취소.

## 기술 의존성
- macOS 15 SDK, Xcode 16.
- Apple Foundation Model SDK (`AppleFoundationModel` 프레임워크).
- SQLite-VSS (`swift-sqlite` + `libsqlite3` 확장) 또는 Chroma HTTP 서버.
- Combine/Swift Concurrency 기반 백그라운드 작업 처리.

## 오픈 이슈
- Apple Intelligence VisionOS 토큰 공유 정책 확인 필요.
- 로컬 임베딩 모델 캐싱/업데이트 전략.
- 벡터 DB가 커질 때의 백업/복구 전략.
