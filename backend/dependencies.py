"""FastAPI dependency providers for auth and rate limiting.

Exports:
  - get_current_user: Dependency that verifies Firebase ID tokens
  - limiter: slowapi Limiter instance for per-user rate limiting
"""

import firebase_admin.auth
import structlog
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

log = structlog.get_logger(__name__)

# HTTP Bearer scheme for extracting Authorization header tokens
_bearer = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    """Verify a Firebase ID token and return the decoded token payload.

    Raises HTTPException(401) for any authentication failure:
      - Invalid token
      - Expired token
      - Missing token
      - Any unexpected verification error
    """
    token = credentials.credentials
    try:
        decoded = firebase_admin.auth.verify_id_token(token)
        return decoded
    except firebase_admin.auth.InvalidIdTokenError as exc:
        log.warning("auth_invalid_token", error=str(exc))
        raise HTTPException(status_code=401, detail="Invalid authentication token") from exc
    except firebase_admin.auth.ExpiredIdTokenError as exc:
        log.warning("auth_expired_token")
        raise HTTPException(status_code=401, detail="Authentication token has expired") from exc
    except Exception as exc:
        log.error("auth_verification_failed", error=str(exc))
        raise HTTPException(status_code=401, detail="Authentication failed") from exc


def _rate_limit_key(request: Request) -> str:
    """Derive rate limit key from authenticated user UID, falling back to IP."""
    if hasattr(request.state, "user") and request.state.user:
        return request.state.user.get("uid", get_remote_address(request))
    return get_remote_address(request)


# Per-user rate limiter.  Uses the authenticated UID so limits are per-account
# rather than per-IP (important for users behind shared NAT).
limiter = Limiter(key_func=_rate_limit_key)
