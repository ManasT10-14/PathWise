---
phase: 01-full-platform-overhaul
plan: "01"
subsystem: backend
tags: [fastapi, vertex-ai, gemini, firebase, prompt-chain, auth, rate-limiting, docker]
dependency_graph:
  requires: []
  provides: [fastapi-backend, gemini-prompt-chain, firebase-auth-middleware, firestore-roadmap-writer]
  affects: [flutter-ai-roadmap-service, firestore-roadmaps-collection]
tech_stack:
  added:
    - FastAPI 0.135.3
    - Uvicorn 0.41.0
    - google-genai 1.70.0
    - firebase-admin 7.3.0
    - pydantic 2.12.5
    - pydantic-settings 2.13.1
    - structlog 25.5.0
    - slowapi 0.1.9
    - tenacity 9.1.2
    - httpx 0.28.1
    - razorpay 2.0.1
  patterns:
    - Vertex AI Gemini structured output via response_schema Pydantic models
    - 4-step sequential prompt chain with ChainStepError propagation
    - Dual-write Firestore pattern (legacy + enhanced fields)
    - Sync def services in threadpool (google-genai is sync, avoids event loop blocking)
    - Per-user rate limiting via authenticated UID (not IP)
key_files:
  created:
    - backend/main.py
    - backend/config.py
    - backend/dependencies.py
    - backend/routers/health.py
    - backend/routers/roadmaps.py
    - backend/services/gemini_client.py
    - backend/services/goal_analyzer.py
    - backend/services/skill_gap_analyzer.py
    - backend/services/roadmap_planner.py
    - backend/services/resource_curator.py
    - backend/services/prompt_chain.py
    - backend/services/firestore_writer.py
    - backend/models/ai_schemas.py
    - backend/models/requests.py
    - backend/models/responses.py
    - backend/prompts/goal_analyzer.txt
    - backend/prompts/skill_gap_analyzer.txt
    - backend/prompts/roadmap_planner.txt
    - backend/prompts/resource_curator.txt
    - backend/requirements.txt
    - backend/.env.example
    - backend/Dockerfile
    - backend/.dockerignore
    - backend/.gitignore
  modified: []
decisions:
  - Sync def (not async) for Gemini service functions because google-genai SDK is synchronous — FastAPI runs sync handlers in a threadpool, preventing event loop blocking
  - Dual-write Firestore pattern to ensure zero breaking changes to existing Flutter Roadmap.fromFirestore() while enabling richer data for new UI
  - ChainStepError wraps each chain step failure with step attribution for diagnosable 502 errors
  - Per-user rate limiting by Firebase UID (not IP) to prevent shared-NAT unfairness
  - tenacity retry with exponential backoff (3 attempts, 1-10s wait) on all Gemini calls
metrics:
  duration: "8 minutes"
  completed_date: "2026-04-07"
  tasks_completed: 6
  files_created: 24
---

# Phase 01 Plan 01: FastAPI Backend + Vertex AI Prompt Chain Summary

FastAPI backend with Gemini 2.5 Flash 4-step prompt chain (goal analyzer, skill gap analyzer, roadmap planner, resource curator), Firebase ID token auth middleware, per-user rate limiting, dual-field Firestore roadmap writer, and a multi-stage Docker build for Cloud Run deployment.

## What Was Built

### Backend Architecture

A production-ready FastAPI service in `backend/` that replaces the Flutter app's local keyword-matching `AiRoadmapService` stub with real semantic AI analysis.

**Entry point** (`backend/main.py`): Firebase Admin SDK initialization (supports both service account file and Application Default Credentials), structlog JSON configuration, CORS middleware, SlowAPI rate-limiting middleware, per-request UUID correlation ID injection, and router mounting at `/api/v1`.

**Configuration** (`backend/config.py`): `Settings(BaseSettings)` class loading all configuration from environment variables or `.env` file. Covers Vertex AI credentials, Firebase, Razorpay, CORS origins, rate limits, and log level.

**Auth middleware** (`backend/dependencies.py`): `get_current_user` async dependency using `HTTPBearer` that calls `firebase_admin.auth.verify_id_token()`. Returns decoded token dict or raises `HTTPException(401)` for invalid, expired, or missing tokens. `limiter` instance uses authenticated UID as rate limit key (falls back to IP for unauthenticated requests).

### Pydantic AI Schema Layer

`backend/models/ai_schemas.py` defines 8 Pydantic models that serve triple duty:
1. Gemini `response_schema` parameter — constrains model output to valid JSON structure
2. FastAPI response model — auto-generates OpenAPI docs
3. Chain step contract — typed data flowing between steps

Models: `GoalAnalysis`, `SkillGap`, `SkillGapAnalysis`, `Milestone`, `RoadmapPlan`, `Resource`, `CuratedResources`. Every field has a `Field(description=)` to guide Gemini's output.

Input validation (`backend/models/requests.py`): `AnalyzeRequest` with `model_validator(mode='before')` stripping control characters from `resume_text` and `career_goals` (SEC-03), `max_length=10000` on resume (SEC-04), `max_length=500` on career goals.

### Prompt Templates

4 `.txt` files in `backend/prompts/` using Python `.format()` placeholders:
- `goal_analyzer.txt`: Role inference, career direction, constraints, realistic timeframe, confidence scoring
- `skill_gap_analyzer.txt`: Ordered gap analysis with prerequisites and proficiency levels
- `roadmap_planner.txt`: Phased milestones with concrete tasks, hour estimates, revision checkpoints
- `resource_curator.txt`: Platform-anchored resource curation with type diversity rules and anti-hallucination constraints

### Vertex AI Chain Services

`backend/services/gemini_client.py`: Shared `genai.Client(vertexai=True)` singleton using the `google-genai` SDK (the modern replacement for the deprecated `google-cloud-aiplatform` generative AI modules).

4 service files (goal_analyzer, skill_gap_analyzer, roadmap_planner, resource_curator): Each uses synchronous `def` (not `async def`) because the google-genai SDK is synchronous — FastAPI runs sync handlers in a threadpool, preventing event loop blocking. All use:
- `response_mime_type: "application/json"` + `response_schema: <PydanticModel>` for structured output
- `model_validate_json(response.text)` for parsing
- `@retry(stop=stop_after_attempt(3), wait=wait_exponential(...))` from tenacity
- `structlog.get_logger()` with PII-safe logging (resume length not content, per SEC-04)

### Chain Orchestrator + Firestore Writer

`backend/services/prompt_chain.py`: `run_analysis_chain()` executes steps 1-4 sequentially, wrapping each in try/except with `ChainStepError(step, cause)` for diagnosable failures. Logs total chain elapsed time.

`backend/services/firestore_writer.py`: `write_roadmap()` implements the dual-write pattern:
- **Legacy fields**: `targetRole`, `milestones` (formatted strings), `resources` (URL list), `timeline` (string), `stageProgress` (dict with 0.0 values) — compatible with existing `Roadmap.fromFirestore()` in Flutter
- **Enhanced fields**: `goalAnalysis`, `skillGaps`, `roadmapPlan`, `curatedResources` (model dicts), `version: 2`, `generatedBy: "gemini-2.5-flash"` — for new UI code in Plan 01-02

### API Endpoint

`POST /api/v1/roadmaps/analyze` with:
- Firebase ID token auth (Depends(get_current_user))
- Per-user rate limiting (10/day via @limiter.limit)
- Full chain execution + Firestore write
- AnalyzeResponse with legacy-compatible + enhanced fields
- Error handling: ChainStepError→502, ValidationError→422, RateLimitExceeded→429, Exception→500

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 3363ec2 | FastAPI scaffold: main.py, config.py, dependencies.py, health router, Dockerfile |
| Task 2 | 5e35f22 | Pydantic AI schemas + request/response models |
| Task 3 | 5963313 | Prompt templates for all 4 chain steps |
| Task 4 | 8a7ceae | Vertex AI services: gemini_client + 4 chain step implementations |
| Task 5 | 4e44e9e | Prompt chain orchestrator + Firestore dual-write writer |
| Task 6 | 0a0ee3c | POST /api/v1/roadmaps/analyze endpoint |
| Fix   | 0e3d5f6 | Retry decorator formatting (grep-verifiability) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @retry decorator formatting for grep-verifiability**
- **Found during:** Final verification (after Task 4 commit)
- **Issue:** Plan acceptance criteria require `@retry(stop=stop_after_attempt(3)` to be grep-verifiable on a single line. The original code used multi-line decorator formatting.
- **Fix:** Consolidated all 4 `@retry(...)` decorators to single-line format. Behavior identical.
- **Files modified:** `backend/services/goal_analyzer.py`, `backend/services/skill_gap_analyzer.py`, `backend/services/roadmap_planner.py`, `backend/services/resource_curator.py`
- **Commit:** 0e3d5f6

**2. [Rule 2 - Missing Critical] roadmaps.py stub created in Task 1**
- **Found during:** Task 1
- **Issue:** `main.py` imports from `routers.roadmaps` which didn't exist yet (Task 6 creates the full implementation). Without a stub, module import would fail.
- **Fix:** Created a minimal stub in Task 1 that was replaced by the full implementation in Task 6.
- **Files modified:** `backend/routers/roadmaps.py`

**3. [Rule 2 - Enhancement] Defense-in-depth truncation in skill_gap_analyzer.py**
- **Found during:** Task 4
- **Issue:** Plan specifies truncating resume at 10K chars. The `AnalyzeRequest` model already validates this, but the service was called with already-validated data. Added `resume_text[:10000]` in the service as a defense-in-depth measure.
- **Fix:** Added explicit slice in `skill_gap_analyzer.py` with a comment explaining the defense-in-depth rationale.

## Known Stubs

None. All plan objectives are fully implemented. The `AnalyzeResponse.resources` field returns AI-curated URLs (not hardcoded), and the Firestore writer dual-writes real chain results.

## Self-Check: PASSED

All 22 key files found on disk. All 7 commits verified in git history.
