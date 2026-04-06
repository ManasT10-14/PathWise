"""Step 4 of the prompt chain: Resource Curator.

Takes the GoalAnalysis and RoadmapPlan outputs and curates real, platform-
verified learning resources mapped to each roadmap phase.

Synchronous def — FastAPI runs sync handlers in a threadpool.
"""

import pathlib

import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from models.ai_schemas import CuratedResources, GoalAnalysis, RoadmapPlan
from services.gemini_client import MODEL, client

log = structlog.get_logger(__name__)

_PROMPT_PATH = pathlib.Path(__file__).parent.parent / "prompts" / "resource_curator.txt"
_PROMPT_TEMPLATE = _PROMPT_PATH.read_text(encoding="utf-8")


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=10), reraise=True)
def curate_resources(
    goal: GoalAnalysis,
    roadmap: RoadmapPlan,
) -> CuratedResources:
    """Curate learning resources mapped to each phase of the roadmap.

    Args:
        goal: GoalAnalysis from Step 1 (provides target role for context).
        roadmap: RoadmapPlan from Step 3 (provides phases to map resources to).

    Returns:
        CuratedResources with resources mapped to phase indices.

    Raises:
        pydantic.ValidationError: If Gemini response doesn't match CuratedResources schema.
        Exception: Propagated after 3 retries.
    """
    log.info(
        "resource_curation_start",
        target_role=goal.target_role,
        phases_count=len(roadmap.phases),
    )

    # Format phases as a numbered list — clear context for the resource curator
    roadmap_phases_formatted = "\n".join(
        f"{i + 1}. {phase.title} "
        f"(level: {phase.level}, "
        f"skills: {', '.join(phase.skills[:5])})"  # cap skills list to keep prompt concise
        for i, phase in enumerate(roadmap.phases)
    )

    prompt = _PROMPT_TEMPLATE.format(
        target_role=goal.target_role,
        roadmap_phases=roadmap_phases_formatted,
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_schema": CuratedResources,
            "max_output_tokens": 4096,
        },
    )

    result = CuratedResources.model_validate_json(response.text)

    log.info(
        "resource_curation_complete",
        resources_count=len(result.resources),
        target_role=goal.target_role,
    )

    return result
