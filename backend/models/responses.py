"""API response models.

AnalyzeResponse uses a dual-field structure:
  - Legacy fields (target_role, milestones, resources, timeline) match
    the existing Flutter Roadmap.fromFirestore() parser exactly.
  - Enhanced fields (goal_analysis, skill_gaps, confidence) expose richer
    AI output for the updated Flutter UI.

This ensures backward compatibility while enabling the UI overhaul (Phase 01-02).
"""

from pydantic import BaseModel, Field


class AnalyzeResponse(BaseModel):
    """Response payload for POST /api/v1/roadmaps/analyze."""

    roadmap_id: str = Field(
        description="Firestore document ID of the newly created roadmap document"
    )

    # --- Enhanced AI output fields ---
    target_role: str = Field(
        description="Target career role inferred by the Goal Analyzer"
    )
    goal_analysis: str = Field(
        description="2–3 sentence summary from the Goal Analyzer step"
    )
    skill_gaps: list[dict] = Field(
        description=(
            "List of identified skill gaps, each with keys: "
            "'skill' (str), 'confidence' (float 0–1), 'level' (str)"
        )
    )

    # --- Legacy-compatible fields (required by existing Flutter Roadmap.fromFirestore) ---
    milestones: list[str] = Field(
        description=(
            "Milestone descriptions as plain strings for legacy Flutter compatibility. "
            "Format: 'Level -- Title: task1, task2, task3'"
        )
    )
    resources: list[str] = Field(
        description=(
            "Resource URLs as plain strings for legacy Flutter compatibility. "
            "One URL per roadmap phase."
        )
    )
    timeline: str = Field(
        description=(
            "Human-readable timeline estimate "
            "(e.g., 'Approx. 6 months at 15 hours/week')"
        )
    )

    # --- Metadata ---
    confidence: float = Field(
        ge=0,
        le=1,
        description="Overall confidence score from the Goal Analyzer (0.0–1.0)",
    )


class ErrorResponse(BaseModel):
    """Standard error response payload."""

    detail: str = Field(description="Human-readable error description")
    error_code: str | None = Field(
        default=None,
        description=(
            "Machine-readable error code for client error handling "
            "(e.g., 'CHAIN_STEP_FAILED', 'RATE_LIMIT', 'VALIDATION_FAILED')"
        ),
    )
