# Pathwise

## What This Is

Pathwise is a dual-pillar career guidance mobile platform that combines Vertex AI-powered adaptive learning roadmaps with a human expert consultation marketplace. Users define career goals, receive personalized skill-gap analysis powered by Gemini 2.5 Flash, track progress through phased roadmaps, and book paid consultations with verified domain experts. Built with Flutter + Firebase + FastAPI.

## Core Value

Users get a personalized, continuously-adapting learning roadmap that evolves based on their progress, struggles, and expert feedback — not a static one-size-fits-all path.

## Requirements

### Validated

- Google Sign-In authentication via Firebase Auth — existing
- Firestore CRUD for users, experts, consultations, roadmaps, reviews — existing
- Role-based routing (user/expert/admin) with 3 distinct interfaces — existing
- Expert marketplace with discovery, booking, and consultation lifecycle — existing
- Razorpay payment integration for consultation fees — existing
- Local AI stub for keyword-based skill extraction and roadmap generation — existing
- Admin dashboard with user management, expert verification, review moderation — existing
- Review and rating system with atomic aggregation — existing
- Service-locator architecture (AppServices InheritedWidget, 8 services) — existing
- 14 screens across user, expert, and admin flows — existing

### Active

- [ ] Complete UI overhaul — modern design with animations, glassmorphism, custom components, polished micro-interactions
- [ ] FastAPI backend with Vertex AI Gemini 2.5 Flash prompt chain (4-step: goal analyzer, skill gap, roadmap planner, resource curator)
- [ ] Replace local AiRoadmapService with HTTP client calling FastAPI backend
- [ ] Semantic skill gap analysis with prerequisite reasoning and confidence scores
- [ ] Personalized multi-phase roadmap generation with real resource curation
- [ ] Dynamic replanning engine — auto-adjusts roadmap when learner falls behind
- [ ] Learner memory system — stores analysis history, struggle patterns, pace trends
- [ ] Expert-AI feedback loop — expert annotations improve future AI recommendations
- [ ] Progress-aware replanning triggers (stageProgress unchanged > 14 days)
- [ ] Server-side Razorpay order creation and signature verification
- [ ] Payment webhook handler for reliable confirmation
- [ ] Expert marketplace polish — improved discovery, filtering, booking UX
- [ ] Admin dashboard improvements — analytics, monitoring
- [ ] Firebase security rules for all 5 collections
- [ ] API rate limiting and cost controls for Vertex AI

### Out of Scope

- Resume PDF parsing with OCR — complexity vs value for MVP, defer to v2
- LinkedIn role matching — requires LinkedIn API access, defer
- Voice coach agent — high complexity, not core to career guidance
- Streak gamification — nice-to-have, defer to v2
- AI interview simulation — separate product scope
- Spaced repetition engine — defer
- Graph database for skill dependencies — Firestore sufficient for MVP
- Multi-user mentor dashboards — defer
- Cohort learning — defer
- iOS/Web deployment — Android-first for MVP

## Context

- **Existing codebase**: Flutter app with 14 screens, 5 data models (AppUser, Expert, Consultation, Roadmap, Review), 8 services, Provider + InheritedWidget architecture
- **Firebase project**: pathwise-aedc5 (Android configured, iOS not yet)
- **Payment**: Razorpay test mode integrated, production keys needed
- **AI stub**: `AiRoadmapService` with `AiAnalysis` return type — designed as swap-ready placeholder for backend integration
- **User handles**: Firebase database setup and Vertex AI API configuration
- **Target users**: Indian students/professionals preparing for tech careers
- **Monetization**: Expert consultation fees via Razorpay (INR)

## Constraints

- **AI Model**: Vertex AI Gemini 2.5 Flash only — user's choice, no LangGraph or other frameworks
- **Backend**: FastAPI (Python) — must integrate with existing Firebase via Admin SDK
- **Frontend**: Flutter 3.x — existing app, enhance don't rewrite from scratch
- **Database**: Firebase Firestore — user manages database setup
- **Payments**: Razorpay — already integrated, needs production hardening
- **Timeline**: Urgent — pack maximum scope into Phase 1
- **Platform**: Android-first (iOS/Web later)
- **Authentication**: Google Sign-In via Firebase Auth (existing)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Vertex AI + Gemini 2.5 Flash over LangGraph | Simpler deployment, sufficient for 4-step prompt chain, Flash is fast and cost-effective | — Pending |
| FastAPI over Firebase Cloud Functions | Dedicated server gives more control, better for portfolio showing backend engineering | — Pending |
| Prompt chain over multi-agent framework | 4 sequential steps don't need graph complexity, easier debugging, lower latency | — Pending |
| Coarse phase granularity | Urgent project — pack everything into few broad phases | — Pending |
| Expert marketplace as core pillar | Already implemented in code, unique differentiator vs pure AI platforms | — Pending |
| UI overhaul with glassmorphism/animations | Must create "wow factor" for portfolio — mind-blowing first impression | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-07 after initialization*
