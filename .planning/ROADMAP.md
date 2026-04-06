# Roadmap: Pathwise

## Overview

Pathwise transforms from a functional prototype with keyword-matching AI and stock Material Design into a portfolio-grade career guidance platform. Phase 1 is the big bang -- it ships the Vertex AI backend, the glassmorphism UI overhaul, payment hardening, security, and marketplace polish all at once because this project is urgent and the AI + UI must land together to deliver the "wow" moment. Phase 2 adds the adaptive intelligence moat: dynamic replanning, learner memory, and expert-AI feedback loops that require real usage data from Phase 1.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Full Platform Overhaul** - AI backend, UI transformation, payments, security, marketplace, and admin -- the entire production-ready core
- [ ] **Phase 2: Adaptive Intelligence** - Dynamic replanning, learner memory, expert-AI feedback loop -- the features that make roadmaps evolve

## Phase Details

### Phase 1: Full Platform Overhaul
**Goal**: Users experience a production-grade career guidance app -- AI-generated roadmaps via Vertex AI, polished glassmorphism UI, secure payments, expert marketplace with real filtering, and an admin dashboard with analytics
**Depends on**: Nothing (first phase)
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08, AI-09, AI-10, ADAPT-06, EXP-01, EXP-02, EXP-03, PAY-01, PAY-02, PAY-03, PAY-04, SEC-01, SEC-02, SEC-03, SEC-04, ADM-01, ADM-02, ADM-03
**Success Criteria** (what must be TRUE):
  1. User completes the onboarding wizard, triggers AI analysis, sees animated 4-step progress storytelling, and receives a multi-phase roadmap with real resources displayed as a vertical timeline with connected nodes
  2. User browses experts with domain filters, price range sliders, and rating thresholds, views expert profiles with full skill lists and reviews, and completes a consultation booking with Razorpay payment that is verified server-side
  3. All screens render with glassmorphism design (frosted glass cards, gradient mesh backgrounds), dark/light mode toggle works consistently, skeleton loading replaces all spinner states, and error/empty states show polished guidance
  4. Admin can view platform analytics (total users, active roadmaps, consultations this week), approve/reject expert applications, and moderate flagged reviews
  5. Skill gap analysis displays confidence scores as colored badges, Firebase security rules reject unauthorized access to all 5 collections, and AI endpoints enforce per-user rate limits
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — FastAPI backend + Vertex AI 4-step prompt chain with auth, rate limiting, and Firestore integration
- [ ] 01-02-PLAN.md — Flutter UI overhaul: glassmorphism design system, all 14 screens, onboarding wizard, timeline, animations, dark mode
- [ ] 01-03-PLAN.md — Integration + payment hardening + security rules + admin dashboard analytics
**UI hint**: yes

### Phase 2: Adaptive Intelligence
**Goal**: Roadmaps become living documents that auto-adjust when learners stall, remember context across sessions, and improve through expert annotations
**Depends on**: Phase 1
**Requirements**: ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-04, ADAPT-05, EXP-04, EXP-05
**Success Criteria** (what must be TRUE):
  1. When a user's milestone progress is unchanged for 14+ days, the system triggers a replan that generates an adjusted roadmap version with a clear replan reason -- previous versions are preserved, not overwritten
  2. Returning users receive AI analysis that references their history, struggle patterns, and pace trends from previous sessions -- the AI demonstrably "remembers" the learner
  3. An expert can annotate specific milestones on a learner's roadmap, and those annotations are incorporated into the next AI replan, producing visibly different recommendations than a replan without expert input
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Full Platform Overhaul | 1/3 | In Progress|  |
| 2. Adaptive Intelligence | 0/2 | Not started | - |
