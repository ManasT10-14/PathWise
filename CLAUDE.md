<!-- GSD:project-start source:PROJECT.md -->
## Project

**Pathwise**

Pathwise is a dual-pillar career guidance mobile platform that combines Vertex AI-powered adaptive learning roadmaps with a human expert consultation marketplace. Users define career goals, receive personalized skill-gap analysis powered by Gemini 2.5 Flash, track progress through phased roadmaps, and book paid consultations with verified domain experts. Built with Flutter + Firebase + FastAPI.

**Core Value:** Users get a personalized, continuously-adapting learning roadmap that evolves based on their progress, struggles, and expert feedback — not a static one-size-fits-all path.

### Constraints

- **AI Model**: Vertex AI Gemini 2.5 Flash only — user's choice, no LangGraph or other frameworks
- **Backend**: FastAPI (Python) — must integrate with existing Firebase via Admin SDK
- **Frontend**: Flutter 3.x — existing app, enhance don't rewrite from scratch
- **Database**: Firebase Firestore — user manages database setup
- **Payments**: Razorpay — already integrated, needs production hardening
- **Timeline**: Urgent — pack maximum scope into Phase 1
- **Platform**: Android-first (iOS/Web later)
- **Authentication**: Google Sign-In via Firebase Auth (existing)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Existing Stack (Already In Place -- Do Not Replace)
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | SDK ^3.11.4 | Mobile app framework |
| Firebase Core | ^3.8.1 | Backend-as-a-service |
| Firebase Auth | ^5.3.4 | Google Sign-In authentication |
| Cloud Firestore | ^5.5.1 | NoSQL database |
| Provider | ^6.1.2 | State management |
| razorpay_flutter | ^1.4.0 | Client-side payment SDK |
| Dart SDK | ^3.11.4 | Language runtime |
## Recommended Additions
### Backend Core (FastAPI + Vertex AI)
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Python | 3.12+ | Runtime | FastAPI 0.135.x requires 3.10+ minimum; 3.12 recommended for performance. 3.13/3.14 also supported but 3.12 has the widest library compatibility right now | HIGH |
| FastAPI | 0.135.3 | API framework | Async-native, auto-generated OpenAPI docs, Pydantic integration, excellent for AI service wrappers. Latest stable as of April 2026 | HIGH |
| Uvicorn | 0.41.0 | ASGI server | Standard FastAPI server. Install with `uvicorn[standard]` for uvloop + httptools performance boost. Python 3.10+ required since 0.40.0 | HIGH |
| google-genai | 1.70.0 | Vertex AI / Gemini SDK | **This is the new recommended SDK.** The old `google-cloud-aiplatform` generative AI modules are deprecated (June 2025) and will be removed June 2026. `google-genai` provides a unified interface for Gemini models on Vertex AI | HIGH |
| Pydantic | 2.12.5 | Data validation & structured output schemas | Core dependency of FastAPI. Used for request/response models AND Gemini structured output schemas (pass Pydantic models to `response_schema` parameter). Stable release; 2.13 is in beta | HIGH |
| pydantic-settings | 2.13.1 | Environment configuration | Load API keys, project IDs, model configs from .env files with type validation. Production/stable, released Feb 2026 | HIGH |
| firebase-admin | 7.3.0 | Server-side Firebase access | Read/write Firestore, verify Firebase Auth tokens from FastAPI. Latest release March 2026, supports Python 3.9-3.13 | HIGH |
| razorpay | 2.0.1 | Server-side payment processing | Create orders server-side, verify payment signatures with `client.utility.verify_payment_signature()`, handle webhooks with `client.utility.verify_webhook_signature()`. Latest release March 2026 | HIGH |
| structlog | 25.5.0 | Structured logging | JSON-structured logs for production. Async-friendly, processor pipeline for correlation IDs. Standard for FastAPI production deployments | MEDIUM |
| slowapi | 0.1.9 | API rate limiting | Rate limiter for FastAPI/Starlette. Production-proven at scale. Use Redis backend for production, in-memory for dev. Note: not actively releasing new versions but stable and widely used | MEDIUM |
| httpx | 0.28.1 | Async HTTP client | For any outbound HTTP calls the backend needs to make (e.g., fetching learning resources for roadmap curation). Sync + async dual API, HTTP/2 support | MEDIUM |
### AI/ML Layer
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Gemini 2.5 Flash | Model ID: `gemini-2.5-flash` | LLM for prompt chain | Best price/performance ratio. $0.30/M input tokens, $2.50/M output tokens. 1M token context window, 65K max output. Supports structured output, function calling, thinking mode. GA on Vertex AI, retirement date Oct 2026 | HIGH |
- Input: 1,048,576 tokens max
- Output: 65,535 tokens max
- Supports: Structured output, function calling, system instructions, thinking mode, context caching
- Does NOT support: Gemini Live API, C2PA
- Thinking budget is controllable per-request to balance quality vs latency vs cost
- Structured output works natively with Pydantic models via `response_schema` parameter in google-genai SDK
- 4-step prompt chain (goal analyzer + skill gap + roadmap planner + resource curator)
- Estimated ~2K input tokens + ~4K output tokens per chain execution
- At $0.30/$2.50 per million: approximately $0.01 per full analysis
- 1,000 analyses/month = ~$10/month in AI costs
### Flutter UI Additions
| Package | Version | Purpose | Why | Confidence |
|---------|---------|---------|-----|------------|
| flutter_animate | ^4.5.2 | Animation system | Chainable, declarative animations. Pre-built effects: fade, scale, slide, blur, shimmer, shake. No manual AnimationController management. Scroll-aware animations. The de facto Flutter animation library | HIGH |
| lottie | ^3.3.2 | Complex animations | After Effects animations rendered natively. Use for onboarding, loading states, empty states, success celebrations. Lazy render cache for performance | HIGH |
| dio | ^5.9.2 | HTTP client for API calls | Interceptors for auth token injection, request/response logging, retry logic, timeout handling. Required for production API communication with FastAPI backend. The app currently has no HTTP client -- only Firestore direct access | HIGH |
| google_fonts | latest | Typography | Access 1000+ Google Fonts. Bundle fonts as assets for offline use. Essential for the UI overhaul typography layer | MEDIUM |
| shimmer | ^3.0.0 | Skeleton loading | Loading placeholders while AI analysis runs (can take 5-10 seconds). Better UX than spinners for content-heavy screens | MEDIUM |
| cached_network_image | latest | Image caching | Cache expert profile photos, resource thumbnails. Note: original package unmaintained since Aug 2024 -- evaluate `cached_network_image_ce` community edition as alternative | LOW |
| Package | Status | Recommendation |
|---------|--------|----------------|
| `glassmorphism` (3.0.0) | Last updated August 2021 -- 5 years unmaintained | DO NOT USE |
| `liquid_glass_widgets` (0.7.3) | Very new (pre-1.0), 0.x version, published hours ago | TOO EARLY for production |
| `glassmorphic_ui_kit` | Low adoption | NOT WORTH the dependency |
- Has zero external dependencies
- Gives full control over blur sigma (sweet spot: 5-15)
- Performs well when bounded by `ClipRRect` (limit repaint area)
- Uses `RepaintBoundary` for caching static blurred backgrounds
- Is the approach recommended by Flutter community consensus
### Deployment Infrastructure
| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| Google Cloud Run | FastAPI hosting | Serverless containers, auto-scaling, pay-per-use. Natural fit since already on Google Cloud (Firebase). Single worker per instance is correct -- Cloud Run scales by adding instances | HIGH |
| Docker | Containerization | Required for Cloud Run. Use multi-stage builds with Python 3.12-slim base | HIGH |
| Cloud Build | CI/CD | Auto-deploy on push to GitHub. Native GCP integration, no extra service needed | MEDIUM |
| Secret Manager | Secrets storage | Store Razorpay keys, webhook secrets, API keys. Better than env vars for production | MEDIUM |
## Alternatives Considered
### Backend Framework
| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| API Framework | FastAPI | Firebase Cloud Functions | User's explicit choice. FastAPI gives more control, better for portfolio, better AI integration patterns. Cloud Functions have cold start issues for AI workloads |
| API Framework | FastAPI | Django REST Framework | Overkill ORM layer when Firestore is the database. FastAPI is faster for async AI workloads |
### AI SDK
| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Gemini SDK | google-genai | google-cloud-aiplatform (vertexai module) | **Deprecated.** GenAI modules removed June 2026. google-genai is the official replacement with full feature parity |
| Gemini SDK | google-genai | LangChain / LangGraph | User explicitly chose against this. 4-step sequential prompt chain doesn't need graph complexity. Direct SDK calls are simpler, faster, easier to debug |
| AI Framework | Direct SDK | PydanticAI | Extra abstraction layer not justified for a 4-step chain. Direct google-genai + Pydantic structured output achieves the same with fewer dependencies |
### Flutter HTTP Client
| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| HTTP Client | Dio | http (dart:io) | Too minimal -- no interceptors, no retry, no request cancellation. Dio provides auth token injection, logging, timeout, and error handling out of the box |
| HTTP Client | Dio | Retrofit + Dio | Over-engineering for the number of endpoints. Retrofit code-gen adds build complexity for marginal benefit on a small API surface |
### State Management
| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| State Mgmt | Provider (keep existing) | Riverpod 3.0 | App already uses Provider with 8 services. Migration would touch every screen for zero user-facing improvement. Riverpod is better, but switching mid-project is the wrong time |
| State Mgmt | Provider (keep existing) | BLoC 9.0 | Even more boilerplate than Riverpod migration. Only justified for enterprise audit requirements |
### Animation
| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Animation | flutter_animate | Manual AnimationController | 10x more boilerplate, error-prone dispose management. flutter_animate wraps it all declaratively |
| Animation | flutter_animate + Lottie | Rive | Rive has a learning curve and requires Rive editor. Lottie files are more abundant (LottieFiles marketplace) and After Effects is more widely known |
## Python Backend Installation
# Create virtual environment
# venv\Scripts\activate   # Windows
# Core
# AI
# Firebase
# Payment
# Data validation & config (FastAPI pulls pydantic, but pin explicitly)
# Production utilities
# Freeze
## Flutter pubspec.yaml Additions
## Vertex AI Client Initialization
# For Vertex AI (not the free Gemini API)
# Structured output with Pydantic
## Version Verification Sources
| Technology | Source | Verified Date |
|------------|--------|---------------|
| google-genai 1.70.0 | [PyPI](https://pypi.org/project/google-genai/) | 2026-04-07 |
| FastAPI 0.135.3 | [GitHub Releases](https://github.com/fastapi/fastapi/releases) | 2026-04-07 |
| Uvicorn 0.41.0 | [PyPI](https://pypi.org/project/uvicorn/) | 2026-04-07 |
| Pydantic 2.12.5 | [PyPI](https://pypi.org/project/pydantic/) | 2026-04-07 |
| pydantic-settings 2.13.1 | [PyPI](https://pypi.org/project/pydantic-settings/) | 2026-04-07 |
| firebase-admin 7.3.0 | [PyPI](https://pypi.org/project/firebase-admin/) | 2026-04-07 |
| razorpay 2.0.1 | [PyPI](https://pypi.org/project/razorpay/) | 2026-04-07 |
| structlog 25.5.0 | [PyPI](https://pypi.org/project/structlog/) | 2026-04-07 |
| slowapi 0.1.9 | [PyPI](https://pypi.org/project/slowapi/) | 2026-04-07 |
| httpx 0.28.1 | [PyPI](https://pypi.org/project/httpx/) | 2026-04-07 |
| flutter_animate 4.5.2 | [pub.dev](https://pub.dev/packages/flutter_animate) | 2026-04-07 |
| lottie 3.3.2 | [pub.dev](https://pub.dev/packages/lottie) | 2026-04-07 |
| dio 5.9.2 | [pub.dev](https://pub.dev/packages/dio) | 2026-04-07 |
| Gemini 2.5 Flash | [Vertex AI Docs](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash) | 2026-04-07 |
| Vertex AI SDK deprecation | [Migration Guide](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk) | 2026-04-07 |
| Gemini 2.5 Flash pricing | [Vertex AI Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) | 2026-04-07 |
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
