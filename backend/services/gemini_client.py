"""Shared Gemini client singleton for all prompt chain services.

Uses the google-genai SDK. Supports two modes:
  1. API Key mode (GEMINI_API_KEY set) — simplest, works on any platform
  2. Vertex AI mode (GCP_PROJECT_ID set, no API key) — for GCP deployments

The client is instantiated once at module import time and shared across all
service modules to avoid redundant authentication overhead.
"""

from google import genai

from config import settings

if settings.gemini_api_key:
    # API Key mode — works on Railway, Render, any non-GCP platform
    client = genai.Client(api_key=settings.gemini_api_key)
elif settings.gcp_project_id:
    # Vertex AI mode — works on GCP, Cloud Run, or with ADC
    from google.genai.types import HttpOptions
    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
        http_options=HttpOptions(api_version="v1"),
    )
else:
    raise RuntimeError(
        "No Gemini credentials configured. "
        "Set GEMINI_API_KEY for API key mode, or GCP_PROJECT_ID for Vertex AI mode."
    )

# Model identifier used across all chain steps.
MODEL = settings.gemini_model
