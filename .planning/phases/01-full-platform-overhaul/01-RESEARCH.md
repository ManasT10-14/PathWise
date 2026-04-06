# Phase 1: Full Platform Overhaul - Research

**Researched:** 2026-04-07
**Domain:** FastAPI backend + Vertex AI prompt chain + Flutter UI overhaul + Razorpay payment hardening + Firebase security + Admin dashboard
**Confidence:** HIGH

## Summary

Phase 1 is a monolithic delivery comprising six workstreams that must ship together: (1) FastAPI backend with Vertex AI Gemini 2.5 Flash 4-step prompt chain, (2) Flutter UI transformation with glassmorphism and animations, (3) Flutter-to-backend integration replacing the local AI stub, (4) server-side Razorpay payment hardening, (5) Firebase security rules for all collections, and (6) admin dashboard analytics. The existing codebase is well-structured for this -- the `AiRoadmapService` was designed as a swap-ready placeholder, the `AppServices` InheritedWidget makes adding a 9th service (`ApiClient`) a single-point change, and `Roadmap.fromFirestore()` already tolerates unknown fields.

The critical execution risk is the AI prompt chain: Gemini 2.5 Flash has documented intermittent JSON failures (truncated responses, backtick-wrapped output, infinite token repetition). Every chain step must have response validation, retry logic, and a Pydantic `response_schema` enforcing structure. The 6-8 second latency for 4 sequential Vertex AI calls demands a progress storytelling UI ("Analyzing skills..." through "Curating resources...") to prevent user abandonment during the most important moment of the product experience.

The UI overhaul scope is large (14 screens) but architecturally shallow -- it is themed component replacement, not structural rewrites. The glassmorphism approach using `BackdropFilter` (no third-party packages) needs performance discipline: `ClipRRect` bounding, `RepaintBoundary` caching, limited to 3-4 key elements per screen, blur sigma of 6-12. Budget Android devices (target demographic: Indian students) will be the performance floor.

**Primary recommendation:** Build the FastAPI backend first (foundation + prompt chain), then wire Flutter integration and UI overhaul in parallel, then payment hardening and security as the final layer. The backend carries the highest iteration risk (prompt tuning) and should start earliest.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | Glassmorphism design system with BackdropFilter | BackdropFilter patterns, performance guidance (sigma 6-12, ClipRRect, RepaintBoundary), BackdropGroup for Flutter 3.29+ |
| UI-02 | Multi-step onboarding wizard with progress indicator | Existing AiGuidanceScreen is a single form -- refactor into stepper/page-view with animated transitions |
| UI-03 | Dark mode and light mode with consistent color scheme | ThemeData dual color schemes, existing `colorScheme.fromSeed` pattern to extend |
| UI-04 | Micro-interactions on key actions | flutter_animate chainable effects, AnimatedBuilder isolation, const children, RepaintBoundary |
| UI-05 | Skeleton loading screens | shimmer package for content-loading placeholders, replaces bare CircularProgressIndicator |
| UI-06 | Roadmap as vertical timeline with connected nodes | CustomPainter for timeline spine, milestone cards, pulsing current node |
| UI-07 | AI analysis 4-step progress storytelling | AnimatedSwitcher with step labels synced to prompt chain progress, Stepper or custom widget |
| UI-08 | Expert marketplace filters | Domain chips, price slider, rating filter, sort -- client-side filtering on existing StreamBuilder data |
| UI-09 | Polished error states with retry and empty states | Error/empty state widgets per screen, replacing bare Center(Text(...)) patterns |
| UI-10 | Gradient mesh backgrounds behind glass cards | Gradient decoration layer beneath BackdropFilter cards on home, roadmap, expert profile |
| AI-01 | FastAPI backend with Firebase Admin SDK | FastAPI scaffold, config, auth dependency, Cloud Run deployment target |
| AI-02 | Vertex AI Gemini 2.5 Flash with google-genai SDK | Client init with vertexai=True, response_schema with Pydantic models, structured JSON output |
| AI-03 | 4-step prompt chain | Sequential chain: Goal Analyzer -> Skill Gap -> Roadmap Planner -> Resource Curator |
| AI-04 | Goal Analyzer structured extraction | Pydantic GoalAnalysis model, temperature 0.2, system prompt as .txt file |
| AI-05 | Skill Gap Detector with confidence scores | SkillGapAnalysis model with confidence 0-1 per skill, prerequisite ordering |
| AI-06 | Roadmap Planner with milestones and deadlines | RoadmapPlan model with phases, duration, skills, weekly_hours |
| AI-07 | Resource Curator with URLs and types | CuratedResources model with per-phase resource lists, URL hallucination risk |
| AI-08 | Replace AiRoadmapService with HTTP client | New ApiClient service in AppServices (9th service), Dio with auth interceptor |
| AI-09 | JSON validation with retry logic | Validate JSON after each Gemini call, truncation repair, exponential backoff, max 3 retries |
| AI-10 | Per-user rate limiting | slowapi with in-memory backend (dev), 10 analyses/day, 3 replans/day |
| ADAPT-06 | Confidence scores displayed as colored badges | Map confidence scores from AI-05 output to colored UI badges next to each skill gap |
| EXP-01 | Expert discovery with search and filters | Domain filter chips, price range, rating filter, sort options on ExpertsScreen |
| EXP-02 | Expert profile with full context | Enhanced ExpertDetailScreen with skill list, experience, reviews, AI context during consultations |
| EXP-03 | Consultation booking flow polish | Improved BookConsultationScreen with clear type selection, scheduling, pricing |
| PAY-01 | Server-side Razorpay order creation | FastAPI endpoint, amount read from Firestore (not client), order_id returned to Flutter |
| PAY-02 | Payment signature verification on server | HMAC-SHA256 verification via razorpay Python SDK before consultation status update |
| PAY-03 | Webhook handler for payment.captured | POST /api/v1/webhooks/razorpay with signature verification, idempotent processing |
| PAY-04 | Idempotent payment state machine | Status transitions: pending -> captured, pending -> failed; never captured -> failed |
| SEC-01 | Firebase security rules for 5 collections | Default deny, field-level validation, client vs server write separation |
| SEC-02 | FastAPI auth middleware | Firebase ID token verification via get_current_user dependency on every endpoint |
| SEC-03 | Input sanitization on AI endpoints | Strip control characters, enforce length limits (resume 10K chars, goals 500 chars, 50 skills max) |
| SEC-04 | PII handling for resume and career goals | Never log in full, hash for debugging, structured logging with PII redaction |
| ADM-01 | Admin dashboard analytics | Platform stats: total users, active roadmaps, consultations this week |
| ADM-02 | Expert verification workflow | Enhanced verification with approval/rejection actions (existing toggle + polish) |
| ADM-03 | Review moderation with flagging | Existing delete + add flag/unflag capability |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

The following directives from CLAUDE.md are binding:

- **AI Model**: Vertex AI Gemini 2.5 Flash only -- no LangGraph or other frameworks
- **Backend**: FastAPI (Python) with Firebase Admin SDK integration
- **Frontend**: Flutter 3.x -- enhance, do not rewrite from scratch
- **Database**: Firebase Firestore -- user manages database setup
- **Payments**: Razorpay -- already integrated, needs production hardening
- **Platform**: Android-first (iOS/Web later)
- **Authentication**: Google Sign-In via Firebase Auth (existing)
- **GSD Workflow**: Do not make direct repo edits outside a GSD workflow unless user explicitly asks to bypass

## Standard Stack

### Core (Existing -- Do Not Replace)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | ^3.11.4 | Mobile framework | Existing app, 14 screens |
| Firebase Core | ^3.8.1 | BaaS | Existing infrastructure |
| Firebase Auth | ^5.3.4 | Authentication | Google Sign-In, existing |
| Cloud Firestore | ^5.5.1 | NoSQL database | Existing data layer |
| Provider | ^6.1.2 | State management | Existing, keep per constraint |
| razorpay_flutter | ^1.4.0 | Client-side payments | Existing Razorpay SDK |

### Backend Additions (Python)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python | 3.12+ | Runtime | FastAPI requires 3.10+; 3.12 for best compatibility. Note: local machine has 3.11 -- use 3.12 in Docker |
| FastAPI | 0.135.3 | API framework | User's choice, async-native, Pydantic integration |
| Uvicorn | 0.41.0 | ASGI server | Standard FastAPI server with `[standard]` extras |
| google-genai | 1.70.0 | Vertex AI SDK | Official SDK, replaces deprecated vertexai module |
| Pydantic | 2.12.5 | Validation + schemas | Core FastAPI dependency, Gemini response_schema |
| pydantic-settings | 2.13.1 | Environment config | Load .env with type validation |
| firebase-admin | 7.3.0 | Server-side Firebase | Token verification, Firestore CRUD |
| razorpay | 2.0.1 | Server-side payments | Order creation, signature verification |
| structlog | 25.5.0 | Structured logging | JSON logs for production |
| slowapi | 0.1.9 | Rate limiting | Per-user rate limits for AI endpoints |
| httpx | 0.28.1 | Async HTTP client | Outbound HTTP calls if needed |

### Flutter Additions

| Package | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dio | ^5.9.2 | HTTP client | Interceptors for auth token injection, retry, logging |
| flutter_animate | ^4.5.2 | Animation system | Chainable declarative animations, scroll-aware effects |
| lottie | ^3.3.2 | Complex animations | Onboarding, loading states, celebration effects |
| google_fonts | ^6.2.1 | Typography | UI overhaul typography layer |
| shimmer | ^3.0.0 | Skeleton loading | Content placeholders during AI analysis (5-10s waits) |

### Deployment

| Technology | Purpose | Why Standard |
|------------|---------|--------------|
| Google Cloud Run | FastAPI hosting | Serverless, auto-scaling, pay-per-use, GCP-native |
| Docker | Containerization | Required for Cloud Run, multi-stage Python 3.12-slim |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dio | dart:http | No interceptors, no retry, no auth injection. Dio is better for production API communication |
| slowapi | Custom middleware | slowapi is battle-tested, integrates cleanly with FastAPI |
| Pydantic response_schema | Prompt-only JSON | Prompt-only JSON fails intermittently. response_schema enforces structure at the API level |
| BackdropFilter (manual) | glassmorphism package | Package unmaintained since 2021. Manual gives full control, zero dependencies |
| flutter_animate | Manual AnimationController | 10x more boilerplate, error-prone dispose lifecycle |

**Python Backend Installation:**
```bash
python3.12 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

pip install fastapi==0.135.3 "uvicorn[standard]==0.41.0"
pip install google-genai==1.70.0
pip install firebase-admin==7.3.0
pip install razorpay==2.0.1
pip install pydantic==2.12.5 pydantic-settings==2.13.1
pip install structlog==25.5.0 slowapi==0.1.9 httpx==0.28.1

pip freeze > requirements.txt
```

**Flutter pubspec.yaml Additions:**
```yaml
dependencies:
  # ... existing deps unchanged ...
  dio: ^5.9.2
  flutter_animate: ^4.5.2
  lottie: ^3.3.2
  google_fonts: ^6.2.1
  shimmer: ^3.0.0
```

## Architecture Patterns

### Recommended Project Structure

```
PathWise-Mobile-App/
  lib/                          # Existing Flutter app
    main.dart                   # Add dark theme, ApiClient to AppServices
    providers/
      app_services.dart         # Add ApiClient as 9th service
    services/
      api_client.dart           # NEW: Dio-based HTTP client with Firebase token
      ai_roadmap_service.dart   # KEEP as offline fallback
      ... (existing 7 services unchanged)
    models/
      ... (existing 5 models, extend Roadmap)
    screens/
      ... (existing 14 screens, UI overhaul in-place)
    theme/                      # NEW
      app_theme.dart            # Light/dark ThemeData with glassmorphism colors
      glass_card.dart           # Reusable glassmorphism card widget
      gradient_background.dart  # Gradient mesh backgrounds
    widgets/                    # NEW
      skeleton_loader.dart      # Reusable shimmer loading widget
      error_state.dart          # Reusable error + retry widget
      empty_state.dart          # Reusable empty state widget
      ai_progress_indicator.dart # 4-step AI analysis storytelling
      timeline_node.dart        # Vertical timeline components
  backend/                      # NEW: FastAPI project
    main.py
    config.py
    dependencies.py
    routers/
      health.py
      roadmaps.py
      payments.py
      webhooks.py
    services/
      prompt_chain.py
      goal_analyzer.py
      skill_gap_analyzer.py
      roadmap_planner.py
      resource_curator.py
      payment_service.py
    models/
      requests.py
      responses.py
      ai_schemas.py
      firestore_models.py
    prompts/
      goal_analyzer.txt
      skill_gap_analyzer.txt
      roadmap_planner.txt
      resource_curator.txt
    Dockerfile
    requirements.txt
    .env.example
```

### Pattern 1: Thin Backend, Shared Database

**What:** Flutter reads Firestore directly for real-time UI (StreamBuilder). FastAPI writes Firestore via Admin SDK for AI/payment operations. Both access the same Firestore instance.

**When:** All data flows in this project.

**Why:** Preserves existing 14-screen StreamBuilder pattern. No real-time capability needed from FastAPI. Flutter continues reading immediately; FastAPI writes trigger StreamBuilder refreshes automatically.

**Example:**
```dart
// Flutter: read roadmap via StreamBuilder (EXISTING -- no change)
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance.collection('roadmaps').doc(roadmapId).snapshots(),
  builder: (context, snap) {
    if (!snap.hasData) return SkeletonLoader(); // NEW: replaces CircularProgressIndicator
    final r = Roadmap.fromFirestore(snap.data!.id, snap.data!.data()!);
    return RoadmapTimeline(roadmap: r); // NEW: replaces flat card list
  },
);
```

### Pattern 2: ApiClient with Firebase Token Injection

**What:** Dio-based HTTP client that automatically attaches the Firebase ID token to every request.

**When:** Every Flutter -> FastAPI call.

**Example:**
```dart
class ApiClient {
  ApiClient({required this.baseUrl}) {
    _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: Duration(seconds: 30)));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _dio.post(path, data: body);
    return response.data as Map<String, dynamic>;
  }
}
```

### Pattern 3: Pydantic Models as Triple-Duty Contracts

**What:** Each Pydantic model serves as (a) Gemini `response_schema`, (b) FastAPI response model, and (c) internal contract between chain steps.

**When:** Every prompt chain step, every API endpoint.

**Example:**
```python
from pydantic import BaseModel, Field

class GoalAnalysis(BaseModel):
    target_role: str = Field(description="Inferred target career role")
    career_direction: str = Field(description="Broader career trajectory")
    constraints: list[str] = Field(description="Time, resource, or skill constraints")
    timeframe_months: int = Field(description="Estimated months to reach target")
    confidence: float = Field(ge=0, le=1, description="Confidence in this analysis")

# Used as: Gemini response_schema, FastAPI response model, and chain step contract
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config={"response_mime_type": "application/json", "response_schema": GoalAnalysis},
)
```

### Pattern 4: Progressive Schema Extension

**What:** Add new fields to Firestore documents without removing or renaming existing fields.

**When:** Every Firestore write from FastAPI.

**Why:** The existing `Roadmap.fromFirestore()` uses null-safe patterns (`m['field']?.toString() ?? ''`). New fields are silently ignored by the current Flutter code. FastAPI MUST populate legacy fields (`milestones[]`, `resources[]`, `timeline`) alongside new fields (`phases[]`, `curatedResources[]`, `goalAnalysis{}`).

### Pattern 5: Glassmorphism Component Library

**What:** Reusable `GlassCard` widget using `BackdropFilter` with performance guardrails baked in.

**When:** Home screen, roadmap, expert profile -- NOT every surface.

**Example:**
```dart
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.blur = 10});
  final Widget child;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### Pattern 6: Idempotent Payment State Machine

**What:** Payment status transitions are one-directional. Only allowed: `pending -> captured`, `pending -> failed`. Never `captured -> failed`.

**When:** Both `/verify` endpoint and `/webhooks/razorpay` handler.

**Example:**
```python
VALID_TRANSITIONS = {
    "pending": {"captured", "failed"},
    "captured": set(),  # terminal state
    "failed": {"pending"},  # retry allowed
}

def transition_payment(current: str, target: str) -> bool:
    return target in VALID_TRANSITIONS.get(current, set())
```

### Anti-Patterns to Avoid

- **Routing all Firestore reads through FastAPI:** Breaks StreamBuilder real-time updates, requires rewriting 14 screens. Flutter reads directly.
- **Vertex AI credentials in Flutter APK:** API keys extractable via apktool. All AI calls go through FastAPI.
- **Client-side payment amount determination:** Current code reads `c.price` from Firestore on client. Server must read price and create order.
- **Monolithic single-prompt AI call:** One prompt for all 4 steps is harder to debug, iterate, and retry.
- **Synchronous firebase_admin in async handlers:** Blocks event loop. Use `def` handlers (FastAPI runs in threadpool) or `asyncio.to_thread()`.
- **Animating layout-triggering properties:** Animate `Transform.translate` and `Opacity`, not width/height/padding.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP client with auth | Raw dart:http with manual token management | Dio with interceptors | Auth token injection, retry, logging, timeout all built in |
| JSON validation for Gemini | Manual string parsing | Pydantic response_schema + model_validate_json | Gemini enforces schema; Pydantic validates; both layers catch failures |
| Rate limiting | Custom request counter | slowapi with Starlette integration | Battle-tested, supports multiple backends (memory, Redis) |
| Payment signature verification | Manual HMAC computation | razorpay Python SDK `client.utility.verify_payment_signature()` | SDK handles exact HMAC format Razorpay expects |
| Animations | Manual AnimationController lifecycle | flutter_animate | Declarative, chainable, handles dispose automatically |
| Loading skeletons | Custom shimmer painting | shimmer package | Standard Flutter community solution, minimal setup |
| Structured logging | print() statements | structlog | JSON output, correlation IDs, async-friendly, processor pipeline |
| Glassmorphism | Third-party glassmorphism packages | Manual BackdropFilter + ClipRRect | All packages unmaintained or too new; manual approach has zero dependencies |

**Key insight:** The complexity in this phase is in the prompt engineering and UI polish, not in infrastructure plumbing. Use established libraries for plumbing so development time focuses on the 4-step prompt chain quality and the glassmorphism visual layer.

## Common Pitfalls

### Pitfall 1: Gemini Structured JSON Output Failures (CRITICAL)

**What goes wrong:** Gemini 2.5 Flash intermittently produces broken JSON: truncated mid-object, backtick-wrapped output, infinite token repetition until max_tokens, and 400 errors claiming "JSON mode is not enabled."

**Why it happens:** Google changes structured output behavior across model versions without warning. Token-heavy responses sometimes hit internal limits before completing valid JSON. Tool-calling history mixed with structured output causes failures.

**How to avoid:**
1. Always use `response_mime_type: "application/json"` WITH `response_schema` (Pydantic model)
2. JSON validation + repair layer after every Gemini call
3. Set `max_output_tokens` to 2x expected output size
4. Retry with exponential backoff (max 3 attempts per step)
5. Never mix tool-calling and structured output in the same request
6. Pin model version (`gemini-2.5-flash-001`) for stability

**Warning signs:** Responses with `finish_reason: "MAX_TOKENS"`, JSON parse exceptions, inconsistent response lengths.

### Pitfall 2: Prompt Chain Silent Semantic Corruption (CRITICAL)

**What goes wrong:** Goal Analyzer misidentifies the target role. All downstream steps proceed confidently on the wrong premise. User gets a polished, irrelevant roadmap.

**Why it happens:** LLMs don't raise exceptions for semantic errors. JSON validates structurally even when content is wrong.

**How to avoid:**
1. Add confidence scores to every chain step output (0.0-1.0)
2. Include original user input in EVERY step's prompt (not just step 1)
3. Log full chain input/output in Firestore for debugging
4. Pass user_input fields alongside each step's output to next step

**Warning signs:** User feedback saying recommendations don't match goals, anomalously short analyses.

### Pitfall 3: Client-Side Payment Trust (CRITICAL)

**What goes wrong:** Flutter trusts client-side Razorpay callback as proof of payment. Current code (line 77 of `consultation_detail_screen.dart`) directly calls `svc.consultations.updateStatus(c.id, 'accepted')` after client callback.

**How to avoid:**
1. Server creates Razorpay order (reads price from Firestore, not client)
2. Server verifies HMAC signature before updating status
3. Webhook handler as backup confirmation
4. NEVER update payment status from Flutter directly

### Pitfall 4: Webhook Idempotency (CRITICAL)

**What goes wrong:** Razorpay retries webhooks. Without idempotency, duplicate processing creates duplicate consultations. Out-of-order events (`failed` after `captured`) overwrite success with failure.

**How to avoid:**
1. Check `processed_webhook_ids` before processing
2. State machine transitions only (pending -> captured, never captured -> failed)
3. Respond 200 immediately, process asynchronously
4. Firestore transactions for status updates

### Pitfall 5: BackdropFilter Performance Collapse (MODERATE)

**What goes wrong:** Multiple `BackdropFilter` widgets with blur cause frame drops below 30fps on mid-range Android. Each forces full GPU re-render of the area behind it.

**How to avoid:**
1. Use `BackdropGroup` (Flutter 3.29+) to batch blur operations
2. Limit blur to small bounded elements (cards, dialogs) -- never full-screen
3. Wrap in `ClipRRect` to constrain repaint area
4. Cache static backgrounds with `RepaintBoundary`
5. Blur sigma 6-12 (not 15-20) -- visual effect similar, cost much lower
6. Test on budget Android device (Redmi/Realme under INR 10,000)

### Pitfall 6: Animation Rebuild Storm (MODERATE)

**What goes wrong:** Animating at a high widget tree level forces 60fps rebuilds of the entire subtree below.

**How to avoid:**
1. Use `AnimatedBuilder` / `AnimatedWidget` for isolated rebuilds
2. Mark static children as `const`
3. Wrap animated sections in `RepaintBoundary`
4. Use `Transform` for position/rotation/scale (GPU compositing, no layout)
5. flutter_animate handles most of this automatically

### Pitfall 7: Firestore Security Rules vs Admin SDK Confusion (MODERATE)

**What goes wrong:** Rules that appear comprehensive but leave server-written data unprotectable, or rules so restrictive they block Flutter from reading server-written roadmaps.

**How to avoid:**
1. Map every collection: who reads (client/server/both), who writes, which fields
2. Field-level validation in rules: clients cannot write `payment_status` (only server via Admin SDK)
3. Default deny base rule, explicitly allow specific operations
4. Test with Firebase Emulator Suite

### Pitfall 8: Vertex AI Quota Exhaustion and Cost Runaway (MODERATE)

**What goes wrong:** 4-step chain = 4 API calls per user. Retry loops on broken JSON compound this. No built-in spend cap on Vertex AI.

**How to avoid:**
1. Per-user rate limiting: max 10 analyses/day via slowapi
2. Hard retry ceiling: 3 retries per step, then graceful failure
3. GCP budget alerts at 50%, 80%, 100%
4. Cache repeat analyses (same goal within 24h -> return cached)
5. Circuit breaker: if error rate > 50% in 5 minutes, stop making calls

### Pitfall 9: Blocking Event Loop with Synchronous Firebase Admin SDK (MINOR)

**What goes wrong:** `firebase_admin` Firestore operations are synchronous. In `async def` handlers, this blocks the event loop.

**How to avoid:** Declare route handlers as `def` (not `async def`) -- FastAPI runs them in a threadpool automatically. For genuinely async handlers, use `asyncio.to_thread()`.

### Pitfall 10: Service Account Key Exposure (MINOR)

**What goes wrong:** Firebase service account JSON committed to repo or baked into Docker image.

**How to avoid:**
1. Add `*.json` service account files to `.gitignore`
2. Use `GOOGLE_APPLICATION_CREDENTIALS` env var
3. On Cloud Run, use workload identity (no key file needed)

## Code Examples

### Vertex AI Client Initialization (google-genai SDK)
```python
# Source: STACK.md / Vertex AI docs
from google import genai
from google.genai.types import HttpOptions

client = genai.Client(
    vertexai=True,
    project="pathwise-aedc5",
    location="us-central1",
    http_options=HttpOptions(api_version="v1"),
)
MODEL = "gemini-2.5-flash"
```

### Prompt Chain Step with Validation
```python
# Source: ARCHITECTURE.md / PITFALLS.md
import json
from pydantic import BaseModel, Field, ValidationError
from tenacity import retry, stop_after_attempt, wait_exponential

class SkillGapAnalysis(BaseModel):
    gaps: list[dict] = Field(description="List of skill gaps")
    strengths: list[str] = Field(description="Skills the user has")
    confidence: float = Field(ge=0, le=1)

@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
async def analyze_skill_gaps(goal: GoalAnalysis, user_input: dict) -> SkillGapAnalysis:
    prompt = load_prompt("skill_gap_analyzer.txt").format(
        target_role=goal.target_role,
        skills=", ".join(user_input["skills"]),
        resume_text=user_input["resume_text"][:10000],  # SEC-03: input length limit
    )
    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": SkillGapAnalysis,
            "max_output_tokens": 4096,
        },
    )
    return SkillGapAnalysis.model_validate_json(response.text)
```

### FastAPI Auth Dependency
```python
# Source: ARCHITECTURE.md
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin.auth

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    try:
        decoded = firebase_admin.auth.verify_id_token(credentials.credentials)
        return decoded
    except firebase_admin.auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except firebase_admin.auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")
```

### Razorpay Server-Side Order + Verification
```python
# Source: STACK.md / PITFALLS.md
import razorpay

razorpay_client = razorpay.Client(auth=(KEY_ID, KEY_SECRET))

# Order creation
order = razorpay_client.order.create({
    "amount": consultation.price * 100,  # paise
    "currency": "INR",
    "receipt": consultation_id,
})

# Signature verification
razorpay_client.utility.verify_payment_signature({
    "razorpay_order_id": order_id,
    "razorpay_payment_id": payment_id,
    "razorpay_signature": signature,
})

# Webhook verification
razorpay_client.utility.verify_webhook_signature(
    body=raw_body,
    signature=webhook_signature,
    secret=webhook_secret,
)
```

### Flutter Glassmorphism Card
```dart
// Source: STACK.md / PITFALLS.md
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.blur = 10, this.opacity = 0.15});
  final Widget child;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(opacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
```

### AI Analysis Progress Storytelling
```dart
// Source: FEATURES.md (D6)
class AiProgressIndicator extends StatefulWidget {
  const AiProgressIndicator({super.key, required this.currentStep});
  final int currentStep; // 0-3

  @override
  State<AiProgressIndicator> createState() => _AiProgressIndicatorState();
}

class _AiProgressIndicatorState extends State<AiProgressIndicator> {
  static const _steps = [
    'Analyzing your background...',
    'Identifying skill gaps...',
    'Building your roadmap...',
    'Curating resources...',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        final isActive = i == widget.currentStep;
        final isDone = i < widget.currentStep;
        return ListTile(
          leading: isDone
              ? const Icon(Icons.check_circle, color: Colors.green)
              : isActive
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radio_button_unchecked),
          title: Text(_steps[i], style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
        );
      }),
    );
  }
}
```

### Firebase Security Rules
```javascript
// Source: PRD Section 12.2
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: read own, admins read all, write own profile
    match /users/{uid} {
      allow read: if request.auth.uid == uid
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow write: if request.auth.uid == uid;
    }

    // Experts: authenticated read, admin write
    match /experts/{expertId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Roadmaps: owner + admin read, owner write (progress only)
    match /roadmaps/{roadmapId} {
      allow read: if request.auth.uid == resource.data.userId
                   || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.userId
                     && request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['stageProgress', 'updatedAt']);
    }

    // Consultations: involved parties + admin
    match /consultations/{cid} {
      allow read: if request.auth.uid == resource.data.userId
                  || request.auth.uid == resource.data.expertId
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.userId
                    || request.auth.uid == resource.data.expertId;
    }

    // Reviews: authenticated read, author create, admin delete
    match /reviews/{rid} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow delete: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Learner memory: server-only (Admin SDK bypasses rules)
    match /learner_memory/{uid} {
      allow read, write: if false;  // Only Admin SDK
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| google-cloud-aiplatform (vertexai module) | google-genai SDK | Deprecated June 2025, removal June 2026 | Must use google-genai with vertexai=True |
| firebase_vertexai Flutter package | firebase_ai package | May 2025 rename | Not applicable -- Flutter does NOT call Vertex AI directly |
| Manual AnimationController | flutter_animate | Mature library, de facto standard | Eliminates boilerplate, handles dispose automatically |
| glassmorphism package (3.0.0) | Manual BackdropFilter | Package unmaintained since Aug 2021 | Build with BackdropFilter + ClipRRect |
| Global BackdropFilter | BackdropGroup | Flutter 3.29+ (2025) | Batches multiple blur operations, 40-60% performance gain |
| Gemini 2.0 Flash | Gemini 2.5 Flash | 2.0 retired March 2026 for new users, full shutdown June 2026 | Use gemini-2.5-flash model ID |

**Deprecated/outdated:**
- `google-cloud-aiplatform` vertexai generative AI modules: removed June 2026
- `firebase_vertexai` Flutter package: renamed to `firebase_ai`
- `glassmorphism` pub.dev package: unmaintained since August 2021

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python | FastAPI backend | Yes | 3.11.4 (local) | Use 3.12 in Docker for deployment; 3.11 works for local dev |
| pip | Python package installation | Yes | 25.3 | -- |
| Docker | Cloud Run deployment | Yes | 28.4.0 | -- |
| Flutter | Mobile app | Yes (not in bash PATH) | ~3.11.4 (per pubspec) | Run via IDE or add to PATH |
| Node.js | Build tooling | Yes | 22.20.0 | -- |
| gcloud CLI | Cloud Run deployment | No | -- | Deploy via Cloud Console UI or GitHub Actions; not blocking for development |

**Missing dependencies with no fallback:**
- None -- all critical dependencies are available.

**Missing dependencies with fallback:**
- gcloud CLI: Not installed. Deployment can be done via Cloud Console web UI or CI/CD pipeline. Not needed during development.
- Flutter not in bash PATH: Available via IDE (likely Android Studio or VS Code). Not blocking for code execution.

## Open Questions

1. **Resource URL Hallucination Strategy**
   - What we know: Gemini may generate plausible-looking URLs that don't exist. The Resource Curator step is the highest hallucination risk.
   - What's unclear: Whether to validate URLs at generation time (adds latency) or post-generation (background task).
   - Recommendation: For MVP, do NOT validate URLs at generation time. Include a disclaimer "Resources are AI-suggested -- verify links before relying on them." Add URL validation as a background task in Phase 2.

2. **Razorpay Production Approval Timeline**
   - What we know: Moving from test to live Razorpay keys requires KYC documentation and review.
   - What's unclear: How long approval takes and what documents are needed.
   - Recommendation: Start the Razorpay activation process immediately -- it runs in parallel with development. Build and test with test keys; swap to live keys when approved.

3. **Vertex AI Region for Indian Users**
   - What we know: Cloud Run should be in `asia-south1` (Mumbai) for latency. Vertex AI Gemini 2.5 Flash has best availability in `us-central1`.
   - What's unclear: Whether cross-region latency (US to India) adds meaningful time per AI call.
   - Recommendation: Use `us-central1` for Vertex AI (best model availability). The 200ms cross-region overhead is negligible vs 1.5-4s per Gemini call. Can move to `asia-south1` later if Vertex AI availability improves.

4. **Admin Dashboard Analytics Data Source**
   - What we know: ADM-01 requires platform analytics (total users, active roadmaps, consultations this week).
   - What's unclear: Whether to compute live from Firestore queries or maintain aggregate counters.
   - Recommendation: Live Firestore queries for MVP (user counts are small). Add aggregate counters if query performance becomes an issue at scale.

5. **Python 3.11 vs 3.12 Locally**
   - What we know: Local machine has Python 3.11.4. FastAPI 0.135.3 works with 3.10+. Docker will use 3.12.
   - What's unclear: Whether any dependency requires 3.12+.
   - Recommendation: Develop locally on Python 3.11 (confirmed compatible). Deploy in Docker with Python 3.12-slim. No dependency requires 3.12+.

## Suggested Build Order

Based on dependency analysis and risk assessment:

### Layer 1: Backend Foundation (everything depends on this)
1. FastAPI project scaffold (main.py, config.py, Dockerfile, requirements.txt, health endpoint)
2. Firebase Admin SDK initialization, verify Firestore connectivity
3. Auth dependency (get_current_user), test with real Firebase ID token
4. Flutter ApiClient service added to AppServices (9th service)

### Layer 2: AI Prompt Chain (highest iteration risk, longest lead time)
5. Goal Analyzer step with Pydantic schema + Gemini structured output
6. Full 4-step chain orchestrator
7. Firestore roadmap write (populate BOTH legacy + new fields)
8. Replace AiRoadmapService in Flutter with ApiClient calls

### Layer 3: UI Overhaul (parallelizable with Layer 2 after foundation)
9. Theme system (light/dark, glassmorphism color tokens)
10. GlassCard component library + gradient backgrounds
11. Onboarding wizard (AiGuidanceScreen refactor into multi-step)
12. AI progress storytelling indicator
13. Roadmap timeline visualization
14. Expert marketplace filters
15. Skeleton loaders + error/empty states across all screens
16. Micro-interactions with flutter_animate

### Layer 4: Payment Hardening + Security
17. Razorpay order creation endpoint
18. Payment verification endpoint
19. Webhook handler with idempotent processing
20. Flutter payment flow update
21. Firebase security rules for all collections
22. Input sanitization on AI endpoints
23. Admin dashboard analytics

### Dependency Graph
```
Layer 1 (foundation) is prerequisite for everything
    |
    +---> Layer 2 (AI chain)
    |        |
    |        +---> Layer 2.5 (Flutter AI integration)
    |
    +---> Layer 3 (UI overhaul) -- parallelizable after Layer 1
    |
    +---> Layer 4 (payments + security) -- parallelizable after Layer 1
```

Layers 2, 3, and 4 can be developed in parallel once Layer 1 is complete, but Layer 2 should be prioritized because it carries the highest iteration risk (prompt tuning).

## Firestore Collection Access Matrix

| Collection | Flutter Reads | Flutter Writes | FastAPI Reads | FastAPI Writes |
|------------|--------------|----------------|---------------|----------------|
| `users` | Own doc (stream) | Own profile fields | By uid (chain context) | Learner memory metadata |
| `experts` | All verified (stream) | Never | By expertId | Never |
| `consultations` | Own bookings (stream) | Create, cancel | By consultationId | Status, payment records, order_id |
| `roadmaps` | Own roadmaps (stream) | Progress updates ONLY | By userId | Full CRUD (AI-generated) |
| `reviews` | By expert (stream) | Create review | Never | Never |
| `learner_memory` (NEW) | Never | Never | By userId | Write after analysis |

## Sources

### Primary (HIGH confidence)
- [google-genai 1.70.0 - PyPI](https://pypi.org/project/google-genai/) - SDK version, API surface
- [Vertex AI Gemini 2.5 Flash docs](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash) - Model capabilities, pricing
- [Structured Output with Vertex AI](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output) - response_schema pattern
- [Razorpay Python SDK integration](https://razorpay.com/docs/payments/server-integration/python/integration-steps/) - Order creation, verification
- [FastAPI 0.135.3 docs](https://fastapi.tiangolo.com/) - Framework patterns
- [flutter_animate 4.5.2 - pub.dev](https://pub.dev/packages/flutter_animate) - Animation API
- [Firebase Security Rules docs](https://firebase.google.com/docs/firestore/security/get-started) - Rules syntax

### Secondary (MEDIUM confidence)
- [BackdropFilter performance - Flutter GitHub #161297](https://github.com/flutter/flutter/issues/161297) - Impeller blur issues
- [Gemini structured output failures - Google AI Forum](https://discuss.ai.google.dev/t/2-5-flash-stopped-delivering-true-json-structures/100175) - JSON reliability issues
- [FastAPI + Firebase Admin SDK patterns](https://github.com/fastapi/fastapi/discussions/6962) - Community patterns
- [Razorpay webhook best practices](https://razorpay.com/docs/webhooks/best-practices/) - Idempotency patterns

### Tertiary (LOW confidence)
- Razorpay production activation timeline and KYC requirements -- needs direct verification with Razorpay support

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All versions verified against PyPI/pub.dev on 2026-04-07, documented in STACK.md
- Architecture: HIGH - Pattern validated against existing codebase (14 screens, 8 services, AppServices InheritedWidget)
- AI prompt chain: HIGH for SDK/structure, MEDIUM for prompt quality (requires iteration with real data)
- Payment hardening: HIGH - Razorpay SDK well-documented, patterns clear
- UI overhaul: HIGH for patterns, MEDIUM for performance (BackdropFilter on budget devices needs profiling)
- Pitfalls: HIGH - Verified across GitHub issues, official docs, community reports

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (stable stack, 30-day validity)
