"""Pathwise FastAPI application entry point.

Responsibilities:
  - Firebase Admin SDK initialization
  - Structlog JSON configuration
  - CORS and rate-limiting middleware
  - Router mounting (/api/v1/health, /api/v1/roadmaps)
  - Per-request correlation ID injection
"""

# ---------------------------------------------------------------------------
# MUST RUN FIRST: Set up GCP credentials from env var before any Google SDK
# imports. Railway/Render/etc. don't have GCP metadata server, so the
# google-genai SDK needs GOOGLE_APPLICATION_CREDENTIALS pointing to a file.
# ---------------------------------------------------------------------------
import json as _json
import os
import tempfile as _tmp

# Write credential JSON env vars to temp files so Google SDKs can read them.
# We store file paths for later use by Firebase and Vertex AI separately.
_firebase_creds_path = None
_vertex_creds_path = None

_sa_json = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON", "")
if _sa_json:
    _tf = _tmp.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
    _tf.write(_sa_json)
    _tf.close()
    _firebase_creds_path = _tf.name

_vtx_json = os.environ.get("VERTEX_AI_CREDENTIALS_JSON", "")
if _vtx_json:
    _vtx_tf = _tmp.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
    _vtx_tf.write(_vtx_json)
    _vtx_tf.close()
    _vertex_creds_path = _vtx_tf.name

# Set GOOGLE_APPLICATION_CREDENTIALS for the google-genai SDK (Vertex AI).
# Prefer dedicated Vertex AI creds; fall back to Firebase creds if same account.
if _vertex_creds_path:
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = _vertex_creds_path
elif _firebase_creds_path:
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = _firebase_creds_path

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
    elif _firebase_creds_path:
        # Use Firebase-specific credentials (not Vertex AI override)
        _cred = firebase_admin.credentials.Certificate(_firebase_creds_path)
        firebase_admin.initialize_app(_cred)
        log.info("firebase_initialized", source="firebase_env_json")
    elif _vertex_creds_path:
        # Fall back to Vertex AI creds if Firebase creds not separate
        _cred = firebase_admin.credentials.Certificate(_vertex_creds_path)
        firebase_admin.initialize_app(_cred)
        log.info("firebase_initialized", source="vertex_creds_fallback")
    else:
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
