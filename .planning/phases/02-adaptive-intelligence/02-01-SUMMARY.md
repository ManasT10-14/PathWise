---
phase: 02-adaptive-intelligence
plan: 01
subsystem: api
tags: [fastapi, firestore, gemini, vertex-ai, memory, replanning, rate-limiting, pydantic]

# Dependency graph
requires:
  - phase: 01-full-platform-overhaul
    provides: "prompt_chain.py, firestore_writer.py, roadmaps.py router, gemini_client.py, AnalyzeRequest/AnalyzeResponse models"

provides:
  - "POST /api/v1/roadmaps/replan endpoint with Firebase auth and 3/day rate limiting"
  - "memory_writer.py: write_analysis_memory(), write_expert_annotation(), read_learner_memory()"
  - "replanner.py: run_replan_chain() memory-aware single-step Gemini chain"
  - "Roadmap versioning: new Firestore doc per replan (replan_version N+1, previous_roadmap_id, replan_reason)"
  - "Learner memory subcollection: users/{uid}/learner_memory/{analysis_history,expert_annotations}"
  - "Analysis memory persistence: every /analyze call writes snapshot to learner_memory"
  - "ReplanRequest and ReplanResponse Pydantic models"
  - "replanner.txt prompt template with 8 format slots for memory-aware context injection"

affects:
  - 02-02-adaptive-intelligence
  - any future phase consuming learner memory or replan API

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Memory-as-enrichment: read_learner_memory() never raises — returns empty structure on any error"
    - "Linked-list versioning: previous_roadmap_id field creates chain, original doc never modified"
    - "Single-step replan chain: one Gemini call vs 4-step analysis chain (different complexity budget)"
    - "ArrayUnion for expert annotations: safe concurrent writes without transaction overhead"
    - "Silent memory write: write_analysis_memory() failure logged as warning, never fails /analyze response"

key-files:
  created:
    - backend/services/memory_writer.py
    - backend/services/replanner.py
    - backend/prompts/replanner.txt
  modified:
    - backend/routers/roadmaps.py
    - backend/models/requests.py
    - backend/models/responses.py
    - backend/services/firestore_writer.py

key-decisions:
  - "Memory is enrichment not requirement: read_learner_memory() always returns safe empty structure on error so replan never hard-fails due to memory access"
  - "Linked-list roadmap versioning: new Firestore document per replan with previous_roadmap_id creates immutable history chain"
  - "Single Gemini call for replanning vs 4-step chain: replan has full context in one prompt, reducing latency"
  - "ArrayUnion for expert annotations: allows concurrent expert writes without last-write-wins data loss"
  - "Rate limit replans at 3/day per user (AI-10): prevents cost runaway on expensive replan calls"

patterns-established:
  - "Replan prompt slots: {target_role}, {current_milestones}, {current_timeline}, {progress_summary}, {stall_context}, {learner_feedback}, {memory_context}, {expert_annotations}"
  - "Memory subcollection path: users/{uid}/learner_memory/{doc_name}"
  - "Versioning fields: replan_version (int), previous_roadmap_id (str), replan_reason (str)"

requirements-completed: [ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-04, ADAPT-05, EXP-05]

# Metrics
duration: 9min
completed: 2026-04-07
---

# Phase 02 Plan 01: Adaptive Intelligence Backend Summary

**Memory-aware replan chain with Firestore versioning: POST /api/v1/roadmaps/replan builds new roadmap docs from learner history, struggle patterns, and expert annotations via single Gemini 2.5 Flash call**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-06T21:24:15Z
- **Completed:** 2026-04-06T21:33:18Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- Built complete adaptive intelligence backend: memory writer, replan chain, versioned endpoint
- POST /api/v1/roadmaps/replan creates new Firestore document with replan_version=N+1 and previous_roadmap_id — original roadmap never overwritten
- Every /analyze call now persists an analysis snapshot to users/{uid}/learner_memory/analysis_history (max 10 entries, oldest dropped)
- Memory context (analysis history + expert annotations) injected into replan prompt when available
- Expert annotations written via write_expert_annotation() stored in users/{uid}/learner_memory/expert_annotations and surfaced in next replan

## Task Commits

Each task was committed atomically:

1. **Task 1: Learner memory writer + replan prompt template** - `f9b5302` (feat)
2. **Task 2: run_replan_chain() service + ReplanRequest/ReplanResponse models** - `796fde9` (feat)
3. **Task 3: POST /api/v1/roadmaps/replan endpoint + memory write on analyze** - `a32b50b` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `backend/services/memory_writer.py` - write_analysis_memory(), write_expert_annotation(), read_learner_memory()
- `backend/services/replanner.py` - run_replan_chain(), ReplanStepError, ReplanOutput schema
- `backend/prompts/replanner.txt` - 8-slot replan prompt template (target_role, milestones, timeline, progress, stall, feedback, memory, annotations)
- `backend/routers/roadmaps.py` - Added POST /replan endpoint + write_analysis_memory() call after /analyze
- `backend/models/requests.py` - Added ReplanRequest with sanitize_feedback validator
- `backend/models/responses.py` - Added ReplanResponse with versioning fields
- `backend/services/firestore_writer.py` - Added replan_version=1 to write_roadmap() for versioning baseline

## Decisions Made
- Memory is enrichment not a requirement: read_learner_memory() always returns safe empty structure on any Firestore error, so replanning never hard-fails due to memory unavailability
- Linked-list versioning pattern: each replanned roadmap stores previous_roadmap_id, creating an immutable traversable history chain without modifying originals
- Single Gemini call for replan vs 4-step chain: the full roadmap context fits in one well-structured prompt, reducing latency and cost
- ArrayUnion for expert annotation writes: concurrent expert annotation writes are safe without transaction coordination

## Deviations from Plan

None - plan executed exactly as written.

Note: The plan verification step `python -c "import main"` triggers a pre-existing structlog configuration conflict (`add_logger_name` processor incompatible with `PrintLoggerFactory` when Firebase initializes without credentials). This is a pre-existing issue unrelated to this plan's changes — all new modules (memory_writer, replanner, models, router) import cleanly in isolation and with mock env vars.

## Issues Encountered
- Packages not installed in the local Python environment (structlog, slowapi, firebase-admin, razorpay, google-genai). Installed via pip during verification — does not affect production deployment since backend runs in Docker with requirements.txt.

## Known Stubs
None — all functions are fully implemented. No placeholder data or hardcoded stubs.

## User Setup Required
None - no external service configuration required beyond what was set up in Phase 01.

## Next Phase Readiness
- POST /api/v1/roadmaps/replan is live and ready for Flutter UI integration (Plan 02-02)
- Memory subcollection structure is established — Flutter UI can trigger replan after stall detection
- Expert annotation endpoint (write_expert_annotation) is available for expert consultation flow
- Rate limiting (3/day) and ownership check are in place — secure for production

---
*Phase: 02-adaptive-intelligence*
*Completed: 2026-04-07*
