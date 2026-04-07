"""Application configuration via pydantic-settings.

All settings are loaded from environment variables (or .env file).
A module-level singleton `settings` is created for use across the app.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Pathwise backend configuration.

    Fields can be overridden by environment variables (case-insensitive).
    Example: GCP_PROJECT_ID=pathwise-aedc5 in .env or shell environment.
    """

    # --- Google Cloud / Vertex AI ---
    gcp_project_id: str
    gcp_location: str = "us-central1"
    gemini_model: str = "gemini-2.5-flash"

    # --- Firebase Admin SDK ---
    # Path to service account JSON file. If empty, falls back to
    # GOOGLE_APPLICATION_CREDENTIALS environment variable (ADC).
    firebase_service_account: str = ""

    # --- Razorpay ---
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""

    # --- CORS ---
    cors_origins: list[str] = ["*"]

    # --- Rate limiting (slowapi format: "N/period") ---
    rate_limit_analyses: str = "10/day"
    rate_limit_replans: str = "3/day"

    # --- Logging ---
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        # Allow extra fields from .env without raising validation errors
        extra="ignore",
    )


# Module-level singleton — import this everywhere instead of re-instantiating
settings = Settings()
