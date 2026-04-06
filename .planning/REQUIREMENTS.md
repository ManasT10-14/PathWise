# Requirements: Pathwise

**Defined:** 2026-04-07
**Core Value:** Users get a personalized, continuously-adapting learning roadmap that evolves based on their progress, struggles, and expert feedback.

## v1 Requirements

### UI Overhaul

- [ ] **UI-01**: App uses glassmorphism design system with frosted glass cards, layered depth, and translucent surfaces via BackdropFilter
- [ ] **UI-02**: Onboarding wizard is a multi-step conversational flow (goal, skills, resume, constraints) with progress indicator and animated transitions
- [ ] **UI-03**: Dark mode and light mode supported with consistent color scheme across all screens
- [ ] **UI-04**: Micro-interactions on all key actions: progress ring fill animations, card entrance animations, celebration burst on stage completion, spring-based button feedback
- [ ] **UI-05**: Skeleton loading screens replace bare CircularProgressIndicator on all data-loading screens
- [ ] **UI-06**: Roadmap displayed as vertical timeline with connected nodes, pulsing current position, milestone cards, and expandable task lists
- [ ] **UI-07**: AI analysis shows animated 4-step progress storytelling ("Analyzing skills..." -> "Detecting gaps..." -> "Building roadmap..." -> "Curating resources...")
- [ ] **UI-08**: Expert marketplace has domain filter chips, price range slider, rating threshold filter, and sort options
- [ ] **UI-09**: All screens have polished error states with retry actions and empty states with helpful guidance
- [ ] **UI-10**: Gradient mesh backgrounds behind glass cards on key screens (home, roadmap, expert profile)

### AI Backend

- [ ] **AI-01**: FastAPI backend deployed with Firebase Admin SDK for token verification and Firestore access
- [ ] **AI-02**: Vertex AI Gemini 2.5 Flash integration via google-genai SDK with structured JSON output (response_schema)
- [ ] **AI-03**: 4-step prompt chain: Goal Analyzer -> Skill Gap Detector -> Roadmap Planner -> Resource Curator
- [ ] **AI-04**: Goal Analyzer extracts structured career objective with target role, timeline, constraints from user input
- [ ] **AI-05**: Skill Gap Detector identifies missing skills with confidence scores (0-1), prerequisite ordering, and proficiency levels
- [ ] **AI-06**: Roadmap Planner generates multi-phase milestones with estimated hours, deadlines, and revision points
- [ ] **AI-07**: Resource Curator maps specific free resources (URLs, types, difficulty) to each milestone
- [ ] **AI-08**: Flutter app replaces local AiRoadmapService with HTTP client calling FastAPI endpoints
- [ ] **AI-09**: JSON validation layer with retry logic for malformed Gemini responses
- [ ] **AI-10**: Per-user rate limiting (max 10 analyses/day, 3 replans/day)

### Adaptive Intelligence

- [ ] **ADAPT-01**: Dynamic replanning triggers when stageProgress unchanged for 14+ days on any milestone
- [ ] **ADAPT-02**: Replan endpoint accepts current progress + optional learner feedback and generates adjusted roadmap
- [ ] **ADAPT-03**: Replanned roadmaps are new versions with replan_reason — history preserved, not overwritten
- [ ] **ADAPT-04**: Learner memory subcollection stores analysis history, struggle patterns, and pace trends
- [ ] **ADAPT-05**: Memory context included in replan and subsequent analysis prompts for continuity
- [ ] **ADAPT-06**: Confidence scores displayed as colored badges next to each skill gap

### Expert Marketplace

- [ ] **EXP-01**: Expert discovery with search, domain filter, price range, rating filter, and sort
- [ ] **EXP-02**: Expert profile shows full skill list, experience, reviews, and AI-generated learner context during consultations
- [ ] **EXP-03**: Consultation booking flow polished with clear type selection, scheduling, and pricing
- [ ] **EXP-04**: Expert annotation interface — experts can add comments to learner roadmap milestones
- [ ] **EXP-05**: Expert annotations stored and fed into AI replan prompts (expert-AI feedback loop)

### Payment Hardening

- [ ] **PAY-01**: Server-side Razorpay order creation via FastAPI endpoint
- [ ] **PAY-02**: Payment signature verification on server before updating consultation status
- [ ] **PAY-03**: Webhook handler for payment.captured event as backup confirmation
- [ ] **PAY-04**: Idempotent payment status transitions (state machine, not direct assignment)

### Security

- [ ] **SEC-01**: Firebase security rules deployed for all 5 collections (users, experts, consultations, roadmaps, reviews)
- [ ] **SEC-02**: FastAPI auth middleware verifies Firebase ID token on every request
- [ ] **SEC-03**: Input sanitization on all AI endpoints (strip control characters, enforce length limits)
- [ ] **SEC-04**: Resume text and career goals treated as PII — never logged in full

### Admin

- [ ] **ADM-01**: Admin dashboard shows platform analytics (total users, active roadmaps, consultations this week)
- [ ] **ADM-02**: Expert verification workflow with approval/rejection actions
- [ ] **ADM-03**: Review moderation with flagging and deletion capability

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
| UI-01 | Phase 1 | Pending |
| UI-02 | Phase 1 | Pending |
| UI-03 | Phase 1 | Pending |
| UI-04 | Phase 1 | Pending |
| UI-05 | Phase 1 | Pending |
| UI-06 | Phase 1 | Pending |
| UI-07 | Phase 1 | Pending |
| UI-08 | Phase 1 | Pending |
| UI-09 | Phase 1 | Pending |
| UI-10 | Phase 1 | Pending |
| AI-01 | Phase 1 | Pending |
| AI-02 | Phase 1 | Pending |
| AI-03 | Phase 1 | Pending |
| AI-04 | Phase 1 | Pending |
| AI-05 | Phase 1 | Pending |
| AI-06 | Phase 1 | Pending |
| AI-07 | Phase 1 | Pending |
| AI-08 | Phase 1 | Pending |
| AI-09 | Phase 1 | Pending |
| AI-10 | Phase 1 | Pending |
| ADAPT-01 | Phase 2 | Pending |
| ADAPT-02 | Phase 2 | Pending |
| ADAPT-03 | Phase 2 | Pending |
| ADAPT-04 | Phase 2 | Pending |
| ADAPT-05 | Phase 2 | Pending |
| ADAPT-06 | Phase 1 | Pending |
| EXP-01 | Phase 1 | Pending |
| EXP-02 | Phase 1 | Pending |
| EXP-03 | Phase 1 | Pending |
| EXP-04 | Phase 2 | Pending |
| EXP-05 | Phase 2 | Pending |
| PAY-01 | Phase 1 | Pending |
| PAY-02 | Phase 1 | Pending |
| PAY-03 | Phase 1 | Pending |
| PAY-04 | Phase 1 | Pending |
| SEC-01 | Phase 1 | Pending |
| SEC-02 | Phase 1 | Pending |
| SEC-03 | Phase 1 | Pending |
| SEC-04 | Phase 1 | Pending |
| ADM-01 | Phase 1 | Pending |
| ADM-02 | Phase 1 | Pending |
| ADM-03 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 43 total
- Mapped to phases: 43
- Unmapped: 0

---
*Requirements defined: 2026-04-07*
*Last updated: 2026-04-07 after initial definition*
