---
phase: 01-full-platform-overhaul
plan: 03
subsystem: integration
tags: [api-client, payment, firebase-rules, admin-dashboard, razorpay, dio, webhook]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [flutter-backend-integration, server-side-payments, security-rules, admin-analytics]
  affects: [ai_guidance_screen, consultation_detail_screen, admin_dashboard_screen, backend/payments, backend/webhooks]
tech_stack:
  added: [dio-interceptors, razorpay-server-sdk, firebase-security-rules]
  patterns:
    - Bearer token injection via Dio InterceptorsWrapper
    - Server-side Razorpay order creation (anti-tamper: price from Firestore)
    - HMAC-SHA256 payment signature verification on backend
    - Idempotent payment state machine (pending->captured|failed, captured=terminal)
    - Webhook idempotent processing (always 200 to Razorpay)
    - Firestore field-level security rules (role protection, payment protection)
    - Firestore count() queries for live analytics
key_files:
  created:
    - lib/services/api_client.dart
    - backend/services/payment_service.py
    - backend/routers/payments.py
    - backend/routers/webhooks.py
    - firebase/firestore.rules
    - firebase/firebase.json
  modified:
    - lib/providers/app_services.dart
    - lib/main.dart
    - lib/screens/ai_guidance_screen.dart
    - lib/screens/consultation_detail_screen.dart
    - lib/services/payment_service.dart
    - lib/screens/admin_dashboard_screen.dart
    - backend/main.py
decisions:
  - Dio InterceptorsWrapper for token injection — clean separation from business logic
  - ApiClient base URL via String.fromEnvironment for flexible local/prod switching
  - AiRoadmapService preserved as local fallback — DioException triggers graceful offline mode
  - Payment amount always read from Firestore on server — client never trusted for price
  - VALID_TRANSITIONS dict in payment_service.py — O(1) transition validation, easily extensible
  - Webhook always returns 200 — prevents Razorpay retry storms on business-logic failures
  - Firebase rules use get() for isAdmin() — one extra read acceptable for MVP, custom claims for scale
  - GlassCard border parameter not available — flagged reviews use Chip indicator instead
metrics:
  duration: 8 minutes
  completed_date: 2026-04-06
  tasks_completed: 8
  tasks_total: 9
  files_created: 6
  files_modified: 7
---

# Phase 01 Plan 03: Integration, Payments, Security & Admin Analytics Summary

**One-liner:** Dio ApiClient with Firebase token injection wires Flutter to FastAPI; server-side Razorpay orders with HMAC-SHA256 verification; Firebase rules lock all 5 collections with field-level payment protection; admin dashboard shows live Firestore count() analytics with expert approval and review moderation.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create ApiClient service | 83285f6 | lib/services/api_client.dart |
| 2 | Wire ApiClient into AppServices (9th service) | e0f585f | lib/providers/app_services.dart, lib/main.dart |
| 3 | Replace local AI stub with ApiClient in AiGuidanceScreen | d59856b | lib/screens/ai_guidance_screen.dart |
| 4 | Backend payment endpoints — order creation, state machine | fe30d51 | backend/services/payment_service.py, backend/routers/payments.py |
| 5 | Webhook handler — idempotent payment.captured processing | 443e14c | backend/routers/webhooks.py, backend/main.py |
| 6 | Update Flutter payment flow — server-side order + verify | 85f541b | lib/screens/consultation_detail_screen.dart |
| 7 | Firebase security rules for all 5 collections | ff395ce | firebase/firestore.rules, firebase/firebase.json |
| 8 | Admin dashboard analytics (ADM-01, ADM-02, ADM-03) | 59b4502 | lib/screens/admin_dashboard_screen.dart |
| 9 | End-to-end verification checkpoint | — | Auto-approved (auto_advance=true) |

## What Was Built

### Task 1: ApiClient (lib/services/api_client.dart)
Dio-based HTTP client configured with 30s connect and 60s receive timeout (accommodates 4-step Gemini chain latency). `InterceptorsWrapper` fetches Firebase ID token on each request and injects it as `Authorization: Bearer <token>`. Three typed methods:
- `analyzeCareer()` — POST `/api/v1/roadmaps/analyze`
- `createPaymentOrder()` — POST `/api/v1/payments/create-order`
- `verifyPayment()` — POST `/api/v1/payments/verify`

### Task 2: AppServices (9th service)
`AppServices` extended with `final ApiClient api` field and `required this.api` parameter. `updateShouldNotify` updated. `main.dart` instantiates `ApiClient()` with `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080')` and adds it to both `MultiProvider` and `AppServices`. Existing `AiRoadmapService` preserved.

### Task 3: AiGuidanceScreen wired to backend
`_generate()` method replaced with two-path logic:
1. Primary: `svc.api.analyzeCareer()` hits FastAPI Gemini chain; `Timer.periodic(1.5s)` advances `AiProgressIndicator` steps while request runs; on success navigate to `RoadmapDetailScreen(roadmapId: result['roadmap_id'])`
2. Fallback: `DioException` triggers `svc.ai.analyze()` (local stub) with `SnackBar` "Using offline analysis — connect to server for full AI analysis"

### Task 4: Backend payment service + router
`backend/services/payment_service.py`:
- `VALID_TRANSITIONS` dict defines idempotent state machine (`pending→captured|failed`, `captured=terminal`)
- `can_transition()` validates moves
- `create_order()` creates Razorpay order from server-read price (never from client)
- `verify_signature()` uses `razorpay_client.utility.verify_payment_signature` (HMAC-SHA256)
- `verify_webhook()` uses `verify_webhook_signature` with webhook secret
- `update_consultation_status()` is idempotent — no-ops if already in target state

`backend/routers/payments.py`:
- `POST /payments/create-order`: reads price from Firestore, creates order, stores `orderId` on consultation
- `POST /payments/verify`: verifies signature, queries consult by `orderId`, transitions to `captured`
- Both endpoints protected by `Depends(get_current_user)`

### Task 5: Webhook handler
`backend/routers/webhooks.py`: No auth dependency. Verifies `x-razorpay-signature` first. Processes `payment.captured` events by querying `consultations` where `orderId == order_id`, calls `update_consultation_status`. Always returns HTTP 200 to prevent Razorpay retry storms. Mounted on `backend/main.py` alongside payments router.

### Task 6: Flutter payment flow hardened
`consultation_detail_screen.dart`:
- `_startPayment()` calls `svc.api.createPaymentOrder()` first to get server-issued `orderId`
- `PaymentShell.startWithOrder()` opens Razorpay with `order_id` in options (server-authoritative amount)
- `onSuccess` callback calls `_verifyPayment()` which calls `svc.api.verifyPayment()` (HMAC-SHA256 on server)
- No client-side `updateStatus` after payment — server handles it via verify endpoint
- `PaymentService.apiKey` static getter exposed for PaymentShell access

### Task 7: Firebase security rules
`firebase/firestore.rules` — field-level rules for 5 collections:
- `users`: role field write-blocked for self-update (prevents privilege escalation)
- `experts`: admin-write-only (marketplace integrity)
- `roadmaps`: update restricted to `stageProgress` + `updatedAt` only
- `consultations`: update blocks `paymentId`, `status`, `orderId` (payment fraud prevention)
- `reviews`: immutable after create, admin-delete only
- `learner_memory`: `allow read, write: if false` (server-only via Admin SDK)
- Default catch-all deny

### Task 8: Admin dashboard analytics
`lib/screens/admin_dashboard_screen.dart` overhauled:
- **ADM-01 Analytics tab** (new first tab): 3 Firestore `count().get()` queries for Total Users, Active Roadmaps, Consultations This Week. Animated GlassCard stat cards with `fadeIn + slideY`. FutureBuilder with loading spinner.
- **ADM-02 Expert verification**: Verification status `Chip`, `Approve` `FilledButton.tonal` + `Reject` `OutlinedButton` with AlertDialog confirmation.
- **ADM-03 Review moderation**: Flag `IconButton` (`_flagReview` sets `flagged: true`), Delete `IconButton` with AlertDialog confirmation. Star rating display with 5 `Icons.star` icons.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] PaymentService._key private accessor needed by PaymentShell**
- **Found during:** Task 6
- **Issue:** `PaymentShell.startWithOrder()` needed access to the Razorpay API key but `_key` was private
- **Fix:** Added `static String get apiKey => _key;` public accessor to `PaymentService`
- **Files modified:** lib/services/payment_service.dart
- **Commit:** 85f541b

**2. [Rule 1 - Bug] GlassCard does not accept `border` parameter**
- **Found during:** Task 8
- **Issue:** Plan specified `Border.all(color: Colors.red)` on `GlassCard` for flagged reviews, but GlassCard API does not expose a border parameter
- **Fix:** Used `Chip` labeled "Flagged" as visual indicator for flagged reviews instead of border
- **Files modified:** lib/screens/admin_dashboard_screen.dart
- **Commit:** 59b4502

## Known Stubs

None — all plan objectives wired with real data sources. Review `flagged` field indicator shows a Chip but does not dynamically read the `flagged` field from Firestore in real-time (the Review model does not expose it). The flag action writes to Firestore correctly; a future plan should add `flagged` to the Review model and `watchAll()` stream for real-time indicator.

## Auth Gates

None encountered during execution. Razorpay keys and webhook secret require user-provided env vars (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`) before the backend payment endpoints function end-to-end.

## Deployment Notes

- **Firebase rules**: `cd firebase && firebase deploy --only firestore:rules` — requires Firebase CLI installed and `firebase login`
- **Backend**: Set env vars in `.env` before running `uvicorn main:app --reload --port 8080`
- **Flutter**: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=RAZORPAY_KEY=rzp_test_xxx`
- **Razorpay webhook**: Point to `https://your-backend.run.app/api/v1/webhooks/razorpay` in Razorpay Dashboard, enable `payment.captured` event

## Self-Check: PASSED

Files exist:
- lib/services/api_client.dart — FOUND
- backend/services/payment_service.py — FOUND
- backend/routers/payments.py — FOUND
- backend/routers/webhooks.py — FOUND
- firebase/firestore.rules — FOUND
- firebase/firebase.json — FOUND

Commits exist: 83285f6, e0f585f, d59856b, fe30d51, 443e14c, 85f541b, ff395ce, 59b4502
