---
phase: 02-adaptive-intelligence
plan: 02
subsystem: flutter-ui
tags: [adaptive-intelligence, replan, expert-annotation, ui, flutter]
dependency_graph:
  requires: [02-01]
  provides: [replan-ui, expert-annotation-ui]
  affects: [lib/screens/roadmap_detail_screen.dart, lib/screens/expert_home_screen.dart, lib/screens/expert_annotation_screen.dart, lib/models/roadmap.dart, lib/services/api_client.dart]
tech_stack:
  added: []
  patterns: [glassmorphism-glasscard, flutter_animate, service-locator-svc-api]
key_files:
  created:
    - lib/screens/expert_annotation_screen.dart
  modified:
    - lib/services/api_client.dart
    - lib/models/roadmap.dart
    - lib/screens/roadmap_detail_screen.dart
    - lib/screens/expert_home_screen.dart
decisions:
  - "Use svc.api (not svc.apiClient) — AppServices.api is the actual field name in the service locator"
  - "Replan banner placed above skill gaps for visual hierarchy — version context before gap details"
  - "Stall card uses warm amber (Colors.orange.shade700) per quality directive — helpful not alarming"
  - "flutter_animate fadeIn+slideY on new cards for polished entrance animations"
metrics:
  duration: 6m
  completed_date: 2026-04-07
  tasks_completed: 3
  files_changed: 5
---

# Phase 02 Plan 02: Flutter Adaptive Intelligence UI Summary

Flutter adaptive intelligence UI: stall detection + replan trigger in RoadmapDetailScreen, two new ApiClient methods, Roadmap model with replan fields and isStalled() getter, new ExpertAnnotationScreen with level picker and text field, and "Annotate" badge on completed consultations in ExpertHomeScreen.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend ApiClient + Roadmap model | 1597740 | lib/services/api_client.dart, lib/models/roadmap.dart |
| 2 | Replan trigger + version banner | 88ab599 | lib/screens/roadmap_detail_screen.dart |
| 3 | ExpertAnnotationScreen + annotation trigger | 3081296 | lib/screens/expert_annotation_screen.dart, lib/screens/expert_home_screen.dart |

## What Was Built

### Task 1 — ApiClient + Roadmap Model Extensions

**`lib/services/api_client.dart`** gained two new methods:
- `replanRoadmap()` — POST `/api/v1/roadmaps/replan` with roadmap_id, current_progress, optional learner_feedback and stall_days
- `submitExpertAnnotation()` — POST `/api/v1/roadmaps/annotate` with roadmap_id, user_id, milestone_level, annotation

**`lib/models/roadmap.dart`** gained:
- Three nullable fields: `replanVersion`, `replanReason`, `previousRoadmapId`
- `isStalled({int thresholdDays = 14})` getter — returns true when any stage < 1.0 AND updatedAt > 14 days ago (ADAPT-01)
- `daysSinceUpdate()` helper — returns int? days since updatedAt
- `fromFirestore` reads `replan_version`, `replan_reason`, `previous_roadmap_id`
- `toFirestore` writes all three when non-null (conditional map spread)
- `copyWith` propagates all three new fields

### Task 2 — RoadmapDetailScreen Replan UI

Three new additions to `_RoadmapBodyState`:

1. **State flag**: `bool _isReplanning = false` — disables button during API call
2. **`_triggerReplan()`**: calls `svc.api.replanRoadmap()`, navigates via `pushReplacement` to the new roadmap ID returned in the response
3. **`_showReplanDialog()`**: AlertDialog with optional feedback TextField (max 500 chars) before triggering replan

Two new conditional sections in the `ListView`:

- **Replan version banner** (when `replanReason != null`): GlassCard with `auto_fix_high` icon, "Version N — Adapted for you" title, and AI replan_reason text. Appears above skill gaps. Animated with `fadeIn + slideY`.
- **Stall warning card** (when `isStalled()` is true): GlassCard with warm amber `warning_amber_rounded` icon, days-stalled count, explanatory text, and `FilledButton.icon` "Replan Roadmap". Button shows `CircularProgressIndicator` during API call. Animated with `fadeIn + slideY`.

### Task 3 — ExpertAnnotationScreen + ExpertHomeScreen

**`lib/screens/expert_annotation_screen.dart`** (new):
- Accepts `roadmapId`, `learnerId`, `consultationId` constructor params
- `_buildForm()`: GlassCard with `ChoiceChip` level selector (beginner/intermediate/advanced) + GlassCard with 6-line TextField (max 800 chars) + `FilledButton.icon` submit
- `_submit()`: calls `svc.api.submitExpertAnnotation()`, flips to success state on success, shows SnackBar on error
- `_buildSuccessState()`: centered GlassCard with check icon, confirmation message, and "Done" button that pops

**`lib/screens/expert_home_screen.dart`**:
- Added import for `expert_annotation_screen.dart`
- Replaced trailing `Icon(Icons.chevron_right)` with conditional:
  - `c.status == 'completed'` → Column with chevron + "Annotate" badge (primaryContainer background, bold text)
  - Otherwise → plain chevron icon
- Annotate badge `GestureDetector.onTap` navigates to `ExpertAnnotationScreen` with `consultationId`, `userId`, `c.id`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected service locator field name**
- **Found during:** Task 2 implementation
- **Issue:** Plan instructions referenced `context.svc.apiClient` but the actual `AppServices` InheritedWidget exposes the field as `api` (verified in `lib/providers/app_services.dart` line 36 and `consultation_detail_screen.dart` line 56 which uses `svc.api.createPaymentOrder()`)
- **Fix:** Used `svc.api` consistently in all three tasks (roadmap_detail_screen.dart and expert_annotation_screen.dart)
- **Files modified:** lib/screens/roadmap_detail_screen.dart, lib/screens/expert_annotation_screen.dart

**2. [Enhancement - Polish] Added flutter_animate on new UI cards**
- **Found during:** Task 2 + quality directive review
- **Issue:** Quality directive specified "Animations on new elements using flutter_animate"
- **Fix:** Added `.animate().fadeIn(duration: 400.ms).slideY(begin: ±0.05, end: 0)` on the replan version banner and stall warning card; `flutter_animate` was already imported in the file
- **Files modified:** lib/screens/roadmap_detail_screen.dart

## Known Stubs

None — all data flows are wired to live Firestore (via Roadmap.fromFirestore) and the FastAPI backend (via ApiClient methods). The `roadmapId` passed to `ExpertAnnotationScreen` is `c.consultationId` as documented in the plan — the backend resolves the user's active roadmap from `userId`.

## Self-Check

- [x] `lib/services/api_client.dart` — modified, commit 1597740
- [x] `lib/models/roadmap.dart` — modified, commit 1597740
- [x] `lib/screens/roadmap_detail_screen.dart` — modified, commit 88ab599
- [x] `lib/screens/expert_annotation_screen.dart` — created, commit 3081296
- [x] `lib/screens/expert_home_screen.dart` — modified, commit 3081296
- [x] All 3 task commits exist in git log
- [x] `replanRoadmap` defined in api_client.dart and called in roadmap_detail_screen.dart
- [x] `submitExpertAnnotation` defined in api_client.dart and called in expert_annotation_screen.dart
- [x] `isStalled()` defined in roadmap.dart and called in roadmap_detail_screen.dart
- [x] `ExpertAnnotationScreen` imported and navigated-to in expert_home_screen.dart
- [x] `replanReason` in roadmap.dart (fromFirestore + field) and roadmap_detail_screen.dart (banner)
- [x] No stubs — all screen logic wired to live backend calls

## Self-Check: PASSED
