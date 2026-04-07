"""Pathwise FastAPI application entry point.

Responsibilities:
  - Firebase Admin SDK initialization
  - Structlog JSON configuration
  - CORS and rate-limiting middleware
  - Router mounting (/api/v1/health, /api/v1/roadmaps)
  - Per-request correlation ID injection
"""

import uuid

import firebase_admin
import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.requests import Request
from starlette.responses import Response

from config import settings
from dependencies import limiter
from routers import health, payments, roadmaps, webhooks

# ---------------------------------------------------------------------------
# Structlog — JSON rendering for production, pretty-printing for dev
# ---------------------------------------------------------------------------
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(
        __import__("logging").getLevelName(settings.log_level)
    ),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

log = structlog.get_logger(__name__)

# ---------------------------------------------------------------------------
# Firebase Admin SDK initialization
# ---------------------------------------------------------------------------
if not firebase_admin._apps:
    if settings.firebase_service_account:
        _cred = firebase_admin.credentials.Certificate(settings.firebase_service_account)
        firebase_admin.initialize_app(_cred)
        log.info("firebase_initialized", source="service_account_file")
    elif _sa_json := __import__("os").environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON"):
        # Railway/cloud: service account JSON passed as env var (no file upload)
        import json as _json, tempfile as _tmp
        _tf = _tmp.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
        _tf.write(_sa_json)
        _tf.close()
        _cred = firebase_admin.credentials.Certificate(_tf.name)
        firebase_admin.initialize_app(_cred)
        log.info("firebase_initialized", source="env_json")
    else:
        # Relies on GOOGLE_APPLICATION_CREDENTIALS env var (Application Default Credentials)
        firebase_admin.initialize_app()
        log.info("firebase_initialized", source="application_default_credentials")

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Pathwise API",
    version="1.0.0",
    description=(
        "AI-powered career guidance backend. "
        "Provides Gemini 2.5 Flash prompt-chain roadmap generation and Razorpay payment orchestration."
    ),
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Per-request correlation ID middleware
# ---------------------------------------------------------------------------
@app.middleware("http")
async def _inject_request_id(request: Request, call_next: object) -> Response:
    """Bind a unique request_id to the structlog context for every request."""
    request_id = str(uuid.uuid4())
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(request_id=request_id)
    response: Response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(health.router, prefix="/api/v1")
app.include_router(roadmaps.router, prefix="/api/v1")
app.include_router(payments.router, prefix="/api/v1")
app.include_router(webhooks.router, prefix="/api/v1")
