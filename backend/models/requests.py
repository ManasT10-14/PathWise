"""API request models with input validation and sanitization.

SEC-03: Input sanitization — strips control characters from free-text fields.
SEC-04: Length limits — resume 10K chars, career goals 500 chars.
"""

import re

from pydantic import BaseModel, Field, model_validator


def _strip_control_chars(text: str) -> str:
    """Remove ASCII control characters (< 0x20) except newline (0x0A) and tab (0x09)."""
    return re.sub(r"[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]", "", text)


class AnalyzeRequest(BaseModel):
    """Request body for POST /api/v1/roadmaps/analyze.

    Validates and sanitizes user-supplied career profile data before
    it is sent to the Gemini prompt chain.
    """

    resume_text: str = Field(
        max_length=10000,
        description=(
            "Plain text resume content. "
            "HTML, Markdown, and binary content are not supported. "
            "Maximum 10,000 characters (SEC-04)."
        ),
    )
    skills: list[str] = Field(
        max_length=50,
        description=(
            "Current skills the user possesses "
            "(e.g., ['Python', 'SQL', 'TensorFlow']). "
            "Maximum 50 items."
        ),
    )
    interests: list[str] = Field(
        max_length=20,
        description=(
            "Interest areas relevant to career direction "
            "(e.g., ['Machine Learning', 'Data Visualization']). "
            "Maximum 20 items."
        ),
    )
    career_goals: str = Field(
        max_length=500,
        description=(
            "Target career goal in plain text "
            "(e.g., 'Become an ML Engineer at a product company within 12 months'). "
            "Maximum 500 characters (SEC-04)."
        ),
    )

    @model_validator(mode="before")
    @classmethod
    def sanitize_text_fields(cls, values: dict) -> dict:
        """Strip control characters from free-text fields (SEC-03).

        Targets resume_text and career_goals — the two fields where users
        might paste arbitrary content (e.g., from a PDF export).
        """
        if isinstance(values.get("resume_text"), str):
            values["resume_text"] = _strip_control_chars(values["resume_text"])
        if isinstance(values.get("career_goals"), str):
            values["career_goals"] = _strip_control_chars(values["career_goals"])
        return values


class ReplanRequest(BaseModel):
    """Request body for POST /api/v1/roadmaps/replan.

    Carries the current roadmap state (id + stage progress) plus optional
    learner-supplied context and stall detection metadata.
    """

    roadmap_id: str = Field(
        description="Firestore document ID of the roadmap to replan"
    )
    current_progress: dict[str, float] = Field(
        description=(
            "Current stageProgress map from Firestore, "
            "e.g. {'beginner': 0.3, 'intermediate': 0.0}"
        )
    )
    learner_feedback: str = Field(
        default="",
        max_length=1000,
        description="Optional learner-supplied context about why they are stuck",
    )
    stall_days: int | None = Field(
        default=None,
        ge=0,
        description=(
            "Days the stalled stage has been unchanged; "
            "None for user-triggered replans"
        ),
    )

    @model_validator(mode="before")
    @classmethod
    def sanitize_feedback(cls, values: dict) -> dict:
        """Strip control characters from learner_feedback (SEC-03)."""
        if isinstance(values.get("learner_feedback"), str):
            values["learner_feedback"] = _strip_control_chars(values["learner_feedback"])
        return values


class AnnotateRequest(BaseModel):
    """Request body for POST /api/v1/roadmaps/annotate.

    Allows experts to annotate specific milestones on a learner's roadmap.
    Annotations are stored in learner memory and injected into future replans (EXP-04, EXP-05).
    """

    learner_id: str = Field(
        description="Firebase UID of the learner whose roadmap is being annotated"
    )
    roadmap_id: str = Field(
        description="Firestore document ID of the roadmap being annotated"
    )
    milestone_level: str = Field(
        description="The roadmap stage level being annotated (e.g., 'beginner', 'intermediate', 'advanced')"
    )
    annotation_text: str = Field(
        max_length=800,
        description="Expert's observation or recommendation for this milestone"
    )

    @model_validator(mode="before")
    @classmethod
    def sanitize_annotation(cls, values: dict) -> dict:
        """Strip control characters from annotation_text (SEC-03)."""
        if isinstance(values.get("annotation_text"), str):
            values["annotation_text"] = _strip_control_chars(values["annotation_text"])
        return values
