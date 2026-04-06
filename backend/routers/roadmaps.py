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
from firebase_admin import firestore
from pydantic import ValidationError
from slowapi.errors import RateLimitExceeded

from config import settings
from dependencies import get_current_user, limiter
from models.requests import AnalyzeRequest, ReplanRequest
from models.responses import AnalyzeResponse, ReplanResponse
from services.firestore_writer import write_roadmap
from services.memory_writer import read_learner_memory, write_analysis_memory
from services.prompt_chain import ChainStepError, run_analysis_chain
from services.replanner import ReplanStepError, run_replan_chain

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

        # Persist analysis to learner memory (ADAPT-04, ADAPT-05)
        try:
            write_analysis_memory(user_id=user_id, chain_result=chain_result, roadmap_id=roadmap_id)
        except Exception as mem_exc:
            # Memory write failure must not fail the analysis response
            log.warning("memory_write_failed", user_id=user_id, error=str(mem_exc))

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


@router.post(
    "/replan",
    response_model=ReplanResponse,
    summary="Replan existing roadmap based on progress stall or learner feedback",
    description=(
        "Adjusts a learner's existing roadmap using memory-aware Gemini replan chain. "
        "Creates a new versioned Firestore document — the original is never overwritten. "
        "Requires a valid Firebase ID token. Rate limited to 3 requests per user per day."
    ),
    responses={
        401: {"description": "Missing or invalid Firebase ID token"},
        404: {"description": "Roadmap not found or does not belong to this user"},
        429: {"description": "Rate limit exceeded (3 replans per day)"},
        502: {"description": "Replan chain failed"},
        500: {"description": "Unexpected internal server error"},
    },
)
@limiter.limit(settings.rate_limit_replans)
async def replan_roadmap(
    request: Request,
    body: ReplanRequest,
    user: dict = Depends(get_current_user),
) -> ReplanResponse:
    """Replan a learner's roadmap using the memory-aware Gemini replan chain.

    Flow:
      1. Attach authenticated user to request state (for rate limiter key)
      2. Fetch and validate ownership of the existing roadmap document
      3. Read learner memory context (analysis history + expert annotations)
      4. Run single-step Gemini replan chain with full context injection
      5. Create a new versioned Firestore document (ADAPT-03 — never overwrite)
      6. Return ReplanResponse with the new document ID and adjusted roadmap

    Error hierarchy:
      - 404: Roadmap not found or ownership mismatch
      - ReplanStepError -> 502 (Gemini API degradation)
      - RateLimitExceeded -> 429 (user hit their daily quota)
      - Exception -> 500 (unexpected, logged with full traceback)
    """
    # Attach user to request state — the rate limiter key_func reads this
    request.state.user = user
    user_id: str = user["uid"]

    log.info("replan_start", user_id=user_id, roadmap_id=body.roadmap_id, stall_days=body.stall_days)

    # -----------------------------------------------------------------------
    # Fetch existing roadmap and verify ownership
    # -----------------------------------------------------------------------
    db = firestore.client()
    doc = db.collection("roadmaps").document(body.roadmap_id).get()

    if not doc.exists or doc.get("userId") != user_id:
        log.warning(
            "replan_roadmap_not_found",
            user_id=user_id,
            roadmap_id=body.roadmap_id,
            exists=doc.exists,
        )
        return JSONResponse(
            status_code=404,
            content={"detail": "Roadmap not found", "error_code": "NOT_FOUND"},
        )

    # Extract current roadmap fields
    target_role: str = doc.get("targetRole", "")
    milestones: list[str] = doc.get("milestones", [])
    timeline: str = doc.get("timeline", "")
    current_version: int = doc.get("replan_version", 1)

    # -----------------------------------------------------------------------
    # Read learner memory for prompt injection (ADAPT-04, EXP-05)
    # -----------------------------------------------------------------------
    memory = read_learner_memory(user_id=user_id)

    # -----------------------------------------------------------------------
    # Run the replan chain
    # -----------------------------------------------------------------------
    try:
        replan_result = run_replan_chain(
            roadmap_id=body.roadmap_id,
            target_role=target_role,
            current_milestones=milestones,
            current_timeline=timeline,
            stage_progress=body.current_progress,
            learner_feedback=body.learner_feedback,
            memory=memory,
            stall_days=body.stall_days,
        )
    except ReplanStepError as exc:
        log.error(
            "replan_chain_error",
            user_id=user_id,
            roadmap_id=body.roadmap_id,
            cause=str(exc.cause),
        )
        return JSONResponse(
            status_code=502,
            content={
                "detail": "Replan failed — AI service error",
                "error_code": "REPLAN_FAILED",
            },
        )
    except RateLimitExceeded:
        return JSONResponse(
            status_code=429,
            content={
                "detail": "Rate limit exceeded. Maximum 3 replans per day.",
                "error_code": "RATE_LIMIT",
            },
        )
    except Exception as exc:
        log.exception("replan_unexpected_error", user_id=user_id, roadmap_id=body.roadmap_id, error=str(exc))
        return JSONResponse(
            status_code=500,
            content={
                "detail": "Internal server error",
                "error_code": "INTERNAL_ERROR",
            },
        )

    # -----------------------------------------------------------------------
    # Create new versioned roadmap document (ADAPT-03 — never overwrite original)
    # -----------------------------------------------------------------------
    new_doc_ref = db.collection("roadmaps").document()
    new_doc_id = new_doc_ref.id
    new_version = current_version + 1

    # Reset progress for the new roadmap version — learner starts fresh on adjusted plan
    new_stage_progress = {k: 0.0 for k in body.current_progress}

    new_doc_ref.set({
        # Legacy fields (required by existing Flutter Roadmap.fromFirestore)
        "userId": user_id,
        "roadmapId": new_doc_id,
        "targetRole": target_role,
        "milestones": replan_result["adjusted_milestones"],
        "resources": doc.get("resources", []),  # carry forward existing resources
        "timeline": timeline,
        "stageProgress": new_stage_progress,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        # Versioning fields (ADAPT-03)
        "replan_version": new_version,
        "previous_roadmap_id": body.roadmap_id,
        "replan_reason": replan_result["replan_reason"],
        "generatedBy": "gemini-2.5-flash-replan",
    })

    log.info(
        "replan_complete",
        user_id=user_id,
        new_roadmap_id=new_doc_id,
        version=new_version,
        stall_days=body.stall_days,
    )

    return ReplanResponse(
        new_roadmap_id=new_doc_id,
        replan_reason=replan_result["replan_reason"],
        adjusted_milestones=replan_result["adjusted_milestones"],
        stalled_stages=replan_result.get("stalled_stages", []),
        version=new_version,
    )
