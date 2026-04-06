"""Step 3 of the prompt chain: Roadmap Planner.

Takes GoalAnalysis and SkillGapAnalysis outputs and produces a phased
milestone-based learning roadmap with concrete tasks and time estimates.

Synchronous def — FastAPI runs sync handlers in a threadpool.
"""

import pathlib

import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from models.ai_schemas import GoalAnalysis, RoadmapPlan, SkillGapAnalysis
from services.gemini_client import MODEL, client

log = structlog.get_logger(__name__)

_PROMPT_PATH = pathlib.Path(__file__).parent.parent / "prompts" / "roadmap_planner.txt"
_PROMPT_TEMPLATE = _PROMPT_PATH.read_text(encoding="utf-8")


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    reraise=True,
)
def plan_roadmap(
    goal: GoalAnalysis,
    gaps: SkillGapAnalysis,
    career_goals: str,
) -> RoadmapPlan:
    """Create a phased learning roadmap from goal analysis and skill gaps.

    Args:
        goal: GoalAnalysis from Step 1 (provides target role and timeframe).
        gaps: SkillGapAnalysis from Step 2 (provides ordered gaps and strengths).
        career_goals: Original user-supplied career goals string (for context).

    Returns:
        RoadmapPlan with ordered phases, hour estimates, and revision checkpoints.

    Raises:
        pydantic.ValidationError: If Gemini response doesn't match RoadmapPlan schema.
        Exception: Propagated after 3 retries.
    """
    log.info(
        "roadmap_planning_start",
        target_role=goal.target_role,
        gaps_count=len(gaps.gaps),
        timeframe_months=goal.timeframe_months,
    )

    # Format skill gaps as a numbered list for clear prompt presentation
    skill_gaps_formatted = "\n".join(
        f"{i + 1}. {gap.skill_name} "
        f"(confidence: {gap.confidence:.2f}, level: {gap.proficiency_required})"
        for i, gap in enumerate(gaps.gaps)
    ) or "No significant gaps identified"

    prompt = _PROMPT_TEMPLATE.format(
        target_role=goal.target_role,
        skill_gaps=skill_gaps_formatted,
        strengths=", ".join(gaps.strengths) if gaps.strengths else "Not specified",
        timeframe_months=goal.timeframe_months,
        career_goals=career_goals or "Not specified",
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": RoadmapPlan,
            "max_output_tokens": 8192,
        },
    )

    result = RoadmapPlan.model_validate_json(response.text)

    log.info(
        "roadmap_planning_complete",
        phases_count=len(result.phases),
        total_hours=result.total_estimated_hours,
        estimated_months=result.estimated_months,
    )

    return result
