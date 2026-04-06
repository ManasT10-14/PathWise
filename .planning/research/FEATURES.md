# Feature Landscape

**Domain:** AI-powered career guidance + expert consultation marketplace (Indian student/professional market)
**Researched:** 2026-04-07
**Overall confidence:** HIGH -- grounded in existing codebase analysis, competitive landscape research, and established UI/UX patterns

---

## Table Stakes

Features users expect from any AI career guidance / adaptive learning platform in 2025-2026. Missing any of these means users leave for roadmap.sh, Coursera, or ChatGPT.

| # | Feature | Why Expected | Complexity | Depends On | Notes |
|---|---------|--------------|------------|------------|-------|
| T1 | **Semantic skill gap analysis** | roadmap.sh and Coursera already offer AI-driven skill assessment. Keyword matching (current stub) feels broken by comparison. Users who paste a resume and get shallow gaps will not return. | Medium | FastAPI backend, Vertex AI integration | Replace `AiRoadmapService` keyword matching with Gemini 2.5 Flash 4-step prompt chain. Must detect proficiency *levels* (not just presence/absence) and reason about prerequisites. |
| T2 | **Personalized multi-phase roadmap generation** | Every competitor (roadmap.sh, Coursera, LinkedIn Learning) generates learning paths. Pathwise's current 3-stage beginner/intermediate/advanced is too coarse. Users expect phases with concrete tasks, deadlines, and curated resources. | Medium | T1 (skill gap output feeds roadmap planner) | Phases should have 4-8 milestones each with estimated hours, not just labels. Resource curation step must link to real URLs (free preferred -- Kaggle, freeCodeCamp, MDN, official docs). |
| T3 | **Real-time progress tracking with visual feedback** | Duolingo, roadmap.sh, and every learning platform show clear progress. Current implementation is a bare `Slider` with no visual context -- no percentage, no completion state, no celebration. Users need to *feel* progress. | Low-Med | Roadmap model exists, UI overhaul | Replace sliders with progress rings/bars per milestone. Add stage completion states (not started / in progress / complete). Show overall roadmap completion percentage. |
| T4 | **Polished onboarding wizard** | 80% of users who don't complete onboarding never return (industry benchmark). Current `AiGuidanceScreen` is a single long scrolling form with `TextField` widgets -- not engaging for first-time users. | Medium | None (frontend only, existing screen refactor) | Convert to multi-step wizard with progress indicator. Steps: (1) "What's your goal?" (2) "What do you already know?" with skill chips (3) Resume upload / paste (4) Constraints (hours/week, timeline). Each step should feel like a conversation, not a form. |
| T5 | **Expert marketplace with search and filter** | Current `ExpertsScreen` is a flat list with no filtering. Users expect to filter by domain, price range, rating, and availability -- standard marketplace UX from Preply, ADPList, Unstop. | Low-Med | Existing expert data model | Add domain filter chips, price range slider, rating threshold, sort by (rating, price, reviews). Consider search by name/skill. |
| T6 | **Loading states and error handling** | Current screens show `CircularProgressIndicator` with no context. AI analysis will take 6-8 seconds (4 Vertex AI calls). Users will think the app is broken without progress communication. | Low | None | Skeleton screens for lists. Animated progress indicator with step labels during AI analysis ("Analyzing your skills...", "Detecting gaps...", "Building roadmap...", "Curating resources..."). Error states with retry actions. |
| T7 | **Dark mode support** | 81.9% of Android users use dark mode. Not supporting it makes the app feel amateur, especially for a portfolio piece targeting tech-savvy Indian students. | Low | Theme system | Flutter's `ThemeData` makes this straightforward. Define light and dark color schemes. Use `colorScheme.surface` / `onSurface` consistently (current code already uses `theme.colorScheme`). |
| T8 | **Server-side payment verification** | Current Razorpay integration is client-only -- no order creation server-side, no signature verification, no webhooks. Any payment-handling app without server verification is insecure and will fail Razorpay's production review. | Medium | FastAPI backend | FastAPI endpoint for order creation, signature verification with `razorpay_signature`, webhook handler for `payment.captured` event. |

---

## Differentiators

Features that set Pathwise apart from roadmap.sh (static paths), ADPList (no AI), Coursera (no adaptation), and ChatGPT (no state/memory). These create the "wow factor" and competitive moat.

| # | Feature | Value Proposition | Complexity | Depends On | Notes |
|---|---------|-------------------|------------|------------|-------|
| D1 | **Dynamic replanning engine** | No competitor adapts roadmaps when learners stall. roadmap.sh paths are static. ChatGPT has no memory. When a user's `stageProgress` on any milestone hasn't changed in 14+ days, Pathwise detects the stall and triggers Gemini to replan -- compressing timelines, reordering prerequisites, swapping in easier resources, and explaining *why*. This is the single highest-impact differentiator. | High | T1, T2, T3 (needs gap analysis + roadmap + progress data) | Trigger conditions: (1) stageProgress unchanged > 14 days, (2) user explicitly requests replan, (3) expert annotates difficulty. Store `lastProgressUpdate` timestamp per stage. Replan creates a *new* roadmap version with `replan_reason` field -- do NOT overwrite history. |
| D2 | **Learner memory system** | ChatGPT forgets everything between sessions. Pathwise remembers: analysis history, struggle patterns (which topics caused stalls), pace trends (hours/week actually spent vs planned), skill evolution over time. Enables the AI to say "Last time you struggled with calculus prerequisites before ML -- let's address that first this time." | High | T1 (analysis results), T3 (progress data) | Firestore sub-collection `users/{uid}/learner_memory` storing: `analysisHistory[]`, `strugglePatterns[]` (topic + duration stuck + resolution), `paceTrends` (planned vs actual velocity), `skillSnapshots[]` (timestamped skill inventories). FastAPI reads this context and includes it in prompt chain. |
| D3 | **Expert-AI feedback loop** | Unique to Pathwise. No platform combines AI roadmap generation with human expert annotation that improves future AI output. Experts see the AI-generated roadmap during consultation, annotate it ("This resource is outdated", "Add system design here", "Skip this -- not relevant for Indian market"), and those annotations are stored and fed back into the AI's next replan/generation for that user. | High | T1, T2, D1, Expert interface | Expert annotation UI on `ExpertHomeScreen`: view learner's active roadmap, add inline comments per milestone, flag resources, suggest additions. Annotations stored in Firestore, included in replan prompt context. Future: aggregate popular annotations across users to improve prompts globally. |
| D4 | **Glassmorphism + layered depth UI system** | Creates the "mind-blowing first impression" the PRD demands. Frosted glass cards, layered depth, translucent surfaces with blur give the app a premium feel that standard Material Design cannot match. Apple's Liquid Glass made this aesthetic mainstream. Combined with the functional depth of AI features, it signals "this is not a student project." | Medium | None (pure frontend) | Use `BackdropFilter` with `ImageFilter.blur(sigmaX: 10, sigmaY: 10)` wrapped in `ClipRRect`. Keep blur sigma moderate (6-12) for performance. Apply to: floating action cards on home screen, roadmap stage cards, expert profile headers, modal bottom sheets. Do NOT apply to every surface -- strategic use on 3-4 key elements. Gradient mesh backgrounds behind glass cards. Test on low-end Android devices. |
| D5 | **Micro-interactions and motion design** | Animations transform a functional app into a delightful one. Duolingo's micro-interactions drive 60% higher engagement. In Pathwise: progress ring fill animations when updating milestones, card entrance animations on roadmap detail, celebration burst when completing a stage, smooth page transitions between wizard steps. | Medium | T3, T4, D4 | Use Flutter's `AnimatedContainer`, `AnimatedOpacity`, `Hero` transitions. 300-500ms duration for major transitions, 50-200ms for micro-interactions. Physics-based `SpringSimulation` for bouncy feedback on progress saves. Rive for celebration animation on stage completion. Avoid over-animating -- every animation must have functional purpose. |
| D6 | **AI analysis progress storytelling** | During the 6-8 second AI analysis wait, show a multi-step animated progress indicator that tells the user what's happening: "Analyzing your background..." -> "Identifying skill gaps..." -> "Building your roadmap..." -> "Curating resources...". This transforms dead wait time into engagement and trust-building. Competitors show a spinner. | Low-Med | T1, T6 | `Stepper` or custom widget with animated transitions between 4 steps, each matching a prompt chain step. Use `AnimatedSwitcher` for text transitions. Optional: show a live-updating preview of extracted skills as they arrive (if streaming is feasible). |
| D7 | **Roadmap timeline visualization** | Current roadmap display is a flat list of cards with sliders. Replace with a vertical timeline with connected nodes, milestone cards, and visual progression. Inspired by roadmap.sh's visual roadmaps but interactive and personalized. Shows dependency flow, current position, and what's next at a glance. | Medium | T2, T3, D4 | Vertical timeline with: (1) nodes (completed=filled, current=pulsing, future=outlined), (2) connecting lines with gradient from completed to future, (3) milestone cards attached to each node, (4) expandable task lists within milestones. Use `CustomPainter` for the timeline spine. |
| D8 | **Confidence scores on skill gaps** | Instead of a flat list of "skills you're missing," show how confident the AI is about each gap: "Python (95% -- critical for ML)", "Docker (40% -- you have some exposure)". Gives users a sense of nuance that flat gap lists cannot convey. No competitor does this. | Low | T1 (Gemini structured output) | Include `confidenceScores: Map<String, double>` in Gemini response schema. Display as colored badges or small progress indicators next to each gap. |

---

## Anti-Features

Features to explicitly NOT build. Each was considered and rejected with rationale.

| # | Anti-Feature | Why Avoid | What to Do Instead |
|---|--------------|-----------|-------------------|
| A1 | **Resume PDF parsing with OCR** | High complexity (PDFium, Tesseract, or cloud OCR), inconsistent results across PDF formats, not worth the engineering time for MVP. Users can paste text. | Keep `.txt/.md` upload. Add clear copy-paste instructions. Defer PDF to v2 when user demand is validated. |
| A2 | **Streak gamification system** | Tempting because Duolingo proves streaks work, but Pathwise is not a daily-use app. Career roadmaps operate on weekly/biweekly cadence. Forcing daily engagement creates guilt, not growth. Streaks also require push notification infrastructure. | Instead: weekly progress check-ins with gentle nudges. Show "weeks active" and "milestones completed" as achievement markers. No punishment for missing days. |
| A3 | **AI interview simulation** | Separate product scope entirely. Requires voice processing, real-time LLM streaming, scoring rubrics. Would double the backend complexity for a tangential feature. | Link to external tools (Pramp, InterviewBit) as roadmap resources. Focus Pathwise on the *preparation path*, not the interview itself. |
| A4 | **In-app chat/messaging between users and experts** | Requires real-time messaging infrastructure (WebSocket, FCM), message storage, read receipts, moderation. Massive scope for marginal value when consultations already exist. | Consultations are booked sessions with defined scope. For async communication, link to expert's external contact (email/LinkedIn) post-consultation. |
| A5 | **Social features / community feed** | Community features (posts, comments, likes) require moderation, content policy, abuse prevention. Distracts from the core value prop of personalized guidance. ADPList does community; Pathwise should not compete there. | Show aggregate stats ("X learners on this path") for social proof without social features. |
| A6 | **Spaced repetition engine** | Requires a knowledge-question bank, scheduling algorithm (SM-2 or similar), and quiz UI. Tangential to career roadmap guidance -- Anki and similar tools own this space. | Suggest spaced repetition tools as roadmap resources for appropriate milestones. |
| A7 | **Graph database for skill dependencies** | Firestore is already in use and sufficient for MVP. A graph DB (Neo4j) adds operational complexity, a separate query language, and deployment burden for a benefit (prerequisite traversal) that Gemini can reason about in prompts. | Encode prerequisite reasoning in the Skill Gap Detector prompt. Gemini reasons about "you need X before Y" without a formal graph. If this becomes insufficient at scale, graph DB is a v3 concern. |
| A8 | **Multi-language / localization** | Indian students/professionals in tech operate in English. Adding Hindi/regional language support adds translation burden, LLM prompt complexity, and testing overhead. | English only for MVP. If user demand emerges, add i18n framework in v2. |
| A9 | **Overengineered AI agent system** | The PRD already wisely chose prompt chaining over LangGraph. Do not be tempted to add agent loops, tool-calling, RAG pipelines, or vector stores. A 4-step prompt chain with structured output handles the use case. Overengineering burns $12,000/month in tokens for what $40 of API calls achieves. | Keep the sequential prompt chain. Each step has a focused system prompt, structured JSON output, and deterministic temperature. If conditional branching is needed later, upgrade to a directed graph -- not a full agent framework. |
| A10 | **Voice-based interaction / voice coach** | Requires speech-to-text, NLU, TTS -- massive complexity for a guidance app where text input is natural and sufficient. | Text-based wizard and chat are the correct modality for career guidance. |

---

## Feature Dependencies

```
T1 (Semantic Skill Gap Analysis)
  |
  +---> T2 (Personalized Roadmap Generation)
  |       |
  |       +---> T3 (Progress Tracking with Visual Feedback)
  |       |       |
  |       |       +---> D1 (Dynamic Replanning Engine)
  |       |       |       |
  |       |       |       +---> D3 (Expert-AI Feedback Loop)
  |       |       |
  |       |       +---> D2 (Learner Memory System)
  |       |
  |       +---> D7 (Roadmap Timeline Visualization)
  |       |
  |       +---> D8 (Confidence Scores on Gaps)
  |
  +---> D6 (AI Analysis Progress Storytelling)

T4 (Polished Onboarding Wizard) -- independent, frontend only
T5 (Expert Search & Filter) -- independent, frontend only
T6 (Loading States & Error Handling) -- independent, applies everywhere
T7 (Dark Mode) -- independent, theme system
T8 (Server-side Payment Verification) -- depends on FastAPI backend existence

D4 (Glassmorphism UI System) -- independent, applies to all screens
D5 (Micro-interactions & Motion) -- partially depends on D4 for context
```

**Critical path:** T1 -> T2 -> T3 -> D1 is the backbone. Everything else is parallelizable.

---

## MVP Recommendation

### Build First (Phase 1 -- Core Intelligence + UI Foundation)

1. **T1: Semantic skill gap analysis** -- The entire app's value prop depends on this. Without real AI analysis, Pathwise is just a form that returns hardcoded strings. This is the unlock.
2. **T2: Personalized roadmap generation** -- Immediate follow-on from T1. Together they deliver the core promise: "I told the app my goals, and it gave me a real plan."
3. **T4: Polished onboarding wizard** -- First impression. The wizard IS the product for new users. If onboarding is a boring form, users never reach the roadmap.
4. **T6: Loading states and error handling** -- T1+T2 introduce 6-8 second latency. Without progress feedback, users will abandon during the most critical moment.
5. **D6: AI analysis progress storytelling** -- Directly mitigates T6's wait time problem. Low complexity, high impact.
6. **D4: Glassmorphism UI system** -- Design foundation for everything else. Build the theme/component library early so all subsequent screens inherit the visual language.
7. **T7: Dark mode** -- Trivial if done alongside D4 during theme creation. Much harder to retrofit later.

### Build Second (Phase 2 -- Intelligence Loop + Marketplace)

8. **T3: Progress tracking with visual feedback** -- Requires roadmap data to exist (from Phase 1 users).
9. **D7: Roadmap timeline visualization** -- Premium display layer on top of T3.
10. **T5: Expert search and filter** -- Marketplace polish.
11. **T8: Server-side payment verification** -- Required before any real-money transactions.
12. **D8: Confidence scores** -- Low-effort addition to T1's output schema.

### Build Third (Phase 3 -- Adaptive Intelligence)

13. **D1: Dynamic replanning** -- Requires real progress data accumulated over weeks. Cannot test meaningfully until users have been tracking progress (Phase 2).
14. **D2: Learner memory** -- Requires multiple analysis sessions per user. Needs time for data accumulation.
15. **D3: Expert-AI feedback loop** -- Requires both replanning (D1) and expert consultations to be active. Highest complexity, highest differentiation.

### Defer

- **D5: Micro-interactions and motion** -- Sprinkle throughout all phases rather than as a discrete feature. Add entrance animations when building each screen, celebration animation when building D7, etc.

---

## Competitive Positioning Summary

| Pathwise Feature | roadmap.sh | Coursera | ADPList | ChatGPT | Unstop |
|-----------------|------------|----------|---------|---------|--------|
| AI skill gap analysis | Yes (premium) | Partial | No | Yes (no state) | No |
| Personalized roadmap | Yes (premium) | Yes (course-bound) | No | Yes (no state) | No |
| Dynamic replanning | **No** | **No** | **No** | **No** | **No** |
| Learner memory | **No** | Partial (course progress) | **No** | **No** | **No** |
| Expert consultation | **No** | **No** | Yes (free) | **No** | **No** |
| Expert-AI feedback | **No** | **No** | **No** | **No** | **No** |
| Payment integration | Premium sub | Course purchase | Free | Subscription | Free |
| Prerequisite reasoning | **No** | Course prereqs | **No** | Partial | **No** |

**Pathwise's unique intersection:** Dynamic replanning + learner memory + expert-AI feedback loop. No existing platform occupies all three.

---

## Sources

- [roadmap.sh Premium Features](https://roadmap.sh/premium) -- competitor feature analysis
- [AI Skill Gap Analysis Software 2026 (DISCO)](https://www.disco.co/blog/ai-skill-gap-analysis-software-2026) -- market expectations
- [9 Mobile App Design Trends 2026 (UXPilot)](https://uxpilot.ai/blogs/mobile-app-design-trends) -- UI pattern trends
- [15 Mobile App Design Trends 2026 (Designveloper)](https://www.designveloper.com/blog/mobile-app-design-trends/) -- UI/UX best practices
- [Duolingo Gamification Secrets (Orizon)](https://www.orizon.co/blog/duolingos-gamification-secrets) -- engagement pattern analysis
- [Mobile Onboarding UX Best Practices 2026 (DesignStudioUIUX)](https://www.designstudiouiux.com/blog/mobile-app-onboarding-best-practices/) -- onboarding patterns
- [Flutter Glassmorphism Implementation (Vibe Studio)](https://vibe-studio.ai/insights/implementing-glassmorphism-effects-in-flutter-uis) -- technical feasibility
- [Adaptive Learning Platforms 2025 (FlowSparks)](https://www.flowsparks.com/resources/adaptive-learning-technology) -- adaptive learning features
- [Knowledge Graphs in Learning (Training Industry)](https://trainingindustry.com/articles/artificial-intelligence/smarter-learning-personalization-at-scale-with-ai-driven-knowledge-graphs/) -- learner memory architecture
- [AI Overengineering Trap (Trace3)](https://blog.trace3.com/the-ai-overengineering-trap) -- anti-pattern validation
- [Push Notification Strategies 2025 (Upshot.ai)](https://upshot-ai.medium.com/push-notification-strategies-to-increase-app-engagement-in-2025-a8461e4e8ad8) -- engagement strategy
- [Preply AI-Powered Features](https://preply.com/en/blog/preply-announces-new-ai-powered-features-to-guide-the-future-of-personalized-learning-in-a-human-ai-world/) -- human+AI hybrid model validation
- [Career Guidance Platforms India 2025 (CareerPlanB)](https://careerplanb.co/best-career-counseling-platforms-india/) -- India market context
