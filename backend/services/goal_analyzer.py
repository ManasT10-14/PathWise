"""Step 1 of the prompt chain: Goal Analyzer.

Accepts the user's raw career profile and returns a structured GoalAnalysis
identifying the target role, career direction, constraints, timeframe, and
a confidence score.

Uses synchronous def (not async) because the google-genai SDK is synchronous.
FastAPI automatically runs sync route handlers and dependencies in a threadpool,
preventing event loop blocking.
"""

import pathlib

import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from models.ai_schemas import GoalAnalysis
from services.gemini_client import MODEL, client

log = structlog.get_logger(__name__)

# Load prompt template once at module import time
_PROMPT_PATH = pathlib.Path(__file__).parent.parent / "prompts" / "goal_analyzer.txt"
_PROMPT_TEMPLATE = _PROMPT_PATH.read_text(encoding="utf-8")


@retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=1, min=1, max=5), reraise=True)
def analyze_goal(
    resume_text: str,
    skills: list[str],
    interests: list[str],
    career_goals: str,
) -> GoalAnalysis:
    """Analyze a user's career profile and return a structured goal analysis.

    Args:
        resume_text: Plain text resume content (already sanitized and truncated).
        skills: List of skills the user currently possesses.
        interests: List of career interest areas.
        career_goals: User's stated career goal in plain text.

    Returns:
        GoalAnalysis with target role, direction, constraints, timeframe, and confidence.

    Raises:
        pydantic.ValidationError: If Gemini returns JSON that doesn't match GoalAnalysis schema.
        Exception: Propagated after 3 failed attempts (handled by ChainStepError in orchestrator).
    """
    # Log input metadata — NOT the resume content itself (SEC-04: avoid logging PII)
    log.info(
        "goal_analysis_start",
        resume_length=len(resume_text),
        skills_count=len(skills),
        interests_count=len(interests),
    )

    prompt = _PROMPT_TEMPLATE.format(
        resume_text=resume_text,
        skills=", ".join(skills) if skills else "Not specified",
        interests=", ".join(interests) if interests else "Not specified",
        career_goals=career_goals or "Not specified",
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": GoalAnalysis,
            "max_output_tokens": 2048,
        },
    )

    result = GoalAnalysis.model_validate_json(response.text)

    log.info(
        "goal_analysis_complete",
        target_role=result.target_role,
        confidence=result.confidence,
        timeframe_months=result.timeframe_months,
    )

    return result
