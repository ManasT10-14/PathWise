# Research Summary: PathWise AI Career Guidance Platform

**Domain:** AI-powered adaptive career guidance + expert consultation marketplace
**Researched:** 2026-04-07
**Overall confidence:** HIGH

## Executive Summary

PathWise operates at the intersection of three existing markets -- AI career guidance (roadmap.sh, Coursera), mentorship platforms (ADPList, Preply), and career assessment tools (Mindler, Unstop) -- but no existing product occupies all three simultaneously. The planned upgrade from a local keyword-matching stub to Vertex AI Gemini 2.5 Flash is the critical unlock: without semantic skill gap analysis, the app cannot deliver on its core promise of personalized, adaptive career roadmaps.

The existing codebase is well-structured for the upgrade. The `AiRoadmapService` was explicitly designed as a swap-ready placeholder, the `AiAnalysis` return type defines a clean interface contract, and the service-locator architecture (`AppServices` InheritedWidget) means replacing the local stub with an HTTP client is a single-point change. The Firestore data model (`Roadmap` with `stageProgress`, `structuredStages` getter) already supports the progress tracking needed for dynamic replanning triggers.

The UI layer is the primary weakness. Every screen uses stock Material Design with no visual polish -- plain `TextField` widgets, bare `Slider` controls, default `ListTile` components, and a single `CircularProgressIndicator` loading state. For a portfolio piece targeting the Indian tech market, this needs a dramatic upgrade. Glassmorphism with `BackdropFilter`, micro-interactions via `AnimatedContainer`/`AnimatedOpacity`, and a multi-step onboarding wizard will transform the perceived quality without requiring architectural changes.

The three most impactful differentiators -- dynamic replanning, learner memory, and expert-AI feedback loops -- form a reinforcing system. Replanning detects stalls, memory provides context across sessions, and expert annotations improve the AI's recommendations. This combination is genuinely unique in the market. However, these features require time-series data (progress tracked over weeks) to function, which dictates a phased rollout where intelligence features ship after the data pipeline is established.

## Key Findings

**Stack:** FastAPI + Vertex AI Gemini 2.5 Flash (4-step prompt chain) replacing local keyword stub, Flutter frontend with glassmorphism UI overhaul, existing Firebase/Firestore infrastructure unchanged.

**Architecture:** Sequential prompt chain (Goal Analyzer -> Skill Gap Detector -> Roadmap Planner -> Resource Curator) with structured JSON output at each step. Shared Firestore between Flutter app and FastAPI backend. Learner memory as Firestore sub-collection.

**Critical pitfall:** The AI analysis takes 6-8 seconds (4 sequential Vertex AI calls). Without a progress storytelling UI that communicates each step, users will abandon during the most critical moment of the product experience. This must ship in Phase 1 alongside the backend integration.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Phase 1: AI Backend + UI Foundation** - Ship the core intelligence and first-impression UI together
   - Addresses: T1 (skill gap analysis), T2 (roadmap generation), T4 (onboarding wizard), T6 (loading states), D4 (glassmorphism), D6 (progress storytelling), T7 (dark mode)
   - Avoids: Shipping AI without UX polish (users see raw JSON latency) or shipping UI without AI (pretty shell, empty core)
   - Rationale: The AI backend and the UI overhaul must ship together. An AI that returns results into an ugly UI wastes the "wow" moment. A beautiful UI that still runs keyword matching wastes the visual investment.

2. **Phase 2: Progress Intelligence + Marketplace Polish** - Build the feedback loops
   - Addresses: T3 (progress tracking), D7 (timeline visualization), T5 (expert filter), T8 (payment verification), D8 (confidence scores)
   - Avoids: Building replanning before progress data exists
   - Rationale: Phase 1 creates roadmaps. Phase 2 makes them trackable and visible. This phase establishes the data pipeline (progress updates over time) that Phase 3's replanning engine requires.

3. **Phase 3: Adaptive Intelligence** - The moat features
   - Addresses: D1 (dynamic replanning), D2 (learner memory), D3 (expert-AI feedback loop)
   - Avoids: Premature optimization -- these features need real user data to test and tune
   - Rationale: Replanning needs weeks of progress data to trigger. Memory needs multiple sessions. Expert feedback needs active consultations. These cannot be meaningfully built or tested without Phase 1+2 infrastructure and real usage.

**Phase ordering rationale:**
- Phase 1 unlocks the value prop (AI) and the first impression (UI). Without both, the app has neither substance nor style.
- Phase 2 creates the data flywheel (users tracking progress) that Phase 3's intelligence features consume.
- Phase 3 builds the moat (no competitor has these features) but requires real-world data to validate.

**Research flags for phases:**
- Phase 1: Standard patterns, well-documented. Gemini structured output and Flutter BackdropFilter both have clear implementation guides.
- Phase 2: Standard patterns for progress tracking and marketplace filtering. No research risks.
- Phase 3: **Likely needs deeper research** -- replanning trigger thresholds (14 days? 7 days? context-dependent?), learner memory schema optimization, and expert annotation UX will need iteration based on real usage data.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Gemini 2.5 Flash, FastAPI, Flutter, Firestore all well-documented with Context7 / official docs. No experimental tech. |
| Features | HIGH | Table stakes validated against roadmap.sh, Coursera, ADPList. Differentiators validated as genuinely absent from competitors. |
| Architecture | HIGH | 4-step prompt chain is a proven pattern. Shared Firestore is the existing architecture. Service swap is explicitly designed. |
| Pitfalls | MEDIUM | AI latency mitigation is well-understood. Replanning trigger tuning and learner memory schema are educated guesses that need real-world validation. |
| UI Patterns | HIGH | Glassmorphism, micro-interactions, and onboarding wizard patterns are mature and well-documented in Flutter. |

## Gaps to Address

- Replanning trigger thresholds need A/B testing with real users -- the 14-day stall detection in the PRD is a reasonable default but may need per-topic adjustment
- Learner memory storage volume -- at what point does accumulated context exceed Gemini's useful prompt window? May need summarization strategy
- Expert annotation UX -- how much friction can experts tolerate before they stop annotating? Needs design research during Phase 3
- Razorpay production approval process -- timeline and requirements for moving from test to production keys need verification
- Resource curation quality -- Gemini may hallucinate URLs. Need validation strategy (URL checking, fallback to curated list)
