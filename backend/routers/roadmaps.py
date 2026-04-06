"""Roadmaps router — POST /api/v1/roadmaps/analyze.

The primary API endpoint for the Pathwise AI roadmap generation feature.
This endpoint replaces the local AiRoadmapService keyword-matching stub
with a real 4-step Gemini 2.5 Flash prompt chain.

Security properties:
  - Every request requires a valid Firebase ID token (SEC-02)
  - Per-user rate limiting: 10 analyses per day (AI-10)
  - Input already sanitized and length-limited by AnalyzeRequest model (SEC-03, SEC-04)
  - Full resume text never appears in log calls (SEC-04)
"""

import structlog
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from slowapi.errors import RateLimitExceeded

from config import settings
from dependencies import get_current_user, limiter
from models.requests import AnalyzeRequest
from models.responses import AnalyzeResponse
from services.firestore_writer import write_roadmap
from services.prompt_chain import ChainStepError, run_analysis_chain

log = structlog.get_logger(__name__)

router = APIRouter(prefix="/roadmaps", tags=["roadmaps"])


@router.post(
    "/analyze",
    response_model=AnalyzeResponse,
    summary="Generate AI career roadmap",
    description=(
        "Runs the 4-step Gemini 2.5 Flash prompt chain (Goal Analyzer → Skill Gap → "
        "Roadmap Planner → Resource Curator) and persists the result to Firestore. "
        "Requires a valid Firebase ID token. Rate limited to 10 requests per user per day."
    ),
    responses={
        401: {"description": "Missing or invalid Firebase ID token"},
        422: {"description": "Request validation error or AI response format mismatch"},
        429: {"description": "Rate limit exceeded (10 analyses per day)"},
        502: {"description": "AI prompt chain step failed"},
        500: {"description": "Unexpected internal server error"},
    },
)
@limiter.limit(settings.rate_limit_analyses)
async def analyze_roadmap(
    request: Request,
    body: AnalyzeRequest,
    user: dict = Depends(get_current_user),
) -> AnalyzeResponse:
    """Generate a personalized career roadmap using the Gemini prompt chain.

    Flow:
      1. Attach authenticated user to request state (for rate limiter key)
      2. Run 4-step prompt chain (sync, runs in FastAPI threadpool)
      3. Write dual-field roadmap document to Firestore
      4. Return AnalyzeResponse with both legacy and enhanced fields

    Error hierarchy:
      - ChainStepError -> 502 (AI service degradation, not client error)
      - ValidationError -> 422 (AI returned unexpected JSON structure)
      - RateLimitExceeded -> 429 (user hit their daily quota)
      - Exception -> 500 (unexpected, logged with full traceback)
    """
    # Attach user to request state — the rate limiter key_func reads this
    request.state.user = user
    user_id: str = user["uid"]

    # Log request start — user_id only, never resume_text (SEC-04)
    log.info("analyze_start", user_id=user_id)

    try:
        chain_result = run_analysis_chain(
            resume_text=body.resume_text,
            skills=body.skills,
            interests=body.interests,
            career_goals=body.career_goals,
            user_id=user_id,
        )

        roadmap_id = write_roadmap(user_id=user_id, chain_result=chain_result)

        goal = chain_result["goal"]
        gaps_data = chain_result["gaps"]
        roadmap_data = chain_result["roadmap"]
        resources_data = chain_result["resources"]

        # Build response — legacy-compatible fields plus enhanced AI output
        response = AnalyzeResponse(
            roadmap_id=roadmap_id,
            target_role=goal.target_role,
            goal_analysis=goal.summary,
            skill_gaps=[
                {
                    "skill": g.skill_name,
                    "confidence": g.confidence,
                    "level": g.proficiency_required,
                }
                for g in gaps_data.gaps
            ],
            milestones=[
                f"{phase.level.capitalize()} -- {phase.title}"
                for phase in roadmap_data.phases
            ],
            resources=[r.url for r in resources_data.resources],
            timeline=f"Approx. {roadmap_data.estimated_months} months",
            confidence=goal.confidence,
        )

        log.info(
            "analyze_complete",
            user_id=user_id,
            roadmap_id=roadmap_id,
            target_role=goal.target_role,
        )

        return response

    except ChainStepError as exc:
        log.error(
            "chain_step_error",
            user_id=user_id,
            step=exc.step,
            cause=str(exc.cause),
        )
        return JSONResponse(
            status_code=502,
            content={
                "detail": f"AI analysis failed at step: {exc.step}",
                "error_code": "CHAIN_STEP_FAILED",
            },
        )

    except ValidationError as exc:
        log.warning("ai_validation_error", user_id=user_id, errors=exc.error_count())
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Invalid AI response format — analysis could not be parsed",
                "error_code": "VALIDATION_FAILED",
            },
        )

    except RateLimitExceeded:
        return JSONResponse(
            status_code=429,
            content={
                "detail": "Rate limit exceeded. Maximum 10 analyses per day.",
                "error_code": "RATE_LIMIT",
            },
        )

    except Exception as exc:
        log.exception("analyze_unexpected_error", user_id=user_id, error=str(exc))
        return JSONResponse(
            status_code=500,
            content={
                "detail": "Internal server error",
                "error_code": "INTERNAL_ERROR",
            },
        )
