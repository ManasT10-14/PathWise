"""Shared Gemini client singleton for all prompt chain services.

Uses the google-genai SDK (the modern replacement for google-cloud-aiplatform
generative AI modules, which are deprecated as of June 2025).

The client is instantiated once at module import time and shared across all
service modules to avoid redundant authentication overhead.
"""

from google import genai
from google.genai.types import HttpOptions

from config import settings

# Vertex AI client — authenticates via GOOGLE_APPLICATION_CREDENTIALS or
# the service account path configured in settings.firebase_service_account.
client = genai.Client(
    vertexai=True,
    project=settings.gcp_project_id,
    location=settings.gcp_location,
    http_options=HttpOptions(api_version="v1"),
)

# Model identifier used across all chain steps.
# Configured via GEMINI_MODEL env var; defaults to "gemini-2.5-flash".
MODEL = settings.gemini_model
