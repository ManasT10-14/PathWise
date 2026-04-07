"""Shared Gemini client singleton for all prompt chain services.

Uses the google-genai SDK. Supports two modes:
  1. Vertex AI mode (GCP_PROJECT_ID set) — uses $300 free credit, preferred
  2. API Key mode (GEMINI_API_KEY set, no GCP project) — fallback for simple deploys

The client is instantiated once at module import time and shared across all
service modules to avoid redundant authentication overhead.
"""

import os

from google import genai

from config import settings

# Prefer Vertex AI when GCP_PROJECT_ID is configured (uses GCP credit)
if settings.gcp_project_id:
    from google.genai.types import HttpOptions
    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
        http_options=HttpOptions(api_version="v1"),
    )
elif settings.gemini_api_key:
    # API Key mode — fallback when no GCP project
    client = genai.Client(api_key=settings.gemini_api_key)
else:
    raise RuntimeError(
        "No Gemini credentials configured. "
        "Set GCP_PROJECT_ID for Vertex AI mode, or GEMINI_API_KEY for API key mode."
    )

# Model identifier used across all chain steps.
MODEL = settings.gemini_model
