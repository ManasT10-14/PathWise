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
