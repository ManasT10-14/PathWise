# Architecture Patterns

**Domain:** FastAPI + Vertex AI backend integration with existing Flutter + Firebase app
**Researched:** 2026-04-07

---

## Recommended Architecture

### High-Level System Overview

```
+-------------------+       HTTPS + Firebase ID Token       +-------------------+
|                   |  -----------------------------------> |                   |
|   Flutter App     |                                       |   FastAPI Backend  |
|   (Android)       |  <----------------------------------- |   (Cloud Run)      |
|                   |       JSON responses                  |                   |
+-------------------+                                       +-------------------+
        |                                                           |       |
        |  Firestore SDK                              Firebase      |       |  google-genai
        |  (client-side)                              Admin SDK     |       |  SDK
        v                                                  v       |       v
+-------------------+                               +------+-------+  +-----------+
|                   |                                |              |  |           |
|   Firebase Auth   |                                |  Firestore   |  | Vertex AI |
|   (Google SSO)    |                                |  (shared)    |  | Gemini    |
|                   |                                |              |  | 2.5 Flash |
+-------------------+                                +--------------+  +-----------+
                                                            ^
                                                            |
                                                     +------+-------+
                                                     |              |
                                                     |   Razorpay   |
                                                     |   Webhooks   |
                                                     +--------------+
```

The architecture adds a FastAPI backend as a **mediation layer** between the Flutter app and AI/payment services. The Flutter app continues to read Firestore directly for real-time UI updates (via StreamBuilder), while all writes that involve AI processing or payment verification flow through FastAPI. This is the "thin backend, shared database" pattern -- the backend owns business logic but the client retains direct read access for responsiveness.

### Why This Shape

1. **Flutter keeps direct Firestore reads.** The existing StreamBuilder pattern across 14 screens works. Routing all reads through REST would add latency, break real-time updates, and require rewriting every screen. The `RoadmapRepository.watchForUser()`, `ExpertRepository`, and `ConsultationRepository` all use `snapshots()` streams that must remain intact.

2. **FastAPI owns all AI and payment writes.** The backend creates roadmaps (after AI processing) and payment orders (before Razorpay checkout). This ensures AI prompt chains run server-side (where secrets live) and payment verification is tamper-proof.

3. **Shared Firestore via Firebase Admin SDK.** Both Flutter (client SDK) and FastAPI (Admin SDK) read/write the same Firestore instance (`pathwise-aedc5`). No data synchronization layer needed. Admin SDK bypasses security rules, so FastAPI writes are unconstrained -- security rules protect client-side access only.

4. **Firebase Auth as the single identity source.** Flutter signs in via Google SSO, gets a Firebase ID token, and sends it as a Bearer token to FastAPI. FastAPI verifies the token using `firebase_admin.auth.verify_id_token()`. No separate auth system needed.

---

## Component Boundaries

| Component | Responsibility | Reads From | Writes To | Communicates With |
|-----------|---------------|------------|-----------|-------------------|
| **Flutter App** | UI rendering, user input, real-time data display, progress updates, Razorpay checkout | Firestore (client SDK) | Firestore (progress updates, consultation bookings, reviews) | FastAPI (HTTP), Firebase Auth |
| **FastAPI Backend** | AI prompt chain orchestration, payment order creation, payment verification, webhook handling, replanning | Firestore (Admin SDK) | Firestore (roadmaps, payment records, learner memory, replan logs) | Vertex AI Gemini, Razorpay API |
| **Firestore** | Persistent storage for all domain data (5 existing + 2 new collections) | -- | -- | Flutter (client SDK), FastAPI (Admin SDK) |
| **Firebase Auth** | Identity management, ID token issuance | -- | -- | Flutter (sign-in), FastAPI (token verification) |
| **Vertex AI Gemini 2.5 Flash** | Career analysis, roadmap generation, replanning inference | -- | -- | FastAPI only (never called from client) |
| **Razorpay** | Payment processing, webhook delivery | -- | -- | Flutter (checkout UI), FastAPI (order creation, verification, webhooks) |

### Boundary Rules

- **Flutter NEVER calls Vertex AI directly.** All AI requests go through FastAPI. This protects credentials, controls costs, and enables server-side prompt management. On Cloud Run, the service account has the `Vertex AI User` IAM role -- no API keys in code.
- **Flutter NEVER creates Razorpay orders.** Orders are created server-side with amount verification. Flutter receives the `order_id` and opens the checkout.
- **FastAPI NEVER serves real-time streams.** Real-time UI updates remain Firestore StreamBuilder. FastAPI handles request-response operations only.
- **Firestore security rules ONLY constrain the Flutter client SDK.** The Admin SDK bypasses rules. Write rules for the client, not the backend.

---

## Data Flow

### Flow 1: AI Roadmap Generation (Primary Flow)

This is the most important flow. It replaces the current synchronous `AiRoadmapService.analyze()` call (line 88 of `ai_guidance_screen.dart`) with an HTTP call to FastAPI.

```
Flutter AiGuidanceScreen._generate()
  |
  |  Current code (to be replaced):
  |    final analysis = svc.ai.analyze(resumeText:, userSkills:, interests:, careerGoals:);
  |    final id = await svc.roadmaps.createFromAnalysis(...);
  |
  |  New code:
  |    final result = await svc.api.post('/api/v1/roadmaps/generate', {
  |      'resume_text': resume,
  |      'skills': [..._skills, ...widget.appUser.skills],
  |      'interests': [..._interests, ...widget.appUser.interests],
  |      'career_goals': goals.isEmpty ? widget.appUser.careerGoals : goals,
  |    });
  |    final roadmapId = result['roadmap_id'];
  |
  v
FastAPI POST /api/v1/roadmaps/generate
  |
  |  1. verify_id_token(token) -> uid
  |  2. Fetch user profile from Firestore (Admin SDK) for enrichment
  |
  |  3. PROMPT CHAIN (sequential, not parallel):
  |
  |     Step 1: Goal Analyzer
  |     Input:  raw user input + user profile
  |     Output: GoalAnalysis { target_role, career_direction, constraints, timeframe }
  |     Config: gemini-2.5-flash, response_mime_type="application/json",
  |             response_schema=GoalAnalysis (Pydantic model)
  |
  |         |  GoalAnalysis feeds into...
  |         v
  |     Step 2: Skill Gap Analyzer
  |     Input:  GoalAnalysis + extracted_skills + resume_text + learner_memory
  |     Output: SkillGapAnalysis { gaps[]{skill, priority, current_level,
  |             required_level, prerequisites[], confidence} }
  |
  |         |  SkillGapAnalysis feeds into...
  |         v
  |     Step 3: Roadmap Planner
  |     Input:  GoalAnalysis + SkillGapAnalysis + user constraints
  |     Output: RoadmapPlan { phases[]{title, duration, skills[],
  |             tasks[], milestones[], weekly_hours} }
  |
  |         |  RoadmapPlan feeds into...
  |         v
  |     Step 4: Resource Curator
  |     Input:  RoadmapPlan + target_role
  |     Output: CuratedResources { phases[]{resources[]{title, url,
  |             type, difficulty, estimated_hours}} }
  |
  |  4. Merge chain outputs into Roadmap Firestore document
  |     - Populate BOTH legacy fields (milestones[], resources[], timeline)
  |       and new fields (phases[], curatedResources[], goalAnalysis)
  |     - This ensures existing RoadmapDetailScreen still works
  |  5. Write Roadmap to Firestore (Admin SDK) via roadmaps collection
  |  6. Write LearnerMemory snapshot to learner_memory collection
  |
  v
FastAPI returns { roadmap_id: "abc123", summary: "..." }
  |
  v
Flutter navigates to RoadmapDetailScreen(roadmapId: "abc123")
  |
  |  Existing StreamBuilder in RoadmapDetailScreen picks up the new
  |  roadmap document via RoadmapRepository.watchForUser() -- no changes needed
  v
UI renders the roadmap using Roadmap.structuredStages getter
```

**Critical compatibility note:** The existing `Roadmap.fromFirestore()` factory (line 62 of `roadmap.dart`) uses null-safe patterns: `m['field']?.toString() ?? ''` and safe list parsing. New fields added by FastAPI will be silently ignored by old app versions. The `structuredStages` getter parses the `milestones[]` array, so FastAPI must populate `milestones[]` even though it also writes the richer `phases[]` structure.

### Flow 2: Payment (Server-Verified)

Replaces the current client-only flow in `ConsultationDetailScreen` (line 69-93 of `consultation_detail_screen.dart`) where the client calls `svc.payments.payConsultation()` directly.

```
Flutter ConsultationDetailScreen
  |
  |  1. User taps "Pay"
  |     Flutter calls FastAPI instead of opening Razorpay directly
  |
  v
FastAPI POST /api/v1/payments/create-order
  |  Input:  { consultation_id }
  |  2. verify_id_token -> uid
  |  3. Fetch consultation from Firestore, verify:
  |     - consultation.userId == uid (ownership check)
  |     - consultation.status == "pending"
  |  4. Read price from consultation document (NOT from client request)
  |     This prevents amount tampering
  |  5. razorpay_client.order.create({
  |       amount: consultation.price * 100,  // paise
  |       currency: "INR",
  |       receipt: consultation_id
  |     })
  |  6. Store order_id in consultation document
  |
  v
Returns { order_id: "order_xxx", amount: 150000, key_id: "rzp_live_xxx" }
  |
  v
Flutter opens Razorpay checkout with order_id
  |  Uses existing PaymentService._razorpay.open() mechanism
  |  But with server-provided order_id instead of client-side amount
  |
  |  On success: razorpay_payment_id, razorpay_order_id, razorpay_signature
  |
  v
FastAPI POST /api/v1/payments/verify
  |  7. Verify HMAC-SHA256 signature:
  |     expected = HMAC-SHA256(order_id|payment_id, key_secret)
  |     Razorpay Python SDK: client.utility.verify_payment_signature({
  |       razorpay_order_id, razorpay_payment_id, razorpay_signature
  |     })
  |  8. Update consultation status to "accepted" in Firestore
  |  9. Record payment_id and verification timestamp
  |
  v
Flutter StreamBuilder picks up status change -> UI updates automatically

PARALLEL WEBHOOK PATH (backup):
  Razorpay -> POST /api/v1/webhooks/razorpay
  |  Verify webhook signature via HMAC-SHA256 with webhook secret
  |  If payment.captured -> ensure consultation status = "accepted"
  |  If payment.failed -> mark consultation as "payment_failed"
  |  Idempotent: check if already processed before updating
```

### Flow 3: Replanning

```
Option A: Client-triggered (build first -- simpler)
  Flutter detects stale progress
    (stageProgress values unchanged for > 14 days)
    |
    v
  FastAPI POST /api/v1/roadmaps/{id}/replan
    |  1. Fetch current roadmap from Firestore
    |  2. Fetch learner_memory for this user
    |  3. Run 2-step replan chain:
    |     Step A: Stall Analyzer -- why is the learner stuck?
    |     Step B: Replan Generator -- adjust milestones, swap resources
    |  4. Update roadmap document with new milestones/resources
    |  5. Write replan_reason and increment replan_count
    |  6. Log to replan_logs collection
    |
    v
  Flutter StreamBuilder picks up updated roadmap

Option B: Server-triggered (build later)
  Cloud Scheduler -> POST /api/v1/internal/check-stale (daily CRON)
    |  Query roadmaps where updatedAt > 14 days ago
    |  AND any stageProgress value < 0.5
    |  Batch trigger replans for matching roadmaps
```

---

## Shared Firestore Access Model

### The Dual-Access Pattern

```
Flutter Client SDK                    FastAPI Admin SDK
  |                                     |
  |  security rules ENFORCED            |  security rules BYPASSED
  |  user can only read/write own data  |  full read/write access
  |  real-time snapshots()              |  single document get/set
  |                                     |
  v                                     v
              SAME Firestore Instance
              (project: pathwise-aedc5)
```

### Collection Access Matrix

| Collection | Flutter Reads | Flutter Writes | FastAPI Reads | FastAPI Writes |
|------------|--------------|----------------|---------------|----------------|
| `users` | Own doc via stream | Own profile fields | By uid (for chain context) | Learner memory metadata |
| `experts` | All verified via stream | Never | By expertId (for consultation context) | Never |
| `consultations` | Own bookings via stream | Create booking, cancel | By consultationId (for payment verification) | Status updates, payment records, order_id |
| `roadmaps` | Own roadmaps via stream | Progress slider updates (`updateProgress()`) | By userId (for replanning context) | Full CRUD (AI-generated roadmaps, replans) |
| `reviews` | By expert via stream | Create review (with batch rating update) | Never | Never |
| `learner_memory` (NEW) | Never | Never | By userId | Write after each analysis/replan |
| `replan_logs` (NEW) | Never (or admin read) | Never | By roadmapId | Write after each replan |

### Firestore Document Evolution

The existing `Roadmap` document schema must be extended without breaking existing code. The `Roadmap.fromFirestore()` factory already handles unknown fields gracefully.

```
roadmaps/{docId}
  // EXISTING FIELDS (keep exactly as-is)
  roadmapId: string
  userId: string
  targetRole: string
  milestones: string[]              // FastAPI MUST populate this for backward compat
  resources: string[]               // FastAPI MUST populate this for backward compat
  timeline: string
  stageProgress: { beginner: 0, intermediate: 0, advanced: 0 }
  createdAt: timestamp
  updatedAt: timestamp

  // NEW FIELDS (written by FastAPI, ignored by existing Flutter code)
  source: "ai_v1" | "local_stub"
  goalAnalysis: {                   // Step 1 output
    targetRole: string,
    careerDirection: string,
    constraints: string[],
    timeframeMonths: number,
    confidence: number
  }
  skillGaps: [{                     // Step 2 output
    skill: string,
    priority: string,
    currentLevel: string,
    requiredLevel: string,
    prerequisites: string[],
    confidence: number
  }]
  phases: [{                        // Step 3 output (richer than milestones[])
    title: string,
    durationWeeks: number,
    skills: string[],
    tasks: string[],
    weeklyHours: number
  }]
  curatedResources: [{              // Step 4 output (richer than resources[])
    title: string,
    url: string,
    type: string,
    difficulty: string,
    estimatedHours: number,
    phase: string
  }]
  replanCount: number
  lastReplanAt: timestamp
  replanReason: string
```

**New collection: `learner_memory/{userId}`**

```
learner_memory/{userId}
  userId: string
  analysisHistory: [{               // Append after each analysis
    timestamp: timestamp,
    targetRole: string,
    skillGapCount: number,
    gapSummary: string[]
  }]
  strugglePatterns: [{              // Updated by replan engine
    skill: string,
    stallCount: number,
    lastStallAt: timestamp
  }]
  paceTrend: string                 // "accelerating" | "steady" | "slowing"
  totalReplans: number
  lastAnalysisAt: timestamp
```

---

## FastAPI Backend Structure

```
backend/
  |-- main.py                     # FastAPI app, lifespan event, CORS middleware
  |-- config.py                   # pydantic-settings: env vars, secrets
  |-- dependencies.py             # Shared Depends(): auth, Firestore client, Gemini client
  |
  |-- routers/
  |   |-- __init__.py
  |   |-- health.py               # GET /health (Cloud Run health check)
  |   |-- roadmaps.py             # POST /api/v1/roadmaps/generate
  |   |                           # POST /api/v1/roadmaps/{id}/replan
  |   |-- payments.py             # POST /api/v1/payments/create-order
  |   |                           # POST /api/v1/payments/verify
  |   |-- webhooks.py             # POST /api/v1/webhooks/razorpay
  |
  |-- services/
  |   |-- __init__.py
  |   |-- prompt_chain.py         # Orchestrates 4-step chain, calls steps in sequence
  |   |-- goal_analyzer.py        # Step 1: prompt + GoalAnalysis schema
  |   |-- skill_gap_analyzer.py   # Step 2: prompt + SkillGapAnalysis schema
  |   |-- roadmap_planner.py      # Step 3: prompt + RoadmapPlan schema
  |   |-- resource_curator.py     # Step 4: prompt + CuratedResources schema
  |   |-- replan_engine.py        # 2-step replan chain
  |   |-- learner_memory.py       # CRUD for learner_memory collection
  |   |-- payment_service.py      # Razorpay client wrapper
  |
  |-- models/
  |   |-- __init__.py
  |   |-- requests.py             # Pydantic: API request bodies
  |   |-- responses.py            # Pydantic: API response bodies
  |   |-- ai_schemas.py           # Pydantic: Gemini response_schema models
  |   |                           # (GoalAnalysis, SkillGapAnalysis, RoadmapPlan, etc.)
  |   |-- firestore_models.py     # Pydantic/TypedDict: Firestore document shapes
  |
  |-- prompts/
  |   |-- goal_analyzer.txt       # System prompt for step 1
  |   |-- skill_gap_analyzer.txt  # System prompt for step 2
  |   |-- roadmap_planner.txt     # System prompt for step 3
  |   |-- resource_curator.txt    # System prompt for step 4
  |   |-- replan_analyzer.txt     # System prompt for replan step A
  |   |-- replan_generator.txt    # System prompt for replan step B
  |
  |-- Dockerfile
  |-- requirements.txt
  |-- .env.example
```

**Why this structure:**
- **Routers are thin** -- validate input, call services, return response. No business logic in routers.
- **Each chain step is its own module** because prompts are the most-iterated artifact. Isolating them makes prompt tuning independent of orchestration logic.
- **Prompts are `.txt` files**, not embedded in Python strings. Prompt engineers (or the developer iterating) can edit prompts without touching service code.
- **`ai_schemas.py` models serve triple duty**: (1) Gemini `response_schema`, (2) FastAPI response models, (3) internal contracts between chain steps.
- **API versioning via `/api/v1/`** so the Flutter app can pin to a version. Breaking changes go to `/api/v2/` without breaking live users.

---

## Authentication Flow

### Flutter Side: New ApiClient Service

Add a new `ApiClient` service to `AppServices` (the existing InheritedWidget at `lib/providers/app_services.dart`). This is the 9th service, alongside the existing 8.

```dart
// New: lib/services/api_client.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'ApiException($statusCode): $body';
}
```

**Note on `http` vs `dio`:** The existing app uses `package:http` (zero external HTTP dependencies currently). For MVP, stick with `http`. Add `dio` with interceptors (retry, logging) only if needed later. Do not add framework weight prematurely.

### FastAPI Side: Dependency Injection

```python
# dependencies.py
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin.auth

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    """Verify Firebase ID token, return decoded claims (uid, email, etc.)."""
    try:
        decoded = firebase_admin.auth.verify_id_token(credentials.credentials)
        return decoded
    except firebase_admin.auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except firebase_admin.auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")

# Usage in any router:
@router.post("/generate")
async def generate_roadmap(
    request: RoadmapRequest,
    user: dict = Depends(get_current_user),
):
    uid = user["uid"]
    # ...
```

---

## 4-Step Prompt Chain Architecture

### Why Sequential, Not Parallel

Each step's output is a required input to the next. Goal Analysis informs Skill Gap Analysis (what role are we analyzing gaps for?), which informs Roadmap Planning (what gaps need to be closed?), which informs Resource Curation (what topics need resources?). Parallelization is structurally impossible.

### Why Not LangChain/LangGraph

Per project constraints: "No LangGraph or other frameworks." The chain is 4 sequential `generate_content()` calls with Pydantic schemas. LangChain would add 15+ transitive dependencies for what is literally 4 function calls in sequence. Direct SDK usage is simpler, more debuggable, and avoids version-coupling risk with a fast-moving framework.

### SDK Choice: google-genai (NOT vertexai)

The `vertexai` package's generative AI modules were deprecated June 2025 and will be removed June 2026. Use the `google-genai` package instead, which unifies Vertex AI and Google AI access. For Vertex AI: set `vertexai=True` when creating the client.

### Structured Output Pattern

```python
from google import genai
from google.genai.types import HttpOptions
from pydantic import BaseModel, Field

# Initialize once at app startup (lifespan)
client = genai.Client(
    vertexai=True,
    project="pathwise-aedc5",
    location="us-central1",
    http_options=HttpOptions(api_version="v1"),
)

MODEL = "gemini-2.5-flash"

class GoalAnalysis(BaseModel):
    target_role: str = Field(description="Inferred target career role")
    career_direction: str = Field(description="Broader career trajectory")
    constraints: list[str] = Field(description="Time, resource, or skill constraints")
    timeframe_months: int = Field(description="Estimated months to reach target")
    confidence: float = Field(ge=0, le=1, description="Confidence in this analysis")

async def analyze_goal(user_input: dict) -> GoalAnalysis:
    prompt = load_prompt("goal_analyzer.txt").format(
        resume_text=user_input["resume_text"],
        skills=", ".join(user_input["skills"]),
        interests=", ".join(user_input["interests"]),
        career_goals=user_input["career_goals"],
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": GoalAnalysis,
        },
    )
    return GoalAnalysis.model_validate_json(response.text)
```

### Chain Orchestrator

```python
# services/prompt_chain.py
async def run_career_analysis_chain(user_input: dict, learner_memory: dict | None) -> dict:
    """Execute the 4-step prompt chain. Returns merged roadmap data."""

    # Step 1: What role is the user aiming for?
    goal = await analyze_goal(user_input)

    # Step 2: What skills are they missing?
    gaps = await analyze_skill_gaps(goal, user_input, learner_memory)

    # Step 3: What's the learning plan?
    plan = await plan_roadmap(goal, gaps, user_input)

    # Step 4: What specific resources should they use?
    resources = await curate_resources(plan, goal)

    return merge_into_roadmap_document(goal, gaps, plan, resources)
```

### Latency Budget

Each Gemini 2.5 Flash call with structured output takes approximately 1.5-4 seconds. A 4-step chain totals 6-16 seconds. This is acceptable for a "generate my roadmap" action (users expect to wait for AI analysis) but would be unacceptable for page loads.

**Flutter UX implication:** The `AiGuidanceScreen` already shows a `CircularProgressIndicator` during generation (line 206). Enhance this with step-by-step labels: "Analyzing your goals...", "Identifying skill gaps...", "Planning your roadmap...", "Finding resources..." either via polling or SSE. For MVP, a single spinner with "Generating your personalized roadmap (this takes ~10 seconds)..." is sufficient.

**Optimization for later:** If latency becomes a problem, Steps 3 and 4 (Roadmap Planner + Resource Curator) could be merged into a single prompt. Do not pre-optimize.

---

## Deployment Architecture

### Recommended: Google Cloud Run

```
Cloud Run Service: pathwise-api
  |-- Region: asia-south1 (Mumbai -- close to Indian users)
  |-- Min instances: 0 (scale to zero, saves cost during development)
  |-- Max instances: 5 (cost control for MVP)
  |-- Memory: 512 MB (no ML inference, just HTTP + SDK calls)
  |-- CPU: 1 vCPU
  |-- Request timeout: 60s (prompt chain can take 20s, add buffer)
  |-- Concurrency: 80 (FastAPI async handles concurrent requests efficiently)
  |
  |-- Environment Variables:
  |     GCP_PROJECT_ID=pathwise-aedc5
  |     GCP_LOCATION=us-central1         (Vertex AI region -- best model availability)
  |     RAZORPAY_KEY_ID=rzp_live_xxx
  |     RAZORPAY_KEY_SECRET=xxx          (via Secret Manager, not plain env var)
  |     RAZORPAY_WEBHOOK_SECRET=xxx      (via Secret Manager)
  |
  |-- Service Account: pathwise-api@pathwise-aedc5.iam.gserviceaccount.com
  |     IAM Roles:
  |       - roles/aiplatform.user           (Vertex AI Gemini API calls)
  |       - roles/datastore.user            (Firestore read/write via Admin SDK)
  |       - roles/secretmanager.secretAccessor (if using Secret Manager)
```

### Why Cloud Run Over Alternatives

| Option | Why Not |
|--------|---------|
| **Cloud Functions** | 9-minute timeout; prompt chain with retries can exceed this; worse cold starts |
| **Firebase Cloud Functions** | Python support is limited; would fragment the backend into Node.js |
| **GKE / GCE** | Overkill for MVP; always-on costs; operational burden |
| **App Engine** | Less scaling control; legacy deployment model |

Cloud Run is the officially recommended target for FastAPI + Vertex AI on Google Cloud. It gives Docker-based deployment, scale-to-zero, proper timeout support (60s), and seamless Vertex AI IAM integration through service accounts.

### Region Strategy

Vertex AI Gemini 2.5 Flash has the best availability in `us-central1`. The Cloud Run service runs in `asia-south1` (Mumbai, latency-optimized for Indian users). Cross-region API calls add approximately 200ms, which is negligible compared to the 2-4 second Gemini inference time per step.

---

## Patterns to Follow

### Pattern 1: Firebase ID Token as API Gateway Auth

**What:** Every FastAPI request carries a Firebase ID token in the `Authorization: Bearer` header. A shared `Depends(get_current_user)` dependency verifies it.

**When:** Every authenticated endpoint.

**Why:** Single auth system. No separate JWT infrastructure. The Flutter app already has Firebase Auth. Token verification is one `verify_id_token()` call.

### Pattern 2: Pydantic Models as Contracts

**What:** Define Pydantic models that serve as (a) Gemini `response_schema` for structured output, (b) FastAPI response models for API docs, and (c) internal contracts between chain steps.

**When:** Every AI chain step, every API endpoint.

**Why:** Type safety across the entire pipeline. Gemini's structured output guarantees the response matches the schema. FastAPI validates input/output automatically. Single source of truth for data shapes. Changes propagate to all three uses.

### Pattern 3: Prompt-as-File with Variable Injection

**What:** Store system prompts as `.txt` files with `{variable}` placeholders. Load at startup, format at runtime.

**When:** All prompt chain steps.

**Why:** Prompts need frequent iteration. Separating prompt content from Python orchestration logic makes both easier to maintain. Prompt changes do not require code review of business logic.

### Pattern 4: Idempotent Payment Processing

**What:** Payment verification and webhook handling are idempotent. Processing the same payment twice produces no additional side effects.

**When:** Both the `/verify` endpoint and `/webhooks/razorpay` handler.

**Why:** Webhooks can be delivered multiple times. The client might retry on network failure. Check consultation status before updating: if already `accepted`, return success without modifying.

### Pattern 5: Progressive Schema Extension

**What:** Add new fields to Firestore documents without removing or renaming existing fields.

**When:** Every Firestore schema change.

**Why:** Flutter and FastAPI share the same Firestore. The Flutter app might be on an older version when FastAPI deploys new fields. The existing `fromFirestore` factories use null-safe patterns (`m['field']?.toString() ?? ''`) that tolerate unknown/missing fields.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Routing All Firestore Reads Through FastAPI

**What:** Making the Flutter app call FastAPI to fetch roadmaps, experts, consultations.

**Why bad:** Breaks real-time updates via StreamBuilder. Adds latency. Requires rewriting 14 screens. The `RoadmapRepository.watchForUser()`, `ConsultationRepository`, and all existing stream-based screens would need to be replaced with polling or SSE.

**Instead:** Flutter reads Firestore directly (existing pattern). FastAPI writes to Firestore. Flutter StreamBuilders pick up changes automatically.

### Anti-Pattern 2: Storing Vertex AI Credentials in the Flutter APK

**What:** Calling Vertex AI directly from the Flutter client.

**Why bad:** API keys in mobile APKs are trivially extractable via `apktool`. No rate limiting. No cost control. No prompt management. Users could manipulate prompts.

**Instead:** All AI calls go through FastAPI. On Cloud Run, the service account has the `Vertex AI User` IAM role -- no API keys exist in code at all.

### Anti-Pattern 3: Client-Side Payment Amount Determination

**What:** Trusting the Flutter app to send the correct payment amount.

**Why bad:** The current code (line 74 of `consultation_detail_screen.dart`) reads `c.price` from the Firestore document and passes it to Razorpay. A compromised client could send a modified amount. Server-side order creation eliminates this vector.

**Instead:** FastAPI reads the consultation price from Firestore and creates the Razorpay order with the server-verified amount.

### Anti-Pattern 4: Monolithic Single-Prompt AI Call

**What:** One massive prompt that asks Gemini to do goal analysis, skill gaps, roadmap, and resources simultaneously.

**Why bad:** Harder to debug (which part hallucinated?). Harder to iterate prompts independently. Higher risk of output quality degradation with complex instructions. Cannot retry a single failed step.

**Instead:** Sequential chain with structured output at each step. Each step produces a validated Pydantic model.

### Anti-Pattern 5: Synchronous Firebase Admin SDK in Async Handlers

**What:** Using synchronous `firebase_admin` Firestore operations directly in `async def` route handlers.

**Why bad:** `firebase_admin` uses synchronous HTTP. In an `async def` handler, this blocks the event loop, preventing other requests from being served.

**Instead:** Wrap in `asyncio.to_thread()`:
```python
doc = await asyncio.to_thread(db.collection("users").document(uid).get)
```
Or declare route handlers as `def` (not `async def`) -- FastAPI runs them in a threadpool automatically. For MVP, `def` handlers are simpler and sufficient.

---

## Suggested Build Order (Dependency-Driven)

Build order is driven by what depends on what. Each layer can be deployed and tested independently.

### Layer 1: Foundation (everything depends on this)

1. **FastAPI project scaffold** -- `main.py`, `config.py`, Dockerfile, requirements.txt, health endpoint
2. **Firebase Admin SDK initialization** -- `core/firebase.py`, verify Firestore connectivity
3. **Auth dependency** -- `dependencies.py` with `get_current_user`, test with a real Firebase ID token from the Flutter app
4. **Flutter ApiClient service** -- new service added to `AppServices` InheritedWidget (9th service), basic connectivity test

**Why first:** Every subsequent feature needs auth and database access. If these fail, nothing else works.

**Testable milestone:** Flutter app can call `GET /health` on the deployed Cloud Run service. An authenticated `POST` returns the user's uid.

### Layer 2: AI Chain (core product value, longest iteration cycle)

5. **Single-step proof of concept** -- Goal Analyzer only, with Pydantic schema and Gemini structured output. Verify the `google-genai` SDK works on Cloud Run.
6. **Full 4-step chain** -- add remaining 3 steps, wire the `prompt_chain.py` orchestrator
7. **Roadmap write to Firestore** -- merge chain output into Roadmap document format (including legacy `milestones[]` and `resources[]` fields). Verify the existing Flutter `RoadmapDetailScreen` StreamBuilder picks it up.
8. **Replace AiRoadmapService in Flutter** -- change `AiGuidanceScreen._generate()` from calling `svc.ai.analyze()` to calling `svc.api.post('/api/v1/roadmaps/generate', ...)`. The local `AiRoadmapService` becomes a fallback for offline mode.

**Why second:** This is the core product differentiator. Prompts will need extensive iteration and testing. Starting early gives maximum time for tuning.

**Testable milestone:** User submits career goal in Flutter, waits 10 seconds, sees AI-generated roadmap in `RoadmapDetailScreen`.

### Layer 3: Payment Hardening

9. **Razorpay order creation endpoint** -- `POST /api/v1/payments/create-order`
10. **Payment verification endpoint** -- `POST /api/v1/payments/verify` with signature check
11. **Webhook handler** -- `POST /api/v1/webhooks/razorpay` with idempotent processing
12. **Flutter payment flow update** -- modify `ConsultationDetailScreen` to create order via FastAPI before opening Razorpay checkout. Keep the existing `PaymentService` for the checkout UI, but feed it the server-created `order_id`.

**Why third:** Payment works today (client-side). Hardening is important for production but does not block the AI feature.

**Testable milestone:** End-to-end payment in Razorpay test mode with server-side order creation and signature verification.

### Layer 4: Intelligence Features

13. **Learner memory system** -- `learner_memory` collection, write analysis history after each chain run
14. **Replanning engine** -- `/api/v1/roadmaps/{id}/replan`, stall detection, 2-step replan chain
15. **Expert-AI feedback loop** -- expert annotation storage, annotation injection into replan prompts

**Why last:** These features require a working AI chain (Layer 2) and stored data across multiple sessions. They cannot be meaningfully developed until Layers 1-2 are solid.

### Dependency Graph

```
Layer 1: FastAPI scaffold + Firebase init + Auth + Flutter ApiClient
            |
            v
Layer 2: Goal Analyzer -> Full Chain -> Firestore Write -> Flutter Integration
            |                                     |
            v                                     v
Layer 3: Payment Create-Order -> Verify -> Webhook -> Flutter Update
            |
            v
Layer 4: Learner Memory -> Replanning -> Expert Feedback Loop
```

Layers 2 and 3 can be developed in parallel once Layer 1 is complete, but Layer 2 should be prioritized because it carries higher iteration risk (prompt tuning).

---

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| **Vertex AI costs** | Negligible (~$5/mo) | Moderate (~$200/mo); enable Vertex AI context caching | Significant; cache common role analyses, compress prompts |
| **Firestore reads** | Free tier covers it | Standard pricing, add composite indexes | Denormalize hot paths, consider read replicas |
| **Cloud Run instances** | 0-1 (scale to zero) | 2-5, increase min to 1 to avoid cold starts | Regional deployment, dedicated instances |
| **Prompt chain latency** | 6-16s, acceptable | Same per request; concurrent via Cloud Run scaling | Cache analyses for common goal patterns |
| **Payment webhooks** | Trivial | Ensure idempotency, monitor duplicate rate | Queue via Cloud Tasks, process async |

For MVP targeting Indian students/professionals: 100-user tier is realistic. Design for 10K scalability but do not engineer for 1M.

---

## Sources

- [FastAPI + Firebase Admin SDK Discussion](https://github.com/fastapi/fastapi/discussions/6962) -- community patterns for shared Firestore access (MEDIUM confidence)
- [Vertex AI Gemini 2.5 Flash Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash) -- model ID `gemini-2.5-flash`, capabilities, token limits (HIGH confidence)
- [Google Gen AI SDK Overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/sdks/overview) -- recommended SDK, replaces deprecated `vertexai` package (HIGH confidence)
- [Vertex AI SDK Migration Guide](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk) -- `vertexai` generative AI modules deprecated June 2025, removed June 2026 (HIGH confidence)
- [Structured Output with Vertex AI](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output) -- Pydantic response_schema, response_mime_type pattern (HIGH confidence)
- [Razorpay Python SDK Server Integration](https://razorpay.com/docs/payments/server-integration/python/payment-gateway/build-integration/) -- order creation, signature verification, webhook flow (HIGH confidence)
- [FastAPI Firebase Auth Pattern](https://medium.com/@gabriel.cournelle/firebase-authentication-in-the-backend-with-fastapi-4ff3d5db55ca) -- ID token verification with dependency injection (MEDIUM confidence)
- [Deploy FastAPI to Cloud Run Quickstart](https://docs.cloud.google.com/run/docs/quickstarts/build-and-deploy/deploy-python-fastapi-service) -- official Google Cloud deployment guide (HIGH confidence)
- [Building LLM Apps with FastAPI Best Practices](https://agentsarcade.com/blog/building-llm-apps-with-fastapi-best-practices) -- async patterns, layered architecture for LLM apps (MEDIUM confidence)
- [Google GenAI Python SDK GitHub](https://github.com/googleapis/python-genai) -- source, examples, API reference (HIGH confidence)
- [Razorpay Webhook Integration with FastAPI](https://www.shekharverma.com/python-integrating-payment-webhooks-with-fastapi-in-python-1/) -- practical webhook handler implementation (MEDIUM confidence)
