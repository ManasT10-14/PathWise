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
