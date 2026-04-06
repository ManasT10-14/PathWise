"""Step 2 of the prompt chain: Skill Gap Analyzer.

Takes the GoalAnalysis output from Step 1 and the user's current skills,
returns a SkillGapAnalysis with ordered gaps, prerequisites, and strengths.

Synchronous def — FastAPI runs sync handlers in a threadpool (avoids event loop blocking).
"""

import pathlib

import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from models.ai_schemas import GoalAnalysis, SkillGapAnalysis
from services.gemini_client import MODEL, client

log = structlog.get_logger(__name__)

_PROMPT_PATH = pathlib.Path(__file__).parent.parent / "prompts" / "skill_gap_analyzer.txt"
_PROMPT_TEMPLATE = _PROMPT_PATH.read_text(encoding="utf-8")


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    reraise=True,
)
def analyze_skill_gaps(
    goal: GoalAnalysis,
    resume_text: str,
    skills: list[str],
) -> SkillGapAnalysis:
    """Identify skill gaps between the user's current profile and the target role.

    Args:
        goal: Structured GoalAnalysis from Step 1 of the chain.
        resume_text: Plain text resume (truncated to 10K chars for context).
        skills: Current skills list.

    Returns:
        SkillGapAnalysis with ordered gaps, prerequisites, and confirmed strengths.

    Raises:
        pydantic.ValidationError: If Gemini response doesn't match SkillGapAnalysis schema.
        Exception: Propagated after 3 retries.
    """
    log.info(
        "skill_gap_analysis_start",
        target_role=goal.target_role,
        skills_count=len(skills),
        resume_length=len(resume_text),
    )

    prompt = _PROMPT_TEMPLATE.format(
        target_role=goal.target_role,
        career_direction=goal.career_direction,
        skills=", ".join(skills) if skills else "Not specified",
        # Enforce 10K truncation at service level as a defense-in-depth measure
        # (request model already validates max_length, but guard here too)
        resume_text=resume_text[:10000],
        timeframe_months=goal.timeframe_months,
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": SkillGapAnalysis,
            "max_output_tokens": 4096,
        },
    )

    result = SkillGapAnalysis.model_validate_json(response.text)

    log.info(
        "skill_gap_analysis_complete",
        gaps_count=len(result.gaps),
        strengths_count=len(result.strengths),
        confidence=result.confidence,
    )

    return result
