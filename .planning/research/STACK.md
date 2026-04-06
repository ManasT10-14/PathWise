# Technology Stack

**Project:** PathWise - AI-powered Career Guidance Platform
**Researched:** 2026-04-07
**Scope:** Additive stack for Vertex AI backend, UI overhaul, and payment hardening on an existing Flutter + Firebase app

---

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

**State management note:** The app currently uses Provider (^6.1.2) with an InheritedWidget service locator pattern. Riverpod 3.0 is the 2026 gold standard but migrating mid-project adds risk for zero user-facing value. **Keep Provider.** Riverpod is a v2 consideration.

---

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

**Gemini 2.5 Flash key specs:**
- Input: 1,048,576 tokens max
- Output: 65,535 tokens max
- Supports: Structured output, function calling, system instructions, thinking mode, context caching
- Does NOT support: Gemini Live API, C2PA
- Thinking budget is controllable per-request to balance quality vs latency vs cost
- Structured output works natively with Pydantic models via `response_schema` parameter in google-genai SDK

**Cost estimation for PathWise:**
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

**Why NOT use glassmorphism packages:**

| Package | Status | Recommendation |
|---------|--------|----------------|
| `glassmorphism` (3.0.0) | Last updated August 2021 -- 5 years unmaintained | DO NOT USE |
| `liquid_glass_widgets` (0.7.3) | Very new (pre-1.0), 0.x version, published hours ago | TOO EARLY for production |
| `glassmorphic_ui_kit` | Low adoption | NOT WORTH the dependency |

**Instead:** Build glassmorphism effects with Flutter's built-in `BackdropFilter` + `ImageFilter.blur` + `ClipRRect`. This approach:
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

---

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

---

## Python Backend Installation

```bash
# Create virtual environment
python3.12 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Core
pip install fastapi==0.135.3 "uvicorn[standard]==0.41.0"

# AI
pip install google-genai==1.70.0

# Firebase
pip install firebase-admin==7.3.0

# Payment
pip install razorpay==2.0.1

# Data validation & config (FastAPI pulls pydantic, but pin explicitly)
pip install pydantic==2.12.5 pydantic-settings==2.13.1

# Production utilities
pip install structlog==25.5.0 slowapi==0.1.9 httpx==0.28.1

# Freeze
pip freeze > requirements.txt
```

## Flutter pubspec.yaml Additions

```yaml
dependencies:
  # Existing deps remain unchanged...

  # NEW: HTTP client for FastAPI backend
  dio: ^5.9.2

  # NEW: Animation system for UI overhaul
  flutter_animate: ^4.5.2
  lottie: ^3.3.2

  # NEW: Typography
  google_fonts: ^6.2.1

  # NEW: Loading states
  shimmer: ^3.0.0
```

## Vertex AI Client Initialization

```python
from google import genai
from google.genai.types import HttpOptions

# For Vertex AI (not the free Gemini API)
client = genai.Client(
    vertexai=True,
    project="pathwise-aedc5",
    location="us-central1",
    http_options=HttpOptions(api_version="v1"),
)

# Structured output with Pydantic
from pydantic import BaseModel

class SkillGapAnalysis(BaseModel):
    current_skills: list[str]
    required_skills: list[str]
    gap_skills: list[str]
    confidence: float

response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents="Analyze skill gaps for...",
    config={
        "response_mime_type": "application/json",
        "response_schema": SkillGapAnalysis,
    },
)
result = response.parsed  # Returns SkillGapAnalysis instance
```

---

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
