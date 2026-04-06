"""Prompt chain orchestrator — runs all 4 AI steps sequentially.

Coordinates the 4-step Gemini prompt chain:
  1. Goal Analyzer  — understands target role and constraints
  2. Skill Gap Analyzer — identifies missing skills with confidence scores
  3. Roadmap Planner — builds a phased milestone roadmap
  4. Resource Curator — maps real resources to each roadmap phase

Wraps each step in structured error handling so failures are diagnosable
and the Firestore writer never receives partial results.

Synchronous def — FastAPI runs sync handlers in a threadpool (google-genai is sync).
"""

import time

import structlog

from services.goal_analyzer import analyze_goal
from services.resource_curator import curate_resources
from services.roadmap_planner import plan_roadmap
from services.skill_gap_analyzer import analyze_skill_gaps

log = structlog.get_logger(__name__)


class ChainStepError(Exception):
    """Raised when a prompt chain step fails after all retry attempts.

    Attributes:
        step: Name of the chain step that failed (e.g., "goal_analyzer").
        cause: The original exception raised by the step.
    """

    def __init__(self, step: str, cause: Exception) -> None:
        self.step = step
        self.cause = cause
        super().__init__(f"Chain failed at {step}: {cause}")


def run_analysis_chain(
    resume_text: str,
    skills: list[str],
    interests: list[str],
    career_goals: str,
    user_id: str,
) -> dict:
    """Run the complete 4-step career analysis prompt chain.

    Steps are executed sequentially — each step's output feeds the next.
    If any step fails after all tenacity retries, a ChainStepError is raised
    with the step name and original exception preserved.

    Args:
        resume_text: Sanitized and length-validated resume text.
        skills: Current skills list.
        interests: Interest areas.
        career_goals: User's stated career goal.
        user_id: Firebase UID of the requesting user (for logging and Firestore write).

    Returns:
        Dict with keys: "goal" (GoalAnalysis), "gaps" (SkillGapAnalysis),
        "roadmap" (RoadmapPlan), "resources" (CuratedResources).

    Raises:
        ChainStepError: If any chain step fails after retries.
    """
    chain_start = time.monotonic()

    log.info("chain_start", user_id=user_id, resume_length=len(resume_text))

    # --- Step 1: Goal Analyzer ---
    try:
        goal = analyze_goal(
            resume_text=resume_text,
            skills=skills,
            interests=interests,
            career_goals=career_goals,
        )
    except Exception as exc:
        log.error("chain_step_failed", step="goal_analyzer", error=str(exc))
        raise ChainStepError("goal_analyzer", exc) from exc

    # --- Step 2: Skill Gap Analyzer ---
    try:
        gaps = analyze_skill_gaps(
            goal=goal,
            resume_text=resume_text,
            skills=skills,
        )
    except Exception as exc:
        log.error("chain_step_failed", step="skill_gap_analyzer", error=str(exc))
        raise ChainStepError("skill_gap_analyzer", exc) from exc

    # --- Step 3: Roadmap Planner ---
    try:
        roadmap = plan_roadmap(
            goal=goal,
            gaps=gaps,
            career_goals=career_goals,
        )
    except Exception as exc:
        log.error("chain_step_failed", step="roadmap_planner", error=str(exc))
        raise ChainStepError("roadmap_planner", exc) from exc

    # --- Step 4: Resource Curator ---
    try:
        resources = curate_resources(
            goal=goal,
            roadmap=roadmap,
        )
    except Exception as exc:
        log.error("chain_step_failed", step="resource_curator", error=str(exc))
        raise ChainStepError("resource_curator", exc) from exc

    elapsed = time.monotonic() - chain_start

    log.info(
        "chain_complete",
        user_id=user_id,
        total_seconds=round(elapsed, 2),
        target_role=goal.target_role,
        phases_count=len(roadmap.phases),
        resources_count=len(resources.resources),
    )

    return {
        "goal": goal,
        "gaps": gaps,
        "roadmap": roadmap,
        "resources": resources,
    }
