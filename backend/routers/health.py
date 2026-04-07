"""Health check router.

Provides a simple liveness probe endpoint for Cloud Run health checks
and monitoring systems.
"""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health", summary="Liveness probe")
async def health_check() -> dict:
    """Return service health status.

    Used by Cloud Run, load balancers, and uptime monitors.
    No authentication required — this endpoint is intentionally public.
    """
    return {"status": "ok", "version": "1.0.0"}


@router.get("/debug/vertex", summary="Test Vertex AI connection")
async def debug_vertex() -> dict:
    """Quick test of Vertex AI connectivity. Returns full error if it fails."""
    import os
    import traceback

    info = {
        "gcp_project": os.environ.get("GCP_PROJECT_ID", "NOT SET"),
        "has_vertex_creds": bool(os.environ.get("VERTEX_AI_CREDENTIALS_JSON")),
        "has_firebase_creds": bool(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")),
        "google_app_creds_set": bool(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")),
        "gemini_api_key_set": bool(os.environ.get("GEMINI_API_KEY")),
    }

    try:
        from services.gemini_client import MODEL, client
        info["model"] = MODEL
        info["client_type"] = "vertex" if hasattr(client, '_project') else "api_key"

        # Try a minimal generation
        response = client.models.generate_content(
            model=MODEL,
            contents="Say hello in one word.",
        )
        info["status"] = "SUCCESS"
        info["response"] = response.text[:100] if response.text else "empty"
    except Exception as e:
        info["status"] = "FAILED"
        info["error"] = str(e)
        info["error_type"] = type(e).__name__
        info["traceback"] = traceback.format_exc()[-500:]

    return info
