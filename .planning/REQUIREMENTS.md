# Requirements: Pathwise

**Defined:** 2026-04-07
**Core Value:** Users get a personalized, continuously-adapting learning roadmap that evolves based on their progress, struggles, and expert feedback.

## v1 Requirements

### UI Overhaul

- [x] **UI-01**: App uses glassmorphism design system with frosted glass cards, layered depth, and translucent surfaces via BackdropFilter
- [x] **UI-02**: Onboarding wizard is a multi-step conversational flow (goal, skills, resume, constraints) with progress indicator and animated transitions
- [x] **UI-03**: Dark mode and light mode supported with consistent color scheme across all screens
- [x] **UI-04**: Micro-interactions on all key actions: progress ring fill animations, card entrance animations, celebration burst on stage completion, spring-based button feedback
- [x] **UI-05**: Skeleton loading screens replace bare CircularProgressIndicator on all data-loading screens
- [x] **UI-06**: Roadmap displayed as vertical timeline with connected nodes, pulsing current position, milestone cards, and expandable task lists
- [x] **UI-07**: AI analysis shows animated 4-step progress storytelling ("Analyzing skills..." -> "Detecting gaps..." -> "Building roadmap..." -> "Curating resources...")
- [x] **UI-08**: Expert marketplace has domain filter chips, price range slider, rating threshold filter, and sort options
- [x] **UI-09**: All screens have polished error states with retry actions and empty states with helpful guidance
- [x] **UI-10**: Gradient mesh backgrounds behind glass cards on key screens (home, roadmap, expert profile)

### AI Backend

- [x] **AI-01**: FastAPI backend deployed with Firebase Admin SDK for token verification and Firestore access
- [x] **AI-02**: Vertex AI Gemini 2.5 Flash integration via google-genai SDK with structured JSON output (response_schema)
- [x] **AI-03**: 4-step prompt chain: Goal Analyzer -> Skill Gap Detector -> Roadmap Planner -> Resource Curator
- [x] **AI-04**: Goal Analyzer extracts structured career objective with target role, timeline, constraints from user input
- [x] **AI-05**: Skill Gap Detector identifies missing skills with confidence scores (0-1), prerequisite ordering, and proficiency levels
- [x] **AI-06**: Roadmap Planner generates multi-phase milestones with estimated hours, deadlines, and revision points
- [x] **AI-07**: Resource Curator maps specific free resources (URLs, types, difficulty) to each milestone
- [x] **AI-08**: Flutter app replaces local AiRoadmapService with HTTP client calling FastAPI endpoints
- [x] **AI-09**: JSON validation layer with retry logic for malformed Gemini responses
- [x] **AI-10**: Per-user rate limiting (max 10 analyses/day, 3 replans/day)

### Adaptive Intelligence

- [x] **ADAPT-01**: Dynamic replanning triggers when stageProgress unchanged for 14+ days on any milestone
- [x] **ADAPT-02**: Replan endpoint accepts current progress + optional learner feedback and generates adjusted roadmap
- [x] **ADAPT-03**: Replanned roadmaps are new versions with replan_reason -- history preserved, not overwritten
- [x] **ADAPT-04**: Learner memory subcollection stores analysis history, struggle patterns, and pace trends
- [x] **ADAPT-05**: Memory context included in replan and subsequent analysis prompts for continuity
- [x] **ADAPT-06**: Confidence scores displayed as colored badges next to each skill gap

### Expert Marketplace

- [x] **EXP-01**: Expert discovery with search, domain filter, price range, rating filter, and sort
- [x] **EXP-02**: Expert profile shows full skill list, experience, reviews, and AI-generated learner context during consultations
- [x] **EXP-03**: Consultation booking flow polished with clear type selection, scheduling, and pricing
- [x] **EXP-04**: Expert annotation interface -- experts can add comments to learner roadmap milestones
- [x] **EXP-05**: Expert annotations stored and fed into AI replan prompts (expert-AI feedback loop)

### Payment Hardening

- [x] **PAY-01**: Server-side Razorpay order creation via FastAPI endpoint
- [x] **PAY-02**: Payment signature verification on server before updating consultation status
- [x] **PAY-03**: Webhook handler for payment.captured event as backup confirmation
- [x] **PAY-04**: Idempotent payment status transitions (state machine, not direct assignment)

### Security

- [x] **SEC-01**: Firebase security rules deployed for all 5 collections (users, experts, consultations, roadmaps, reviews)
- [x] **SEC-02**: FastAPI auth middleware verifies Firebase ID token on every request
- [x] **SEC-03**: Input sanitization on all AI endpoints (strip control characters, enforce length limits)
- [x] **SEC-04**: Resume text and career goals treated as PII -- never logged in full

### Admin

- [x] **ADM-01**: Admin dashboard shows platform analytics (total users, active roadmaps, consultations this week)
- [x] **ADM-02**: Expert verification workflow with approval/rejection actions
- [x] **ADM-03**: Review moderation with flagging and deletion capability

## v2 Requirements

### Enhanced AI

- **AI-V2-01**: Resume PDF parsing with OCR for structured skill extraction
- **AI-V2-02**: LinkedIn profile import for role matching
- **AI-V2-03**: Spaced repetition suggestions within roadmap milestones

### Engagement

- **ENG-01**: Push notifications for progress check-ins and consultation reminders (FCM)
- **ENG-02**: Weekly progress email summaries
- **ENG-03**: Achievement badges for milestone completions (non-streak)

### Platform

- **PLAT-01**: iOS deployment with Firebase configuration
- **PLAT-02**: Web deployment
- **PLAT-03**: Platform commission on expert payments (15%)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Streak gamification | Career roadmaps are weekly cadence, not daily. Creates guilt, not growth. |
| AI interview simulation | Separate product scope. Requires voice processing and scoring rubrics. |
| In-app chat/messaging | Requires WebSocket infrastructure, moderation. Consultations are booked sessions. |
| Social features / community | Requires moderation and content policy. ADPList owns this space. |
| Graph database for skills | Firestore sufficient. Gemini reasons about prerequisites in prompts. |
| Multi-language / localization | Target users operate in English. Add i18n in v2 if demand emerges. |
| Voice coach | Massive complexity (STT, NLU, TTS) for tangential benefit. |
| Agent framework (LangGraph) | 4-step prompt chain is sufficient. Agent loops burn tokens without benefit. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UI-01 | Phase 1 | Complete |
| UI-02 | Phase 1 | Complete |
| UI-03 | Phase 1 | Complete |
| UI-04 | Phase 1 | Complete |
| UI-05 | Phase 1 | Complete |
| UI-06 | Phase 1 | Complete |
| UI-07 | Phase 1 | Complete |
| UI-08 | Phase 1 | Complete |
| UI-09 | Phase 1 | Complete |
| UI-10 | Phase 1 | Complete |
| AI-01 | Phase 1 | Complete |
| AI-02 | Phase 1 | Complete |
| AI-03 | Phase 1 | Complete |
| AI-04 | Phase 1 | Complete |
| AI-05 | Phase 1 | Complete |
| AI-06 | Phase 1 | Complete |
| AI-07 | Phase 1 | Complete |
| AI-08 | Phase 1 | Complete |
| AI-09 | Phase 1 | Complete |
| AI-10 | Phase 1 | Complete |
| ADAPT-01 | Phase 2 | Complete |
| ADAPT-02 | Phase 2 | Complete |
| ADAPT-03 | Phase 2 | Complete |
| ADAPT-04 | Phase 2 | Complete |
| ADAPT-05 | Phase 2 | Complete |
| ADAPT-06 | Phase 1 | Complete |
| EXP-01 | Phase 1 | Complete |
| EXP-02 | Phase 1 | Complete |
| EXP-03 | Phase 1 | Complete |
| EXP-04 | Phase 2 | Complete |
| EXP-05 | Phase 2 | Complete |
| PAY-01 | Phase 1 | Complete |
| PAY-02 | Phase 1 | Complete |
| PAY-03 | Phase 1 | Complete |
| PAY-04 | Phase 1 | Complete |
| SEC-01 | Phase 1 | Complete |
| SEC-02 | Phase 1 | Complete |
| SEC-03 | Phase 1 | Complete |
| SEC-04 | Phase 1 | Complete |
| ADM-01 | Phase 1 | Complete |
| ADM-02 | Phase 1 | Complete |
| ADM-03 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 42 total
- Phase 1: 35 requirements
- Phase 2: 7 requirements
- Mapped to phases: 42
- Unmapped: 0

---
*Requirements defined: 2026-04-07*
*Last updated: 2026-04-07 after roadmap creation*
