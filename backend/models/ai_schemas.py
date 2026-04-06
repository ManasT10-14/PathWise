"""Pydantic models for Gemini structured output.

These models serve triple duty:
  1. Gemini response_schema — tells the model what JSON structure to return
  2. FastAPI response model — auto-generates OpenAPI docs with field descriptions
  3. Chain step contract — typed data passed between prompt chain steps

Design principle: every field has a description so Gemini understands what to fill in.
"""

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Step 1: Goal Analyzer output
# ---------------------------------------------------------------------------


class GoalAnalysis(BaseModel):
    """Parsed output from the Goal Analyzer prompt chain step."""

    target_role: str = Field(
        description="Inferred target career role (e.g., 'ML Engineer', 'Backend Engineer')"
    )
    career_direction: str = Field(
        description=(
            "Broader career trajectory label "
            "(e.g., 'Data/ML Engineering', 'Full-Stack Development')"
        )
    )
    constraints: list[str] = Field(
        description=(
            "Time, resource, or skill constraints identified from the user's background "
            "(e.g., 'No prior ML experience', 'Part-time study commitment')"
        )
    )
    timeframe_months: int = Field(
        ge=1,
        le=60,
        description="Estimated months to reach the target role from the user's current skill level",
    )
    confidence: float = Field(
        ge=0,
        le=1,
        description=(
            "Confidence score (0.0–1.0) reflecting how clearly the input maps "
            "to a specific career direction. Lower if goals are vague."
        ),
    )
    summary: str = Field(
        description=(
            "2–3 sentence human-readable summary of the career goal analysis, "
            "explaining the target role, key constraints, and recommended path."
        )
    )


# ---------------------------------------------------------------------------
# Step 2: Skill Gap Analyzer output
# ---------------------------------------------------------------------------


class SkillGap(BaseModel):
    """A single missing skill identified during gap analysis."""

    skill_name: str = Field(description="Name of the missing skill (e.g., 'PyTorch', 'SQL')")
    confidence: float = Field(
        ge=0,
        le=1,
        description=(
            "Confidence (0.0–1.0) that this is a genuine gap for the target role. "
            "Use lower values for skills where the user's background is ambiguous."
        ),
    )
    proficiency_required: str = Field(
        description=(
            "Required proficiency level for the target role. "
            "Must be exactly one of: 'beginner', 'intermediate', or 'advanced'."
        )
    )
    prerequisites: list[str] = Field(
        default_factory=list,
        description=(
            "Skills that should be learned before this one "
            "(e.g., learning NumPy before PyTorch). Empty list if no prerequisites."
        ),
    )


class SkillGapAnalysis(BaseModel):
    """Complete skill gap analysis output for a user's target role."""

    gaps: list[SkillGap] = Field(
        description=(
            "Ordered list of skill gaps, highest priority first. "
            "Foundational prerequisites come before advanced specializations."
        )
    )
    strengths: list[str] = Field(
        description="Skills the user already has that are relevant to the target role"
    )
    confidence: float = Field(
        ge=0,
        le=1,
        description=(
            "Overall confidence (0.0–1.0) in the gap analysis. "
            "Lower if the resume is sparse or skills list is incomplete."
        ),
    )


# ---------------------------------------------------------------------------
# Step 3: Roadmap Planner output
# ---------------------------------------------------------------------------


class Milestone(BaseModel):
    """A single learning phase within the roadmap."""

    title: str = Field(
        description=(
            "Descriptive milestone title "
            "(e.g., 'Foundations: Python and Statistics for ML')"
        )
    )
    level: str = Field(
        description=(
            "Learning level of this phase. "
            "Must be exactly one of: 'beginner', 'intermediate', or 'advanced'."
        )
    )
    skills: list[str] = Field(
        description="Skills taught and practised in this milestone phase"
    )
    estimated_hours: int = Field(
        ge=1,
        description=(
            "Realistic (not optimistic) total hours to complete this phase, "
            "including practice and project work."
        ),
    )
    tasks: list[str] = Field(
        description=(
            "3–5 concrete, actionable tasks the learner must complete "
            "(e.g., 'Complete Andrew Ng's ML Specialization Week 1–4', "
            "'Build a linear regression project from scratch')."
        )
    )


class RoadmapPlan(BaseModel):
    """Complete phased learning roadmap."""

    phases: list[Milestone] = Field(
        description=(
            "Ordered learning phases (3–5 milestones). "
            "Prerequisites come first; advanced specializations come last."
        )
    )
    total_estimated_hours: int = Field(
        ge=1,
        description="Sum of estimated_hours across all phases",
    )
    weekly_hours_recommended: int = Field(
        ge=1,
        le=40,
        description=(
            "Recommended weekly study commitment in hours. "
            "Should make the roadmap completable within estimated_months."
        ),
    )
    estimated_months: int = Field(
        ge=1,
        description=(
            "Total months to complete the roadmap at weekly_hours_recommended. "
            "Must be consistent with total_estimated_hours / (weekly_hours_recommended * 4.3)."
        ),
    )
    revision_points: list[str] = Field(
        description=(
            "Specific points in the roadmap where the learner should assess progress "
            "and potentially adjust pace or direction "
            "(e.g., 'After completing Phase 1: self-assess Python proficiency')."
        )
    )


# ---------------------------------------------------------------------------
# Step 4: Resource Curator output
# ---------------------------------------------------------------------------


class Resource(BaseModel):
    """A single curated learning resource mapped to a roadmap phase."""

    title: str = Field(description="Descriptive resource title including platform name")
    url: str = Field(
        description=(
            "Resource URL. Use well-known platform URLs that are very likely to exist. "
            "Prefer platform landing pages over deep links if uncertain about exact URL."
        )
    )
    type: str = Field(
        description=(
            "Resource type. Must be exactly one of: "
            "'course', 'article', 'video', 'tutorial', or 'book'."
        )
    )
    difficulty: str = Field(
        description=(
            "Difficulty level matching the roadmap phase. "
            "Must be exactly one of: 'beginner', 'intermediate', or 'advanced'."
        )
    )
    phase_index: int = Field(
        ge=0,
        description="0-based index of the roadmap phase this resource maps to",
    )


class CuratedResources(BaseModel):
    """Collection of curated resources mapped to roadmap phases."""

    resources: list[Resource] = Field(
        description=(
            "2–4 resources per roadmap phase, covering a mix of types "
            "(not all courses, not all videos). Prioritize free resources."
        )
    )
    disclaimer: str = Field(
        default=(
            "Resources are AI-suggested. Verify links before relying on them."
        ),
        description="Standard disclaimer about AI-suggested resource URLs",
    )
