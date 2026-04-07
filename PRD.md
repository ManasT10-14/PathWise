# Product Requirements Document

## Pathwise — AI + Human Expert Career Guidance Platform

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Owner** | Manas |
| **Stack** | Flutter 3.x, Firebase, FastAPI, Vertex AI (Gemini 2.5 Flash) |
| **Positioning** | Adaptive career guidance through AI intelligence and human expertise |
| **Repository** | PathWise-Mobile-App |

### Revision History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-03-15 | Initial PRD with LangGraph multi-agent architecture |
| 2.0 | 2026-04-07 | Complete rewrite: Vertex AI migration, Expert Marketplace pillar, grounded in implemented codebase |

---

# 1. Executive Summary

Pathwise is a **dual-pillar career guidance platform** that combines Vertex AI-powered adaptive roadmap generation with a human expert consultation marketplace. Users define career goals, receive personalized skill-gap analysis and phased learning roadmaps powered by Gemini 2.5 Flash, track their progress, and optionally book paid consultations with verified domain experts for human-validated guidance.

### What Exists Today (v1.0 -- Implemented)

A production-ready Flutter mobile application with:

- **14 screens** across three role-based interfaces (learner, expert, admin)
- **Firebase integration**: Auth (Google Sign-In), Firestore (5 collections), real-time streaming
- **Expert Marketplace**: discovery, booking, Razorpay payment processing, review and rating system
- **Local AI stub**: keyword-based skill extraction and roadmap generation (`AiRoadmapService`), architected as a swap-ready placeholder for the Vertex AI backend
- **Service-locator architecture**: `AppServices` InheritedWidget exposing 8 services via `context.svc`

### What the Vertex AI Backend Unlocks (v1.1 -- Planned)

- Gemini 2.5 Flash-powered skill gap analysis with prerequisite reasoning
- Personalized multi-phase roadmap generation with real resource curation
- Progress-aware dynamic replanning when learners fall behind
- Long-term learner memory for pattern detection across sessions
- Expert-AI feedback loop where human annotations improve future AI recommendations

### Core Thesis

Static roadmaps fail because they cannot adapt. Mentorship alone fails because it cannot scale. Pathwise sits at the intersection: **AI generates and adapts the plan; experts validate and refine it; the system learns from both.**

---

# 2. Product Vision

> Transform "I want to become X" into "Here is your evolving, expert-validated path to X, adapting to your pace, strengths, and constraints in real time."

Pathwise should feel like a **career strategist** (understands market demands), a **learning architect** (sequences knowledge optimally), and an **accountability coach** (detects drift and corrects course) -- augmented by **human experts** who bring domain nuance that AI alone cannot replicate.

### Competitive Landscape

| Platform | Strength | Weakness | Pathwise Advantage |
|---|---|---|---|
| **Coursera / Udemy** | Massive course catalog | Static paths, no personalization, no adaptation | AI-personalized roadmaps that evolve with learner progress |
| **roadmap.sh** | Clean visual roadmaps | One-size-fits-all, no progress tracking, no AI | Gap analysis against user's actual skills, adaptive replanning |
| **ADPList** | Human mentorship | No AI, no structured roadmaps, no payments | AI + Expert hybrid with integrated booking and payment |
| **LinkedIn Learning** | Professional content | Generic recommendations, no skill gap reasoning | Prerequisite-aware sequencing based on resume analysis |
| **ChatGPT / Gemini** | General-purpose AI | No state, no memory, no progress tracking, no experts | Persistent learner profiles, closed-loop tracking, expert marketplace |

Pathwise occupies a **unique intersection** that no existing platform covers: AI-driven adaptive planning with integrated human expert validation and monetized consultation.

---

# 3. Problem Statement

### The Unguided Learner

Students and early-career professionals have career ambitions but no structured, personalized path. They learn topics in the wrong order, skip prerequisites, overestimate their readiness, lose consistency, and accumulate knowledge gaps that compound silently. Generic roadmaps provide direction but no adaptation -- when life intervenes or a topic proves harder than expected, the plan breaks and the learner drifts.

### The Time-Constrained Professional

Career switchers (e.g., backend engineer moving to GenAI) have strong foundations but specific gaps. They need the system to recognize what they already know, identify precisely what they lack, and build a compressed plan that respects their limited weekly hours. Rigid curricula waste their time on topics they have already mastered.

### The Expert Seeking Reach

Domain experts -- professors, senior engineers, industry mentors -- want to monetize their guidance but lack a platform that pairs them with pre-qualified learners and augments their sessions with AI-generated context. They spend time on intake (understanding the learner's background) that an AI system could handle automatically, and they have no tool to track whether their advice was followed.

---

# 4. User Personas

### Persona A: Riya -- The Placement-Bound Student

| Attribute | Detail |
|---|---|
| **Profile** | 3rd-year CS undergrad preparing for campus placements |
| **Goal** | ML Engineer role at a product company |
| **Time** | 2 hours/day, 6 months until placement season |
| **Current Skills** | Python, basic DSA, introductory ML course |
| **Pain Point** | Doesn't know what to learn next, overwhelmed by resource options |

**Journey**: `LoginScreen` (Google Sign-In) -> `RoleRouter` (routes as `UserRole.user`) -> `UserMainShell` (Home tab) -> `HomeModeScreen` (chooses "AI Guidance") -> `AiGuidanceScreen` (uploads resume, tags skills, sets goal) -> AI generates roadmap -> `RoadmapDetailScreen` (tracks progress via sliders) -> returns weekly to update progress -> AI detects stall on "Deep Learning" milestone -> triggers replan with easier resources

### Persona B: Arjun -- The Career Switcher

| Attribute | Detail |
|---|---|
| **Profile** | 5 years as a backend engineer, switching to GenAI |
| **Goal** | GenAI Engineer role within 8 months |
| **Time** | 10 hours/week (evenings + weekends) |
| **Current Skills** | Python, Java, system design, REST APIs, Docker |
| **Pain Point** | Strong coding skills but weak ML theory; needs targeted gap-filling, not a beginner curriculum |

**Journey**: Profile setup with resume upload -> AI recognizes Python/Docker/REST strength -> identifies gaps: ML fundamentals, transformer architecture, prompt engineering, vector databases -> generates compressed 4-phase roadmap skipping known topics -> Arjun books expert consultation to validate transition strategy -> expert annotates roadmap -> AI incorporates expert feedback into next replan

### Persona C: Dr. Priya -- The Domain Expert

| Attribute | Detail |
|---|---|
| **Profile** | AI professor at a tier-1 university, 12 years experience |
| **Goal** | Monetize mentorship, reach students beyond her institution |
| **Rate** | INR 1,500 per 30-minute session |
| **Pain Point** | Spends first 15 minutes of every session understanding the learner's background |

**Journey**: Admin creates expert profile in `AdminDashboardScreen` -> links to Dr. Priya's user account via `linkedUserId` -> `ExpertHomeScreen` shows incoming bookings -> learner profile + AI-generated roadmap attached to each booking -> Dr. Priya conducts session with full context -> learner submits review via `ReviewSubmitScreen` -> rating aggregated automatically -> Dr. Priya's profile improves in `ExpertsScreen` ranking

### Persona D: Manas -- The Platform Admin

| Attribute | Detail |
|---|---|
| **Profile** | Platform creator and operator |
| **Goal** | Maintain quality, verify experts, monitor platform health |

**Journey**: `AdminDashboardScreen` with 4 tabs -> Users tab: manage roles via `PopupMenuButton` (promote user to expert/admin) -> Experts tab: toggle verification status -> Consultations tab: monitor all bookings and statuses -> Reviews tab: moderate and delete inappropriate reviews

---

# 5. Core Product Pillars

## Pillar 1: AI-Powered Career Guidance

### 5.1 Goal Definition Wizard

Users provide their learning context through `AiGuidanceScreen`:

- **Resume upload**: plain text via `file_picker` (`.txt`, `.md` formats)
- **Skill tags**: comma-separated current skills
- **Interest areas**: free-text interests that influence role inference
- **Career goals**: target role or ambition statement

The wizard collects structured input that feeds the AI analysis pipeline.

### 5.2 Skill Gap Analysis

**Current implementation** (`lib/services/ai_roadmap_service.dart`):

The `AiRoadmapService` performs local keyword-based analysis:
- Extracts skills by matching resume text against 34 technology keywords (`_techKeywords`)
- Infers target role via pattern matching in `_inferTargetRole()` (supports: Data Analyst, ML Engineer, Mobile Engineer, Frontend, Backend, DevOps, Software Engineer)
- Computes skill gaps as the set difference between `_skillsForRole(target)` and extracted skills
- Returns an `AiAnalysis` object with: `extractedSkills`, `goalAnalysis`, `skillGaps`, `targetRole`, `milestones`, `resources`, `timeline`

**Target implementation** (Vertex AI backend):

Gemini 2.5 Flash replaces keyword matching with semantic understanding:
- Parses resume context to identify skill proficiency levels (not just presence/absence)
- Reasons about prerequisite dependencies ("You need linear algebra before deep learning")
- Estimates confidence scores per skill gap
- Generates actionable gap-closing strategies, not just gap labels

### 5.3 Adaptive Roadmap Generation

The system produces a phased learning roadmap stored as a `Roadmap` document in Firestore:

```
Roadmap
  |-- targetRole: "ML Engineer"
  |-- milestones: ["Beginner -- Foundations...", "Intermediate -- Close gaps...", "Advanced -- Ownership..."]
  |-- resources: ["https://...", ...]
  |-- timeline: "Approx. 4-8 months..."
  |-- stageProgress: { "beginner": 0.0, "intermediate": 0.0, "advanced": 0.0 }
```

The `structuredStages` getter on the `Roadmap` model transforms flat milestones into `RoadmapStage` objects with level, title, tasks, and resources -- enabling the UI to render a structured timeline view in `RoadmapDetailScreen`.

### 5.4 Progress Tracking

Learners update progress per stage using sliders (0.0 to 1.0) in `RoadmapDetailScreen`. Progress is persisted via `RoadmapRepository.updateProgress()` and synced in real time through Firestore's `StreamBuilder` pattern.

### 5.5 Dynamic Replanning (v1.1)

When progress stalls (e.g., beginner stage at 0.3 for > 2 weeks), the system triggers a replan through the FastAPI backend:

- Compresses remaining milestones into the available timeline
- Reorders topics to prioritize prerequisites the learner is struggling with
- Swaps in easier alternative resources
- Suggests a revision week before advancing
- Generates a `replan_reason` explaining the adjustment

---

## Pillar 2: Expert Consultation Marketplace

### 5.6 Expert Discovery

`ExpertsScreen` displays verified experts from the `experts` Firestore collection via `StreamBuilder`. Each expert card shows:

- Name, domain, experience level
- Rating (aggregated from reviews) and total review count
- Price per session (INR)
- Verification badge (admin-controlled)
- Skill tags

### 5.7 Expert Profiles

`ExpertDetailScreen` renders a detailed profile with:

- Full skill list and experience description
- Rating breakdown (average from `ReviewRepository`)
- Price per session
- Booking action button

Experts are linked to user accounts via `linkedUserId` or email matching through `ExpertRepository.findExpertForUser()`, enabling a single authentication flow for both roles.

### 5.8 Consultation Booking

`BookConsultationScreen` captures:

| Field | Input | Stored As |
|---|---|---|
| Session type | `SegmentedButton` (chat / audio / video) | `Consultation.type` |
| Date and time | `showDatePicker` + `showTimePicker` | `Consultation.scheduledAt` |
| Question limit | `Slider` (1-20) | `Consultation.questionLimit` |
| Price | Auto-filled from expert's `pricePerSession` | `Consultation.price` |

Creates a `Consultation` document with `status: "pending"` via `ConsultationRepository.create()`.

### 5.9 Payment Processing

`PaymentService` integrates Razorpay for INR payment processing:

```
User taps "Pay" on ConsultationDetailScreen
  |
  v
PaymentService.payConsultation()
  |-- Opens Razorpay checkout
  |-- key: from --dart-define=RAZORPAY_KEY (or test placeholder)
  |-- amount: price * 100 (paise)
  |-- prefill: user email
  |-- external wallets: Paytm
  |
  |-- EVENT_PAYMENT_SUCCESS -> callback with paymentId -> update consultation status to "accepted"
  |-- EVENT_PAYMENT_ERROR -> show error SnackBar, no status change
  |-- EVENT_EXTERNAL_WALLET -> log wallet name
```

**Target state** (v1.1): Server-side Razorpay order creation via FastAPI, payment signature verification, webhook handler for reliable confirmation, platform commission logic.

### 5.10 Review and Rating System

After consultation completion, learners submit reviews via `ReviewSubmitScreen`:

- Star rating (1-5)
- Text feedback

`ReviewRepository.submitReview()` performs a Firestore batch write:
1. Creates the `Review` document
2. Recalculates the expert's average `rating` and increments `totalReviews`

This ensures atomic rating updates. Reviews are displayed on expert profiles and monitored in the admin dashboard.

---

## Pillar 3: Multi-Role Administration

### 5.11 Role-Based Access Control

The `UserRole` enum (`user`, `expert`, `admin`) drives the entire navigation tree:

```
AuthGate (StreamBuilder on FirebaseAuth)
  |
  |-- Not authenticated -> LoginScreen
  |-- Authenticated -> RoleRouter
        |
        |-- UserRole.user   -> UserMainShell (NavigationBar: Home, Profile)
        |-- UserRole.expert  -> ExpertHomeScreen
        |-- UserRole.admin   -> AdminDashboardScreen
```

`RoleRouter` watches the user's Firestore document via `UserRepository.watchUser()` and reactively routes based on the `role` field.

### 5.12 Admin Dashboard

`AdminDashboardScreen` provides four management tabs:

| Tab | Capabilities |
|---|---|
| **Users** | View all users, change roles (user/expert/admin) via `PopupMenuButton` |
| **Experts** | Toggle verification status, view rating statistics |
| **Consultations** | Monitor all bookings across the platform, view statuses |
| **Reviews** | Read feedback, moderate (delete) inappropriate reviews |

### 5.13 Expert Console

`ExpertHomeScreen` allows domain experts to:

- View their linked expert profile (matched by `linkedUserId` or email)
- See incoming consultation bookings via `ConsultationRepository.watchForExpert()`
- Track consultation statuses (pending / accepted / completed / cancelled)

---

# 6. System Architecture

## 6.1 Current Architecture (v1.0 -- Implemented)

```
+-------------------------------------------------------+
|                    Flutter Mobile App                   |
|                                                         |
|  +---------------------------------------------------+ |
|  |           AppServices (InheritedWidget)            | |
|  |          accessed via context.svc extension         | |
|  |                                                     | |
|  |  AuthService         UserRepository                | |
|  |  (Firebase Auth +    (Firestore 'users')           | |
|  |   Google Sign-In)                                   | |
|  |                                                     | |
|  |  ExpertRepository    ConsultationRepository        | |
|  |  (Firestore           (Firestore                   | |
|  |   'experts')           'consultations')             | |
|  |                                                     | |
|  |  RoadmapRepository   ReviewRepository              | |
|  |  (Firestore           (Firestore                   | |
|  |   'roadmaps')          'reviews')                   | |
|  |                                                     | |
|  |  AiRoadmapService    PaymentService                | |
|  |  (local keyword       (Razorpay                    | |
|  |   stub)                checkout)                    | |
|  +---------------------------------------------------+ |
|                                                         |
|  Screens (14 files):                                    |
|  LoginScreen -> RoleRouter -> UserMainShell             |
|                             -> ExpertHomeScreen          |
|                             -> AdminDashboardScreen      |
+-------------------------------------------------------+
          |                           |
          v                           v
  +---------------+          +----------------+
  |   Firebase     |          |    Razorpay     |
  |  - Auth        |          |  - Checkout     |
  |  - Firestore   |          |  - Payments     |
  |  - Storage     |          +----------------+
  +---------------+
```

**Architectural Patterns:**
- **Service Locator**: `AppServices` InheritedWidget provides singleton service instances to the entire widget tree via `context.svc`
- **Repository Pattern**: Each Firestore collection has a dedicated repository with `Stream<List<T>>` watchers and `Future<T>` operations
- **Constructor Injection**: Repositories accept `FirebaseFirestore` instance (enables testing with fake Firestore)
- **Reactive UI**: `StreamBuilder` widgets subscribe to real-time Firestore document/collection streams
- **Immutable Models**: `const` constructors, `factory fromFirestore()`, `copyWith()` for updates

## 6.2 Target Architecture (v1.1 -- AI Backend)

```
+--------------------+        +---------------------------+
|   Flutter App       |        |      FastAPI Server        |
|                    |  HTTPS  |      (Python 3.11+)        |
|  AiGuidanceService |------->|                           |
|  (HTTP client,     |        |  Auth Middleware            |
|   replaces local   |        |  (Firebase Admin SDK        |
|   AiRoadmapService)|        |   token verification)      |
|                    |        |                           |
|  Firebase SDK      |        |  /api/v1/guidance/analyze  |
|  (Auth, Firestore  |        |  /api/v1/guidance/replan   |
|   -- shared)       |        |  /api/v1/guidance/roadmap  |
+--------------------+        |                           |
          |                    |  Vertex AI Client          |
          |                    |  (Gemini 2.5 Flash)        |
          |                    |                           |
          |    Shared          |  Firebase Admin SDK        |
          |    Firestore  <----|  (Firestore read/write)    |
          |                    +---------------------------+
          v                              |
  +---------------+                      v
  |   Firebase     |            +-----------------+
  |  - Auth        |            |   Vertex AI      |
  |  - Firestore   |            |   (Google Cloud)  |
  |  (5 collections)|           |   Gemini 2.5     |
  +---------------+            |   Flash           |
                                +-----------------+
```

**Key design decisions:**

1. **Shared Firestore**: Both Flutter app and FastAPI backend read/write the same Firestore collections. The Flutter app continues to use Firestore SDK for real-time subscriptions; the backend uses Firebase Admin SDK for AI-triggered writes.

2. **Firebase token passthrough**: The Flutter app sends the user's Firebase ID token to FastAPI. The backend verifies it using Firebase Admin SDK, extracting the `uid` to scope all operations to the authenticated user.

3. **Swap-ready service interface**: The local `AiRoadmapService` returns `AiAnalysis` with fields: `extractedSkills`, `goalAnalysis`, `skillGaps`, `targetRole`, `milestones`, `resources`, `timeline`. The new HTTP-based service will return the identical structure, making the migration a single service swap in `AppServices`.

## 6.3 AI Orchestration -- Prompt Chain Architecture

Instead of a complex multi-agent framework, Pathwise uses a **sequential prompt chain** -- four focused Vertex AI calls that each solve one sub-problem and pass structured output to the next step.

```
User Input (resume, skills, interests, careerGoals)
  |
  |  Step 1: Goal Analyzer
  |  System: "You are a career counselor. Extract a structured career objective."
  |  Input: raw user data
  |  Output: { targetRole, timeline, constraints, learningStyle }
  |  Temperature: 0.2 (deterministic)
  |
  v
  |  Step 2: Skill Gap Detector
  |  System: "You are a technical skills assessor. Compare the learner's
  |           current skills against requirements for {targetRole}."
  |  Input: Step 1 output + user skills + resume
  |  Output: { gaps[], strengths[], prerequisites[], confidenceScores{} }
  |  Temperature: 0.2 (deterministic)
  |
  v
  |  Step 3: Roadmap Planner
  |  System: "You are a learning architect. Create a phased roadmap that
  |           respects prerequisite ordering, time constraints, and skill gaps."
  |  Input: Step 1 + Step 2 outputs
  |  Output: { phases[], milestones[], deadlines[], revisionPoints[] }
  |  Temperature: 0.3 (slightly creative for phrasing)
  |
  v
  |  Step 4: Resource Curator
  |  System: "You are a learning resource specialist. Map specific, high-quality
  |           resources to each milestone. Prefer free resources."
  |  Input: Step 3 phases
  |  Output: { resources[] with URLs, types, difficulty levels }
  |  Temperature: 0.5 (creative for resource diversity)
  |
  v
  Aggregator: Combine all outputs into Roadmap document -> Firestore write
```

**Why prompt chaining over a multi-agent framework:**

| Consideration | Prompt Chain | Multi-Agent Framework |
|---|---|---|
| Deployment complexity | Single FastAPI process | Requires agent runtime, state store |
| Debugging | Each step is an independent API call with its own prompt | Complex graph state to trace |
| Latency | 4 sequential Vertex AI calls (~6-8s total) | Agent loop overhead, potential retries |
| Scale threshold | Sufficient for 4 sequential reasoning steps | Valuable at 10+ agents with conditional routing |
| Cost | 4 focused prompts = minimal token usage | Agent loops may repeat prompts |

The architecture is designed to **evolve**: if Pathwise grows to need conditional branching (e.g., different analysis paths for different career domains), the prompt chain can be upgraded to a directed graph without changing the FastAPI interface.

**Gemini 2.5 Flash specifics:**
- **Structured output**: Uses Vertex AI's `response_schema` parameter to enforce JSON output format at each step, eliminating parsing failures
- **Context window**: 1M tokens -- sufficient to include full resume + conversation history for replanning
- **Speed**: Flash variant optimized for latency (~1-2s per step)
- **Cost**: Most cost-effective Gemini model for structured reasoning tasks

## 6.4 Data Flow Diagrams

### Flow 1: AI Roadmap Generation

```
User                Flutter App              FastAPI              Vertex AI         Firestore
 |                      |                       |                     |                 |
 |  Fill goal wizard    |                       |                     |                 |
 |--------------------->|                       |                     |                 |
 |                      |  POST /guidance/analyze                     |                 |
 |                      |  + Firebase ID token  |                     |                 |
 |                      |---------------------->|                     |                 |
 |                      |                       |  Verify token       |                 |
 |                      |                       |  Extract uid        |                 |
 |                      |                       |                     |                 |
 |                      |                       |  Step 1: Goal       |                 |
 |                      |                       |-------------------->|                 |
 |                      |                       |<--------------------|                 |
 |                      |                       |  Step 2: Gaps       |                 |
 |                      |                       |-------------------->|                 |
 |                      |                       |<--------------------|                 |
 |                      |                       |  Step 3: Roadmap    |                 |
 |                      |                       |-------------------->|                 |
 |                      |                       |<--------------------|                 |
 |                      |                       |  Step 4: Resources  |                 |
 |                      |                       |-------------------->|                 |
 |                      |                       |<--------------------|                 |
 |                      |                       |                     |                 |
 |                      |                       |  Write roadmap doc  |                 |
 |                      |                       |---------------------------------------->|
 |                      |                       |                     |                 |
 |                      |  200 OK + roadmap_id  |                     |                 |
 |                      |<----------------------|                     |                 |
 |                      |                       |                     |                 |
 |                      |  StreamBuilder fires                        |                 |
 |                      |  (Firestore listener) |                     |                 |
 |                      |<----------------------------------------------------+         |
 |  RoadmapDetailScreen |                       |                     |                 |
 |<---------------------|                       |                     |                 |
```

### Flow 2: Consultation Booking + Payment

```
User                Flutter App                     Razorpay          Firestore
 |                      |                               |                 |
 |  Browse experts      |                               |                 |
 |--------------------->| ExpertsScreen                  |                 |
 |                      |  StreamBuilder on 'experts'    |                 |
 |                      |<----------------------------------------------------+
 |  Select expert       |                               |                 |
 |--------------------->| ExpertDetailScreen             |                 |
 |  Book session        |                               |                 |
 |--------------------->| BookConsultationScreen          |                 |
 |  Choose type, date,  |                               |                 |
 |  question limit      |                               |                 |
 |--------------------->|                               |                 |
 |                      |  Create consultation           |                 |
 |                      |  status: "pending"             |                 |
 |                      |----------------------------------------------->|
 |                      |                               |                 |
 |  Tap "Pay"           | ConsultationDetailScreen       |                 |
 |--------------------->|                               |                 |
 |                      |  PaymentService                |                 |
 |                      |  .payConsultation()            |                 |
 |                      |------------------------------>|                 |
 |                      |                               |                 |
 |  Razorpay checkout   |                               |                 |
 |<---------------------|------------------------------>|                 |
 |  Complete payment    |                               |                 |
 |--------------------->|------------------------------>|                 |
 |                      |  EVENT_PAYMENT_SUCCESS         |                 |
 |                      |<------------------------------|                 |
 |                      |                               |                 |
 |                      |  Update status: "accepted"     |                 |
 |                      |----------------------------------------------->|
 |                      |                               |                 |
 |  Expert sees booking |                               |                 |
 |  in ExpertHomeScreen |  StreamBuilder fires           |                 |
```

### Flow 3: Review + Rating Aggregation

```
User                Flutter App                          Firestore
 |                      |                                    |
 |  Submit review       | ReviewSubmitScreen                  |
 |  (rating + feedback) |                                    |
 |--------------------->|                                    |
 |                      |  ReviewRepository.submitReview()    |
 |                      |  Batch write:                       |
 |                      |    1. Create review doc              |
 |                      |    2. Recalculate expert.rating      |
 |                      |    3. Increment expert.totalReviews  |
 |                      |----------------------------------->|
 |                      |                                    |
 |                      |  Expert profile updates atomically  |
 |                      |  StreamBuilder refreshes            |
 |  Updated rating      |<-----------------------------------|
 |  shown everywhere    |                                    |
```

---

# 7. Data Model Design

## 7.1 Entity Relationship Diagram

```
AppUser (1) ---------> (N) Roadmap          [userId]
AppUser (1) ---------> (N) Consultation     [userId]
Expert  (1) ---------> (N) Consultation     [expertId]
Expert  (1) ---------> (N) Review           [expertId]
AppUser (1) ---------> (N) Review           [userId]
Consultation (1) ----> (0..1) Review        [consultationId]
AppUser (0..1) <-----> (0..1) Expert        [linkedUserId / email match]
```

## 7.2 Collection Schemas

### `users` Collection

```json
{
  "uid": "string (Firebase Auth UID)",
  "name": "string",
  "email": "string",
  "resume": "string (plain text)",
  "skills": ["string"],
  "interests": ["string"],
  "careerGoals": "string",
  "role": "string (user | expert | admin)",
  "createdAt": "Timestamp",
  "lastLoginDate": "Timestamp"
}
```

Implementation note: `AppUser.fromFirestore()` handles backward-compatible field parsing -- checks both camelCase (`skills`) and PascalCase (`Skills`) keys to handle legacy data from manual Firestore entries.

### `experts` Collection

```json
{
  "expertId": "string",
  "name": "string",
  "email": "string",
  "domain": "string (e.g., 'Artificial Intelligence')",
  "experience": "string (e.g., '12 years')",
  "rating": "number (0.0 - 5.0, aggregated)",
  "pricePerSession": "number (INR)",
  "isVerified": "boolean",
  "skills": ["string"],
  "totalReviews": "number",
  "createdAt": "Timestamp",
  "linkedUserId": "string | null (links to AppUser.uid)"
}
```

The `linkedUserId` field bridges the user authentication system with the expert marketplace. When an expert logs in as a regular user, `ExpertRepository.findExpertForUser()` matches by `linkedUserId` first, then falls back to email matching.

### `roadmaps` Collection

```json
{
  "roadmapId": "string",
  "userId": "string",
  "targetRole": "string",
  "milestones": ["string (phase descriptions)"],
  "resources": ["string (URLs)"],
  "timeline": "string",
  "stageProgress": {
    "beginner": "number (0.0 - 1.0)",
    "intermediate": "number (0.0 - 1.0)",
    "advanced": "number (0.0 - 1.0)"
  },
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

The `stageProgress` map enables granular progress tracking per phase. The `Roadmap.structuredStages` getter transforms flat milestone arrays into `RoadmapStage` objects for UI rendering.

### `consultations` Collection

```json
{
  "consultationId": "string",
  "userId": "string",
  "expertId": "string",
  "type": "string (chat | audio | video)",
  "status": "string (pending | accepted | completed | cancelled)",
  "price": "number (INR)",
  "questionLimit": "number (1-20)",
  "scheduledAt": "Timestamp",
  "createdAt": "Timestamp"
}
```

Implementation note: `Consultation._cleanStatus()` strips nested quotes from status/type fields -- defensive parsing for data that may have been manually entered via the Firebase Console.

### `reviews` Collection

```json
{
  "reviewId": "string",
  "userId": "string",
  "expertId": "string",
  "consultationId": "string",
  "rating": "number (1-5, integer)",
  "feedback": "string",
  "timestamp": "Timestamp"
}
```

---

# 8. API Contract Specification (FastAPI Backend)

## 8.1 Authentication Middleware

All API endpoints require a Firebase ID token:

```
Authorization: Bearer <firebase_id_token>
```

FastAPI dependency verifies the token using Firebase Admin SDK and extracts the authenticated `uid`. Requests without valid tokens receive `401 Unauthorized`.

## 8.2 Guidance Endpoints

### `POST /api/v1/guidance/analyze`

Generates a personalized roadmap from user input via the Vertex AI prompt chain.

**Request:**
```json
{
  "resume_text": "string (plain text, max 10,000 chars)",
  "skills": ["string"],
  "interests": ["string"],
  "career_goals": "string (max 500 chars)"
}
```

**Response (200):**
```json
{
  "roadmap_id": "string (Firestore document ID)",
  "target_role": "string",
  "goal_analysis": "string (AI-generated summary)",
  "extracted_skills": ["string"],
  "skill_gaps": ["string"],
  "milestones": ["string"],
  "resources": [
    {
      "url": "string",
      "title": "string",
      "type": "course | article | video | project",
      "difficulty": "beginner | intermediate | advanced"
    }
  ],
  "timeline": "string",
  "confidence_scores": {
    "skill_name": 0.0
  }
}
```

**Errors:**
| Code | Condition |
|---|---|
| 400 | All input fields empty (at least one of resume, skills, or goals required) |
| 401 | Invalid or missing Firebase token |
| 422 | Validation error (field length exceeded) |
| 429 | Rate limit exceeded (max 10 analyses per user per day) |
| 503 | Vertex AI unavailable (includes `Retry-After` header) |
| 504 | Vertex AI timeout (prompt chain exceeded 15s) |

### `POST /api/v1/guidance/replan`

Adjusts an existing roadmap based on current progress and optional learner feedback.

**Request:**
```json
{
  "roadmap_id": "string",
  "current_progress": {
    "beginner": 0.0,
    "intermediate": 0.0,
    "advanced": 0.0
  },
  "feedback": "string | null (optional learner notes on struggles)"
}
```

**Response (200):**
```json
{
  "updated_milestones": ["string"],
  "updated_resources": [
    {
      "url": "string",
      "title": "string",
      "type": "string",
      "difficulty": "string"
    }
  ],
  "updated_timeline": "string",
  "replan_reason": "string (AI-generated explanation of changes)"
}
```

### `GET /api/v1/guidance/roadmap/{user_id}`

Retrieves the active roadmap for a user. Returns `404` if no roadmap exists.

**Response (200):**
```json
{
  "roadmap_id": "string",
  "target_role": "string",
  "milestones": ["string"],
  "resources": ["object"],
  "timeline": "string",
  "stage_progress": { "string": 0.0 },
  "created_at": "ISO 8601",
  "updated_at": "ISO 8601"
}
```

## 8.3 Pydantic Schema Alignment

FastAPI Pydantic models mirror the Dart data classes for cross-language consistency:

| Dart Class | Pydantic Model | Shared Fields |
|---|---|---|
| `AiAnalysis` | `GuidanceAnalysisResponse` | extractedSkills, goalAnalysis, skillGaps, targetRole, milestones, resources, timeline |
| `Roadmap` | `RoadmapDocument` | roadmapId, userId, targetRole, milestones, resources, timeline, stageProgress |
| `AppUser` (subset) | `LearnerProfile` | uid, skills, interests, careerGoals, resume |

---

# 9. Payment Architecture

## 9.1 Current Implementation (v1.0)

Razorpay integration is client-side only, suitable for development and testing:

1. `PaymentService` initializes Razorpay SDK and registers event handlers
2. API key is configured via `--dart-define=RAZORPAY_KEY=rzp_test_xxx` at build time
3. If the key contains "PLACEHOLDER", payment is blocked with an error message
4. Checkout opens with amount in paise (`price * 100`), app name "Pathwise", and optional email prefill
5. External wallet support: Paytm
6. On success: consultation status updated to "accepted"; on failure: error displayed, no state change

## 9.2 Target Implementation (v1.1)

Server-side payment flow for production security:

```
Flutter App                  FastAPI                     Razorpay
     |                          |                            |
     |  POST /payments/order    |                            |
     |  { consultation_id }     |                            |
     |------------------------->|                            |
     |                          |  Create order              |
     |                          |  (amount, currency, receipt)|
     |                          |--------------------------->|
     |                          |  order_id                  |
     |                          |<---------------------------|
     |  { order_id, amount }    |                            |
     |<-------------------------|                            |
     |                          |                            |
     |  Open Razorpay checkout  |                            |
     |  with order_id           |                            |
     |--------------------------------------------->         |
     |  Payment completed       |                            |
     |<---------------------------------------------         |
     |                          |                            |
     |  POST /payments/verify   |                            |
     |  { payment_id, order_id, |                            |
     |    signature }           |                            |
     |------------------------->|                            |
     |                          |  Verify HMAC signature     |
     |                          |  Update consultation       |
     |                          |  status: "accepted"        |
     |  { verified: true }      |                            |
     |<-------------------------|                            |
     |                          |                            |
     |                          |  Webhook (backup)          |
     |                          |<---------------------------|
```

## 9.3 Pricing Model

- Experts set their own `pricePerSession` (stored in `experts` collection)
- Consultation price is locked at booking time (immune to expert price changes)
- Amount transmitted to Razorpay in paise (smallest currency unit)
- **Future**: Platform commission (e.g., 15% of each transaction) deducted before expert payout

---

# 10. AI Strategy Deep Dive

## 10.1 Model Selection: Gemini 2.5 Flash via Vertex AI

| Factor | Decision |
|---|---|
| **Model** | Gemini 2.5 Flash |
| **Access** | Vertex AI API (Google Cloud) |
| **Why Flash** | Optimized for speed and cost while maintaining strong structured output capabilities |
| **Context window** | 1M tokens (sufficient for full resume + analysis history for replanning) |
| **Output format** | Structured JSON via `response_schema` parameter (eliminates parsing failures) |
| **Region** | asia-south1 (Mumbai) for low latency to Indian users |

## 10.2 Prompt Engineering

### Goal Analyzer Prompt (Step 1)

```
System:
You are a career counselor specializing in technology careers. Analyze the
learner's input and extract a structured career objective.

Consider:
- Explicit career goals stated by the learner
- Implicit signals from their resume, skills, and interests
- Market demand for the inferred role
- Realistic timeline given their current skill level

Respond ONLY with valid JSON matching the provided schema.

User:
Resume: {resume_text}
Current Skills: {skills}
Interests: {interests}
Career Goals: {career_goals}
```

### Skill Gap Detector Prompt (Step 2)

```
System:
You are a technical skills assessor. Given a learner's target role and current
skill profile, identify:
1. Skills they already have (strengths)
2. Skills they are missing (gaps)
3. Prerequisite skills they need before tackling advanced gaps
4. Confidence score (0.0-1.0) for each gap based on how critical it is

Order gaps by prerequisite dependency: foundational gaps first, advanced gaps last.
Do NOT include skills irrelevant to the target role.

User:
Target Role: {target_role}
Timeline: {timeline}
Constraints: {constraints}
Current Skills: {extracted_skills}
Resume Context: {resume_text}
```

## 10.3 Closed-Loop Intelligence (v1.1+)

### Progress-Aware Replanning

```
Trigger: stageProgress for any stage unchanged for > 14 days
   |
   v
Fetch learner's roadmap + progress history + past replan events
   |
   v
Replan Prompt:
  "The learner has been stuck on {stage} at {progress}% for {days} days.
   Their original timeline was {timeline}. Their stated struggles: {feedback}.
   Adjust the roadmap to account for this delay."
   |
   v
Output: compressed milestones, reordered topics, alternative resources
   |
   v
Write updated roadmap to Firestore -> StreamBuilder auto-refreshes UI
```

### Learner Memory (v1.2)

A `learner_memory` subcollection under each user document stores:

| Memory Type | Content | Used By |
|---|---|---|
| `analysis_history` | Past AI analyses with timestamps | Replan prompt context |
| `struggle_patterns` | Topics where progress stalled repeatedly | Gap detector weighting |
| `pace_trends` | Average days per stage completion | Timeline estimation |
| `expert_annotations` | Expert notes from consultations | Replan prompt augmentation |
| `preferred_formats` | Resource types the learner engages with most | Resource curator filtering |

This enables the AI to reason over the learner's history, not just their current state -- transforming one-shot generation into **continuous adaptive intelligence**.

### Expert-AI Handoff

After a consultation, the expert can annotate the learner's roadmap with observations (e.g., "Learner understands CNNs conceptually but struggles with implementation -- recommend hands-on project before advancing"). These annotations are stored in `learner_memory` and injected into the replan prompt, creating a feedback loop where human expertise directly improves AI recommendations.

## 10.4 Cost Management

| Strategy | Implementation |
|---|---|
| Per-user rate limit | Max 10 analyses/day, 3 replans/day via FastAPI middleware |
| Prompt caching | Cache Step 1 (Goal Analyzer) output for 24h if input unchanged |
| Structured output | `response_schema` eliminates retry-inducing parse failures |
| Model choice | Flash is ~10x cheaper than Pro for equivalent quality on structured tasks |
| Input trimming | Resume text capped at 10,000 chars; skills/interests at 50 items |

---

# 11. Flutter Architecture

## 11.1 State Management

| Layer | Mechanism | Rationale |
|---|---|---|
| **Dependency Injection** | `AppServices` InheritedWidget + `context.svc` extension | Lightweight DI without code generation overhead |
| **Service Instances** | `MultiProvider` wrapping singleton services | Single instantiation, shared across widget tree |
| **UI State** | `StatefulWidget` local state + `StreamBuilder` | App is primarily read-reactive CRUD; no need for BLoC/Riverpod complexity |
| **Real-time Data** | `StreamBuilder` on Firestore collection/document streams | Automatic UI refresh when backend data changes |

## 11.2 Screen Inventory

| Screen | File | Role Access | Purpose |
|---|---|---|---|
| `LoginScreen` | `login_screen.dart` | All | Google Sign-In entry point |
| `RoleRouter` | `role_router.dart` | All | Auth-aware routing by `UserRole` |
| `UserMainShell` | `user_main_shell.dart` | User | Bottom nav (Home + Profile tabs) |
| `HomeModeScreen` | `home_mode_screen.dart` | User | Choose AI Guidance or Expert mode |
| `AiGuidanceScreen` | `ai_guidance_screen.dart` | User | Resume upload, skill tagging, roadmap generation |
| `RoadmapDetailScreen` | `roadmap_detail_screen.dart` | User | View roadmap phases, update progress |
| `ExpertsScreen` | `experts_screen.dart` | User | Browse verified experts |
| `ExpertDetailScreen` | `expert_detail_screen.dart` | User | Expert profile and booking entry |
| `BookConsultationScreen` | `book_consultation_screen.dart` | User | Session type, scheduling, pricing |
| `ConsultationDetailScreen` | `consultation_detail_screen.dart` | User | Payment flow, consultation status |
| `ReviewSubmitScreen` | `review_submit_screen.dart` | User | Star rating + text feedback |
| `ProfileScreen` | `profile_screen.dart` | User | Edit profile, view consultations/roadmaps |
| `ExpertHomeScreen` | `expert_home_screen.dart` | Expert | Incoming consultations dashboard |
| `AdminDashboardScreen` | `admin_dashboard_screen.dart` | Admin | 4-tab management console |

## 11.3 Offline Behavior

- **Firestore SDK** provides automatic offline caching; `StreamBuilder` displays cached data when connectivity drops
- **Payment** requires connectivity (Razorpay checkout is online-only)
- **AI analysis** requires connectivity (Vertex AI backend call)
- **Target**: Explicit offline mode indicator in the UI, queue consultation bookings for sync when online

---

# 12. Security Model

## 12.1 Authentication

- **Provider**: Firebase Auth with Google Sign-In
- **Flow**: `AuthService.signInWithGoogle()` -> Google account selection -> Firebase credential -> `authStateChanges()` stream triggers `RoleRouter`
- **Session**: Firebase Auth manages token refresh automatically
- **Constructor injection**: `AuthService` accepts optional `FirebaseAuth` and `GoogleSignIn` instances for testability

## 12.2 Authorization

| Layer | Mechanism |
|---|---|
| **Screen-level** | `RoleRouter` checks `AppUser.role` and routes to role-specific home screens |
| **Feature-level** | Admin tabs only accessible from `AdminDashboardScreen` |
| **Data-level** | Firestore Security Rules (proposed below) |

### Proposed Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: read own, admins read all, write own profile
    match /users/{uid} {
      allow read: if request.auth.uid == uid
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow write: if request.auth.uid == uid;
    }

    // Experts: anyone authenticated can read, only admins can write
    match /experts/{expertId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Roadmaps: owner read/write, admins read
    match /roadmaps/{roadmapId} {
      allow read, write: if request.auth.uid == resource.data.userId
                         || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null;
    }

    // Consultations: involved parties + admins
    match /consultations/{consultationId} {
      allow read: if request.auth.uid == resource.data.userId
                  || request.auth.uid == resource.data.expertId
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.userId
                    || request.auth.uid == resource.data.expertId;
    }

    // Reviews: anyone authenticated can read, author can write
    match /reviews/{reviewId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## 12.3 API Security (v1.1)

| Threat | Mitigation |
|---|---|
| **Unauthorized access** | Firebase ID token verification on every FastAPI request |
| **Prompt injection** | Input sanitization (strip control characters), Vertex AI safety filters, `response_schema` enforcement |
| **Cost abuse** | Per-user daily rate limits (10 analyses, 3 replans) |
| **Data exposure** | Resume text and career goals are PII; never logged in full, only hashed for debugging |
| **Payment fraud** | Server-side Razorpay order creation + HMAC signature verification |

---

# 13. Non-Functional Requirements

| Requirement | Target | Measurement |
|---|---|---|
| Roadmap generation latency | < 8s (4-step prompt chain) | P95 from FastAPI access logs |
| Replan latency | < 5s (single prompt) | P95 from FastAPI access logs |
| Dashboard load time | < 2s (first meaningful paint) | Firestore query + StreamBuilder render |
| Payment success rate | > 95% (of initiated checkouts) | Razorpay dashboard analytics |
| API uptime | 99.5% | Cloud Run health check monitoring |
| Vertex AI fallback rate | < 5% (of total requests) | Error rate in FastAPI structured logs |
| Firestore read cost | < 50K reads/day at 100 DAU | Firebase Console billing dashboard |
| App crash rate | < 0.5% | Firebase Crashlytics (when integrated) |
| Cold start latency (API) | < 3s | Cloud Run min-instances configuration |

---

# 14. Success Metrics

### Product Metrics

| Metric | Target | Signal |
|---|---|---|
| DAU / MAU | > 25% | Engagement and habit formation |
| Roadmap generation to first progress update | < 48 hours | Activation velocity |
| Expert consultation conversion | > 10% of users who view expert list | Marketplace health |
| Review submission rate | > 60% of completed consultations | Feedback loop quality |
| Repeat consultation rate | > 30% | Expert value validation |
| Replan trigger rate | > 20% of active learners per month | Adaptive system engagement |

### Technical Metrics

| Metric | Target | Signal |
|---|---|---|
| Prompt chain success rate | > 95% | Vertex AI reliability |
| Structured output parse rate | > 99% | `response_schema` effectiveness |
| Payment completion rate | > 90% (of initiated) | Razorpay integration health |
| Firestore read latency (P95) | < 500ms | Database performance |
| API error rate | < 2% | Backend stability |

---

# 15. Development Roadmap

### Phase 0: Foundation (Completed)

| Deliverable | Status |
|---|---|
| Flutter app scaffold with 14 screens | Done |
| Firebase Auth (Google Sign-In) | Done |
| Firestore CRUD for 5 collections (users, experts, consultations, roadmaps, reviews) | Done |
| Service-locator architecture (AppServices InheritedWidget, 8 services) | Done |
| Expert Marketplace (discovery, booking, consultation lifecycle) | Done |
| Razorpay payment integration (client-side) | Done |
| Local AI stub (keyword-based AiRoadmapService) | Done |
| Role-based routing (user / expert / admin) | Done |
| Admin dashboard (4-tab management console) | Done |
| Review and rating system with atomic aggregation | Done |

### Phase 1: AI Backend (4 weeks)

| Week | Deliverable |
|---|---|
| 1 | FastAPI project scaffold, Firebase Admin SDK integration, Pydantic schemas |
| 2 | Vertex AI client, Goal Analyzer + Skill Gap prompts with structured output |
| 3 | Roadmap Planner + Resource Curator prompts, aggregator logic |
| 4 | Replace `AiRoadmapService` with HTTP client in Flutter, end-to-end testing |

### Phase 2: Adaptive Intelligence (3 weeks)

| Week | Deliverable |
|---|---|
| 1 | `/api/v1/guidance/replan` endpoint with progress-aware prompt |
| 2 | Learner memory subcollection, analysis history persistence |
| 3 | Auto-trigger replanning when progress stalls, expert annotation bridge |

### Phase 3: Payment Hardening (2 weeks)

| Week | Deliverable |
|---|---|
| 1 | Server-side Razorpay order creation, signature verification endpoint |
| 2 | Webhook handler for reliable payment confirmation, platform commission logic |

### Phase 4: Production Readiness (2 weeks)

| Week | Deliverable |
|---|---|
| 1 | Cloud Run deployment, Firestore Security Rules audit, rate limiting |
| 2 | Structured logging, error reporting, monitoring dashboards, portfolio case study |

---

# 16. Risk Register

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| **Vertex AI cost overrun** | High | Medium | Per-user daily rate limits, Gemini Flash (cheapest), prompt caching, input trimming |
| **Razorpay payment disputes** | Medium | Low | Server-side signature verification, consultation status audit trail, cancellation policy |
| **Expert supply problem** | High | High | Seed with 5-10 initial experts, AI-first value proposition reduces expert dependency for core experience |
| **Prompt injection via resume** | Medium | Medium | Input sanitization, Vertex AI safety filters, `response_schema` enforcement, never execute LLM output as code |
| **Firestore cost at scale** | Medium | Medium | Composite indexes for common queries, pagination on admin screens, denormalization for read-heavy paths |
| **Gemini model deprecation** | Low | Low | Abstract Vertex AI client behind interface, prompt templates decoupled from model-specific syntax |
| **Single point of failure (FastAPI)** | Medium | Low | Cloud Run auto-scaling, health checks, Firestore continues serving cached data in Flutter app during outage |

---

# 17. FastAPI Project Structure

```
backend/
  app/
    main.py                    # FastAPI app, CORS, lifespan
    config.py                  # Environment variables, Vertex AI region/project
    dependencies.py            # Firebase token verification dependency
    routers/
      guidance.py              # /api/v1/guidance/* endpoints
      payments.py              # /api/v1/payments/* endpoints (v1.1)
    services/
      vertex_ai.py             # Gemini 2.5 Flash client, prompt chain orchestrator
      firestore.py             # Firebase Admin SDK Firestore operations
    prompts/
      goal_analyzer.py         # Step 1 system + user prompt templates
      skill_gap.py             # Step 2 prompt templates
      roadmap_planner.py       # Step 3 prompt templates
      resource_curator.py      # Step 4 prompt templates
      replanner.py             # Replan prompt template
    schemas/
      guidance.py              # Pydantic models for analysis request/response
      roadmap.py               # Pydantic models for roadmap documents
      common.py                # Shared types (SkillGap, Resource, etc.)
  tests/
    test_guidance.py           # Integration tests for prompt chain
    test_auth.py               # Token verification tests
    conftest.py                # Test fixtures (mock Vertex AI, fake Firestore)
  requirements.txt             # FastAPI, firebase-admin, google-cloud-aiplatform, pydantic
  Dockerfile                   # Cloud Run container
  .env.example                 # Required environment variables
```

---

# 18. Appendix: Vertex AI Configuration

### Environment Variables

```env
GCP_PROJECT_ID=pathwise-aedc5
GCP_REGION=asia-south1
VERTEX_AI_MODEL=gemini-2.5-flash
FIREBASE_CREDENTIALS_PATH=./service-account.json
RAZORPAY_KEY_ID=rzp_live_xxx
RAZORPAY_KEY_SECRET=xxx
```

### Vertex AI Client Initialization

```python
from google.cloud import aiplatform
from vertexai.generative_models import GenerativeModel

aiplatform.init(project="pathwise-aedc5", location="asia-south1")
model = GenerativeModel("gemini-2.5-flash")
```

### Structured Output Configuration

```python
response_schema = {
    "type": "object",
    "properties": {
        "target_role": {"type": "string"},
        "timeline": {"type": "string"},
        "constraints": {"type": "array", "items": {"type": "string"}},
        "learning_style": {"type": "string"}
    },
    "required": ["target_role", "timeline"]
}

response = model.generate_content(
    prompt,
    generation_config={
        "response_mime_type": "application/json",
        "response_schema": response_schema,
        "temperature": 0.2
    }
)
```

---

# 19. Portfolio Signal Summary

This project demonstrates end-to-end product engineering across seven competency domains:

| Competency | Evidence in Pathwise |
|---|---|
| **System Design** | Multi-tier architecture (mobile -> REST API -> AI service), shared database between client and server, service locator pattern, repository abstraction |
| **AI Engineering** | Vertex AI prompt chain with structured output, closed-loop replanning, learner memory system, prompt injection defense |
| **Mobile Development** | Flutter with InheritedWidget DI, StreamBuilder reactive patterns, 14-screen app with role-based navigation, Material 3 theming |
| **Payment Systems** | Razorpay integration with full lifecycle (checkout, success/failure callbacks, external wallets), server-side verification architecture |
| **Marketplace Design** | Three-stakeholder platform (learners, experts, admin), booking flow, review aggregation, expert verification, linked account system |
| **Production Engineering** | Firebase Auth with Google OAuth, Firestore security rules, Cloud Run deployment plan, rate limiting, structured logging |
| **Product Thinking** | Multi-persona design, competitive positioning, success metrics with targets, phased delivery roadmap, risk register |

---

*This document is a living specification. It reflects the implemented codebase as of v1.0 and projects the architectural evolution through v1.2. All code references point to actual files in the repository.*
