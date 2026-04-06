"""Replan chain — memory-aware single-step roadmap adjustment.

Unlike the 4-step analysis chain, replanning is a single Gemini call that
uses the existing roadmap + progress + memory as input context.

The prompt template (replanner.txt) accepts structured slots for:
  - Current roadmap milestones and timeline
  - Per-stage progress values
  - Stall detection context (days unchanged)
  - Optional learner feedback
  - Past analysis history from learner memory
  - Expert annotations from learner memory

Synchronous def — FastAPI runs sync handlers in a threadpool (google-genai is sync).
"""

import time
from pathlib import Path

import structlog
from pydantic import BaseModel

from services.gemini_client import MODEL, client

log = structlog.get_logger(__name__)

# Load the replan prompt template once at module import time.
# Path is relative to this file: ../prompts/replanner.txt
REPLANNER_PROMPT = (Path(__file__).parent.parent / "prompts" / "replanner.txt").read_text(
    encoding="utf-8"
)


class ReplanStepError(Exception):
    """Raised when the Gemini replan call fails.

    Attributes:
        cause: The original exception that caused the failure.
    """

    def __init__(self, cause: Exception) -> None:
        self.cause = cause
        super().__init__(f"Replan failed: {cause}")


class ReplanOutput(BaseModel):
    """Structured output schema for the Gemini replan call.

    Passed as response_schema to the Gemini SDK so the model returns
    well-typed JSON that can be validated directly.
    """

    adjusted_milestones: list[str]
    replan_reason: str
    stalled_stages: list[str]


def run_replan_chain(
    roadmap_id: str,
    target_role: str,
    current_milestones: list[str],
    current_timeline: str,
    stage_progress: dict[str, float],
    learner_feedback: str,
    memory: dict,
    stall_days: int | None,
) -> dict:
    """Run the replan prompt chain against Gemini 2.5 Flash.

    Formats the replanner.txt template with all available context (roadmap
    state, learner progress, memory, expert annotations) and makes a single
    structured Gemini call. Returns the AI-adjusted roadmap data.

    Args:
        roadmap_id: Firestore document ID of the current roadmap (used for logging).
        target_role: The target career role stored on the roadmap document.
        current_milestones: List of milestone strings in legacy format
            (e.g., "Beginner -- Foundations: task1, task2").
        current_timeline: Human-readable timeline string from the roadmap document.
        stage_progress: Dict mapping stage level to progress float
            (e.g., {"beginner": 0.3, "intermediate": 0.0}).
        learner_feedback: Optional free-text feedback from the learner.
            Pass empty string if not provided.
        memory: Dict returned by read_learner_memory() with keys
            "analysis_history", "expert_annotations", "has_memory".
        stall_days: Number of days the stalled stage has been unchanged,
            or None if the replan was user-triggered (not automatic).

    Returns:
        Dict with keys:
            "adjusted_milestones": list[str] — new milestone strings in legacy format
            "replan_reason": str — AI explanation of the changes made
            "stalled_stages": list[str] — stage levels identified as stalled

    Raises:
        ReplanStepError: If the Gemini API call fails for any reason.
    """
    chain_start = time.monotonic()

    log.info(
        "replan_start",
        roadmap_id=roadmap_id,
        target_role=target_role,
        stall_days=stall_days,
        has_memory=memory.get("has_memory", False),
    )

    # -----------------------------------------------------------------------
    # Build prompt slot values
    # -----------------------------------------------------------------------

    progress_summary = ", ".join(
        f"{k}: {v:.1f}" for k, v in stage_progress.items()
    )

    if stall_days is not None:
        # Identify which stage(s) might be stalled — the ones with lowest progress
        stalled = _find_most_stalled_stage(stage_progress)
        stall_context = (
            f"Stage '{stalled}' unchanged for {stall_days} days (threshold: 14 days)"
        )
    else:
        stall_context = "User-triggered replan (no automatic stall detected)"

    memory_context = _format_analysis_history(memory.get("analysis_history", []))
    expert_annotations_text = _format_expert_annotations(memory.get("expert_annotations", []))

    milestones_text = "\n".join(current_milestones) if current_milestones else "No milestones available"
    feedback_text = learner_feedback.strip() if learner_feedback.strip() else "No feedback provided"

    prompt = REPLANNER_PROMPT.format(
        target_role=target_role,
        current_milestones=milestones_text,
        current_timeline=current_timeline,
        progress_summary=progress_summary,
        stall_context=stall_context,
        learner_feedback=feedback_text,
        memory_context=memory_context,
        expert_annotations=expert_annotations_text,
    )

    # -----------------------------------------------------------------------
    # Gemini structured output call
    # -----------------------------------------------------------------------
    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_schema": ReplanOutput,
                "max_output_tokens": 4096,
            },
        )

        result = ReplanOutput.model_validate_json(response.text)

    except Exception as exc:
        log.error("replan_step_failed", roadmap_id=roadmap_id, error=str(exc))
        raise ReplanStepError(exc) from exc

    elapsed = time.monotonic() - chain_start

    log.info(
        "replan_complete",
        roadmap_id=roadmap_id,
        stall_days=stall_days,
        milestone_count=len(result.adjusted_milestones),
        stalled_stages=result.stalled_stages,
        total_seconds=round(elapsed, 2),
    )

    return {
        "adjusted_milestones": result.adjusted_milestones,
        "replan_reason": result.replan_reason,
        "stalled_stages": result.stalled_stages,
    }


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _find_most_stalled_stage(stage_progress: dict[str, float]) -> str:
    """Return the stage level with the lowest progress value.

    Used to name the stalled stage in the prompt when stall_days is provided
    but we need to identify which specific level is stuck.
    """
    if not stage_progress:
        return "unknown"
    # Return the stage with the lowest progress that is < 1.0 (not complete).
    # Falls back to the first stage if all are complete or all equal.
    incomplete = {k: v for k, v in stage_progress.items() if v < 1.0}
    if incomplete:
        return min(incomplete, key=lambda k: incomplete[k])
    return next(iter(stage_progress))


def _format_analysis_history(history: list[dict]) -> str:
    """Format analysis_history entries into a readable prompt string."""
    if not history:
        return "No prior session history"
    lines = [
        f"- {r.get('target_role', 'unknown role')}, "
        f"{r.get('gap_count', '?')} gaps, "
        f"analyzed_at: {r.get('analyzed_at', '?')}"
        for r in history
    ]
    return "\n".join(lines)


def _format_expert_annotations(annotations: list[dict]) -> str:
    """Format expert_annotations entries into a readable prompt string."""
    if not annotations:
        return "No expert annotations"
    lines = [
        f"- [{r.get('milestone_level', '?')}] {r.get('annotation', '')}"
        for r in annotations
    ]
    return "\n".join(lines)
