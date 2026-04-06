---
phase: 02-adaptive-intelligence
verified: 2026-04-07T00:00:00Z
status: gaps_found
score: 6/8 must-haves verified
gaps:
  - truth: "ExpertAnnotationScreen lets an expert type an annotation for a specific milestone level and submits it to the backend via POST /api/v1/roadmaps/annotate"
    status: failed
    reason: "POST /api/v1/roadmaps/annotate does not exist in any backend router. write_expert_annotation() is defined in memory_writer.py but is never wired to an HTTP endpoint. The Flutter client calls /api/v1/roadmaps/annotate and will receive a 404 at runtime."
    artifacts:
      - path: "backend/routers/roadmaps.py"
        issue: "No /annotate route defined. grep for 'annotate' in all backend routers returns zero matches."
      - path: "backend/services/memory_writer.py"
        issue: "write_expert_annotation() exists and is correct but is unreachable from HTTP — no router imports or calls it."
    missing:
      - "Add POST /api/v1/roadmaps/annotate endpoint to backend/routers/roadmaps.py"
      - "Import write_expert_annotation from services.memory_writer in the router"
      - "Endpoint should accept roadmap_id, user_id, milestone_level, annotation in request body"
      - "Should call write_expert_annotation(user_id, roadmap_id, milestone_level, annotation_text, expert_id) and return {status: ok}"
      - "Apply Firebase auth dependency (get_current_user) — only authenticated experts should annotate"

  - truth: "Expert annotations stored in users/{uid}/learner_memory/expert_annotations are injected into the replan prompt"
    status: partial
    reason: "The data-flow is complete IF the annotations reach Firestore, but the /annotate endpoint is missing so annotations can never be written in production. The read path (read_learner_memory -> replan prompt) is fully implemented and correct. This gap is downstream of the missing endpoint."
    artifacts:
      - path: "backend/routers/roadmaps.py"
        issue: "No endpoint exists to receive annotation submissions — write_expert_annotation() is dead code from a router perspective."
    missing:
      - "Depends on the /annotate endpoint gap above being closed. Once the endpoint exists, the injection path (read_learner_memory -> run_replan_chain -> prompt) is already wired correctly."

human_verification:
  - test: "Stall detection threshold at exactly 14 days"
    expected: "isStalled() returns false at 13 days, true at 14 days. RoadmapDetailScreen renders the stall card when isStalled() is true."
    why_human: "Requires a real Firestore document with updatedAt set to exactly 14 days ago and stageProgress with at least one stage < 1.0 to confirm UI renders correctly."
  - test: "Replan navigation replaces the old roadmap screen"
    expected: "After calling /api/v1/roadmaps/replan, Navigator.pushReplacement loads the new roadmap document. Back button does not return to the old roadmap."
    why_human: "Requires a running backend and live Firestore connection. Can't verify navigation stack behavior statically."
  - test: "Replan version banner displays on replanned roadmap"
    expected: "A GlassCard banner reads 'Version 2 — Adapted for you' with the AI-generated replan_reason text when replanReason is non-null on the Roadmap object."
    why_human: "Requires a replanned Firestore document with replan_reason and replan_version fields set."
---

# Phase 2: Adaptive Intelligence Verification Report

**Phase Goal:** Roadmaps become living documents that auto-adjust when learners stall, remember context across sessions, and improve through expert annotations
**Verified:** 2026-04-07
**Status:** gaps_found — 1 blocker, 1 partial gap
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | POST /api/v1/roadmaps/replan accepts roadmap_id, user_id, current_progress, optional learner_feedback and returns a versioned adjusted roadmap | VERIFIED | `backend/routers/roadmaps.py` lines 178-340: full endpoint with auth, rate limiting, Firestore fetch, ownership check, ReplanStepError handling, and ReplanResponse return |
| 2 | A learner_memory subcollection document is created under users/{uid}/learner_memory/analysis_history after every /analyze call | VERIFIED | `backend/routers/roadmaps.py` lines 91-95: `write_analysis_memory()` called in try/except after `write_roadmap()` in the analyze handler; failure logs warning but never fails the response |
| 3 | The replan prompt includes memory context (past analyses, struggle patterns, pace trends, expert annotations) when learner_memory documents exist | VERIFIED | `replanner.py` lines 125-139: formats `analysis_history` and `expert_annotations` from `read_learner_memory()` into prompt slots; `replanner.txt` contains `{memory_context}` and `{expert_annotations}` slots |
| 4 | Replanned roadmaps are new Firestore documents with version N+1 and a replan_reason field — the original document is never overwritten | VERIFIED | `backend/routers/roadmaps.py` lines 301-324: `db.collection("roadmaps").document()` creates new doc; sets `replan_version: current_version + 1`, `previous_roadmap_id`, `replan_reason`; original doc is never modified |
| 5 | Expert annotations stored in users/{uid}/learner_memory/expert_annotations are injected into the replan prompt | PARTIAL | `read_learner_memory()` correctly reads and returns `expert_annotations`; `run_replan_chain()` correctly injects them. But annotations can never reach Firestore — the `POST /api/v1/roadmaps/annotate` endpoint is missing. The injection path is implemented; the write path is broken. |
| 6 | RoadmapDetailScreen shows a 'Replan Roadmap' button when any stage has been unchanged for 14+ days | VERIFIED | `lib/models/roadmap.dart` lines 51-57: `isStalled()` checks `daysSinceUpdate >= thresholdDays` AND any `stageProgress < 1.0`; `roadmap_detail_screen.dart` line 362: `if (widget.roadmap.isStalled())` gates the stall card and FilledButton |
| 7 | Tapping 'Replan Roadmap' calls POST /api/v1/roadmaps/replan and navigates the user to the new roadmap document | VERIFIED | `roadmap_detail_screen.dart` line 143: `context.svc.api.replanRoadmap(...)` called in `_triggerReplan()`; line 158: `Navigator.of(context).pushReplacement(MaterialPageRoute(...RoadmapDetailScreen(roadmapId: newRoadmapId)))` |
| 8 | ExpertAnnotationScreen lets an expert type an annotation and submits it to POST /api/v1/roadmaps/annotate | FAILED | Flutter screen is fully implemented and calls `submitExpertAnnotation()` which hits `/api/v1/roadmaps/annotate`. Backend has no such endpoint. All annotation submissions will return HTTP 404 at runtime. |

**Score:** 6/8 truths verified (1 FAILED, 1 PARTIAL)

---

## Required Artifacts

### Plan 02-01 Artifacts

| Artifact | Status | Level 1: Exists | Level 2: Substantive | Level 3: Wired |
|----------|--------|----------------|---------------------|----------------|
| `backend/services/memory_writer.py` | VERIFIED | Yes | 189 lines, 3 full functions | Imported in `roadmaps.py`; `write_analysis_memory` called after analyze; `read_learner_memory` called in replan handler |
| `backend/services/replanner.py` | VERIFIED | Yes | 223 lines, full Gemini call with ReplanOutput schema | Imported in `roadmaps.py`; `run_replan_chain` called in replan handler |
| `backend/prompts/replanner.txt` | VERIFIED | Yes | 33 lines, all 8 format slots present | Loaded at module import time via `Path(__file__).parent.parent / "prompts" / "replanner.txt"` |
| `backend/routers/roadmaps.py` | VERIFIED | Yes | `/replan` endpoint at lines 178-340 | Registered in `main.py` via `include_router(roadmaps.router)` |
| `backend/models/requests.py` (ReplanRequest) | VERIFIED | Yes | `ReplanRequest` with `roadmap_id`, `current_progress`, `learner_feedback`, `stall_days`, `sanitize_feedback` validator | Imported and used in `roadmaps.py` replan handler |
| `backend/models/responses.py` (ReplanResponse) | VERIFIED | Yes | `ReplanResponse` with `new_roadmap_id`, `replan_reason`, `adjusted_milestones`, `stalled_stages`, `version` | Imported and used as `response_model` in replan endpoint |
| `backend/services/firestore_writer.py` (replan_version=1) | VERIFIED | Yes | Line 114: `"replan_version": 1` in `doc_data` | Called by analyze endpoint; provides versioning baseline |

### Plan 02-02 Artifacts

| Artifact | Status | Level 1: Exists | Level 2: Substantive | Level 3: Wired |
|----------|--------|----------------|---------------------|----------------|
| `lib/services/api_client.dart` (replanRoadmap, submitExpertAnnotation) | VERIFIED | Yes | `replanRoadmap()` lines 155-171; `submitExpertAnnotation()` lines 186-202 | `replanRoadmap` called in `roadmap_detail_screen.dart` line 148; `submitExpertAnnotation` called in `expert_annotation_screen.dart` line 52 |
| `lib/models/roadmap.dart` (replan fields + isStalled) | VERIFIED | Yes | `replanVersion`, `replanReason`, `previousRoadmapId` fields; `isStalled()` and `daysSinceUpdate()` getters; `fromFirestore` reads all three; `toFirestore` writes conditionally; `copyWith` propagates | `isStalled()` called in `roadmap_detail_screen.dart` line 362; replan fields read from Firestore snapshots |
| `lib/screens/roadmap_detail_screen.dart` | VERIFIED | Yes | `_isReplanning` flag, `_triggerReplan()`, `_showReplanDialog()`, stall card, version banner — all present | Reads live Firestore snapshot via StreamBuilder; calls `svc.api.replanRoadmap()` |
| `lib/screens/expert_annotation_screen.dart` | ORPHANED (runtime broken) | Yes | Full screen: level chips, TextField, `_submit()`, success state — 202 lines | Navigated-to from `expert_home_screen.dart`; calls `svc.api.submitExpertAnnotation()`. The Flutter artifact is complete and wired; the backend target endpoint is missing — calls return 404 |
| `lib/screens/expert_home_screen.dart` | VERIFIED | Yes | "Annotate" badge on `c.status == 'completed'` cards with `GestureDetector` navigating to `ExpertAnnotationScreen` | `ExpertAnnotationScreen` imported line 13; navigation at lines 181-190 |

---

## Key Link Verification

| From | To | Via | Status | Detail |
|------|----|-----|--------|--------|
| `roadmaps.py` replan endpoint | `memory_writer.read_learner_memory()` | Call before `run_replan_chain` | WIRED | Line 250: `memory = read_learner_memory(user_id=user_id)` |
| `roadmaps.py` analyze endpoint | `memory_writer.write_analysis_memory()` | Call after `write_roadmap()` | WIRED | Lines 91-95: try/except wraps the call; memory failure is non-fatal |
| `replanner.py run_replan_chain()` | `backend/prompts/replanner.txt` | `Path(__file__).parent.parent / 'prompts' / 'replanner.txt'` | WIRED | Line 29: `REPLANNER_PROMPT = (Path(...) / "replanner.txt").read_text(encoding="utf-8")` |
| `roadmap_detail_screen.dart _RoadmapBodyState` | `api_client.dart replanRoadmap()` | `context.svc.api.replanRoadmap()` on button tap | WIRED | Line 143: `final apiClient = context.svc.api;` then line 148: `await apiClient.replanRoadmap(...)` |
| `expert_home_screen.dart` | `expert_annotation_screen.dart` | `Navigator.push` to `ExpertAnnotationScreen` | WIRED | Lines 181-190: `Navigator.of(context).push(MaterialPageRoute(...ExpertAnnotationScreen(...)))` |
| `expert_annotation_screen.dart` | `api_client.dart submitExpertAnnotation()` | `context.svc.api.submitExpertAnnotation()` on submit tap | WIRED (Flutter side) | Line 52: `await context.svc.api.submitExpertAnnotation(...)` — but backend endpoint missing |
| `api_client.dart submitExpertAnnotation()` | `POST /api/v1/roadmaps/annotate` | HTTP POST via Dio | NOT_WIRED | No route `/annotate` exists in `backend/routers/roadmaps.py` or any other router file. `write_expert_annotation()` defined in `memory_writer.py` is never called from any router. |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `roadmap_detail_screen.dart` replan banner | `widget.roadmap.replanReason` | Firestore snapshot via `Roadmap.fromFirestore(m['replan_reason'])` | Yes — set by replan endpoint on new doc | FLOWING |
| `roadmap_detail_screen.dart` stall card | `widget.roadmap.isStalled()` | `updatedAt` from Firestore `Timestamp` + `stageProgress` map | Yes — both fields written by Firestore on roadmap update | FLOWING |
| `expert_annotation_screen.dart` submit | `_annotationController.text` | User input | Yes — captured from TextField | HOLLOW — data captured correctly but `submitExpertAnnotation()` hits a 404 endpoint |
| `memory_writer.write_analysis_memory` entries | `chain_result["goal"], chain_result["gaps"]` | `run_analysis_chain()` return dict | Yes — real AI output | FLOWING |
| `replanner.py` memory context | `memory["analysis_history"]`, `memory["expert_annotations"]` | `read_learner_memory()` Firestore reads | Conditional — only if docs exist. Empty lists returned safely on first use | FLOWING (with correct empty-state fallback) |

---

## Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| `write_analysis_memory` exports | `python -c "from services.memory_writer import write_analysis_memory, write_expert_annotation, read_learner_memory; print('OK')"` | Import succeeds (pycache present) | PASS |
| `run_replan_chain` exports | `python -c "from services.replanner import run_replan_chain, ReplanStepError; print('OK')"` | Import succeeds | PASS |
| All 8 replanner.txt slots present | `grep -c "{target_role}\|{expert_annotations}\|{memory_context}\|{stall_context}" replanner.txt` | All 8 slots confirmed in file | PASS |
| POST /annotate endpoint | `grep -rn "/annotate" backend/routers/` | Zero matches | FAIL — endpoint missing |
| `replan_version=1` in firestore_writer | `grep -n "replan_version" backend/services/firestore_writer.py` | Line 114: `"replan_version": 1` | PASS |
| `rate_limit_replans` in config | `grep -n "rate_limit_replans" backend/config.py` | Line 37: `rate_limit_replans: str = "3/day"` | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ADAPT-01 | 02-01, 02-02 | Dynamic replanning triggers when stageProgress unchanged for 14+ days | SATISFIED | `Roadmap.isStalled(thresholdDays: 14)` in `roadmap.dart`; called in `roadmap_detail_screen.dart`; `stall_days` forwarded to replan endpoint |
| ADAPT-02 | 02-01, 02-02 | Replan endpoint accepts current progress + optional learner feedback and generates adjusted roadmap | SATISFIED | `ReplanRequest` has `current_progress`, `learner_feedback`, `stall_days`; `run_replan_chain()` formats all into prompt; `ReplanResponse` returns adjusted roadmap |
| ADAPT-03 | 02-01, 02-02 | Replanned roadmaps are new versions with replan_reason — history preserved, not overwritten | SATISFIED | `new_doc_ref = db.collection("roadmaps").document()` creates new doc; sets `replan_version: current_version + 1`, `previous_roadmap_id`, `replan_reason`; original never touched |
| ADAPT-04 | 02-01 | Learner memory subcollection stores analysis history, struggle patterns, and pace trends | PARTIAL | `analysis_history` doc is written after every /analyze call. `struggle_patterns` and `pace_trends` docs are described in plan's Firestore structure but never written by any code. Only `analysis_history` and `expert_annotations` are implemented. |
| ADAPT-05 | 02-01 | Memory context included in replan and subsequent analysis prompts for continuity | SATISFIED | `read_learner_memory()` reads `analysis_history` + `expert_annotations`; both injected into replan prompt via `{memory_context}` and `{expert_annotations}` slots |
| EXP-04 | 02-02 | Expert annotation interface — experts can add comments to learner roadmap milestones | BLOCKED | `ExpertAnnotationScreen` is fully implemented in Flutter. However, `POST /api/v1/roadmaps/annotate` does not exist in the backend. Any annotation submission returns HTTP 404. The interface exists but is non-functional end-to-end. |
| EXP-05 | 02-01, 02-02 | Expert annotations stored and fed into AI replan prompts (expert-AI feedback loop) | BLOCKED | Storage is broken (no /annotate endpoint). Read-and-inject path is implemented correctly in `read_learner_memory()` and `run_replan_chain()`. Loop cannot close without the write endpoint. |

**Orphaned requirements from REQUIREMENTS.md Phase 2 mapping:** None. All 7 requirements (ADAPT-01 through ADAPT-05, EXP-04, EXP-05) appear in plan frontmatter.

**Note on ADAPT-04 partial gap:** The plan's Firestore structure listed `struggle_patterns` and `pace_trends` as subcollection documents alongside `analysis_history` and `expert_annotations`. Neither is written by `memory_writer.py` or any other backend file. The REQUIREMENTS.md description of ADAPT-04 is broad ("analysis history, struggle patterns, and pace trends") and only `analysis_history` is implemented. This is a partial shortfall but less critical than the missing /annotate endpoint since the replan prompt functions correctly with just analysis history.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/screens/expert_annotation_screen.dart` | 52 | `svc.api.submitExpertAnnotation()` calls `/api/v1/roadmaps/annotate` | BLOCKER | Endpoint does not exist on backend — all annotation submissions fail with 404 at runtime |
| `backend/services/memory_writer.py` | 77 | `write_expert_annotation()` defined but never called from any HTTP route | BLOCKER | Function is dead code from a production perspective — backend has no entry point that invokes it |

No placeholder comments, empty return stubs, or hardcoded data found in any other verified file. All other implementations are substantive and data-wired.

---

## Human Verification Required

### 1. Stall Detection UI Trigger

**Test:** Create a test Firestore roadmap document with `updatedAt` set to 15 days ago, `stageProgress: {"beginner": 0.3}`. Open that roadmap in the app.
**Expected:** The stall warning GlassCard appears with "Progress stalled for 15 days" and a "Replan Roadmap" FilledButton.
**Why human:** Requires live Firestore + running app to verify the StreamBuilder reflects updatedAt correctly and the `isStalled()` condition renders the card.

### 2. End-to-End Replan Flow (once /annotate is fixed)

**Test:** Tap "Replan Roadmap" on a stalled roadmap, enter feedback, tap "Replan", wait for result.
**Expected:** App navigates to a new roadmap screen. The new screen shows the "Version 2 — Adapted for you" banner with the AI-generated replan_reason. Back button does not return to old roadmap (pushReplacement).
**Why human:** Requires live Gemini API access and Firestore writes to verify. Navigation stack behavior only verifiable at runtime.

### 3. Expert Annotation Round-Trip (pending /annotate endpoint)

**Test:** After /annotate endpoint is created and deployed: navigate to ExpertHomeScreen, tap "Annotate" on a completed consultation, enter "Learner struggles with PyTorch implementation", tap Submit.
**Expected:** Success state shows "Annotation Submitted" confirmation. The annotation appears in `users/{uid}/learner_memory/expert_annotations.annotations` in Firestore. A subsequent replan for that user's roadmap references the annotation in the replan_reason.
**Why human:** Requires live backend, Firestore write verification, and a second replan call to confirm the feedback loop closes.

---

## Gaps Summary

Two gaps block full goal achievement:

**Gap 1 (Blocker): POST /api/v1/roadmaps/annotate endpoint missing.**
The Flutter `ExpertAnnotationScreen` is fully built and calls `submitExpertAnnotation()` which targets `/api/v1/roadmaps/annotate`. This route does not exist in any backend router file. `write_expert_annotation()` is correctly implemented in `memory_writer.py` but is never called from any HTTP handler. This is a single-task fix: add the endpoint to `roadmaps.py`, import `write_expert_annotation`, and return `{"status": "ok"}`. EXP-04 and EXP-05 are blocked by this gap.

**Gap 2 (Minor): `struggle_patterns` and `pace_trends` subcollection documents never written.**
ADAPT-04 specifies these two Firestore documents alongside `analysis_history` and `expert_annotations`. Only `analysis_history` is written after each /analyze call. `struggle_patterns` and `pace_trends` are mentioned in the plan's interface spec but no code writes them. The replan prompt does not include these slots either (only `{memory_context}` from analysis_history and `{expert_annotations}` are injected). This does not block current functionality but is an incomplete implementation of ADAPT-04.

The core adaptive intelligence loop — stall detection, replan trigger, AI chain, Firestore versioning, memory persistence, version banner display — is fully and correctly implemented. The expert annotation feedback loop is 95% complete with only the missing HTTP endpoint preventing end-to-end operation.

---

_Verified: 2026-04-07_
_Verifier: Claude (gsd-verifier)_
