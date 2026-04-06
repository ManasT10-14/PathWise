"""Firestore roadmap document writer.

Writes AI-generated roadmap data to Firestore using a dual-field pattern:

  Legacy fields: Compatible with the existing Flutter Roadmap.fromFirestore() parser.
    Required fields: targetRole, milestones, resources, timeline, stageProgress,
    userId, roadmapId, createdAt, updatedAt.

  Enhanced fields: Rich structured data for the new UI (Plan 01-02).
    Fields: goalAnalysis, skillGaps, roadmapPlan, curatedResources, version, generatedBy.
    Ignored by current Flutter Roadmap.fromFirestore() but available for new code.

This dual-write pattern (Pattern 4 from 01-RESEARCH.md) ensures:
  - Existing Flutter UI works immediately (reads legacy fields)
  - New UI can access full AI output (reads enhanced fields)
  - No Flutter code changes required for Phase 01-01 to be useful
"""

import structlog
from firebase_admin import firestore

log = structlog.get_logger(__name__)


def write_roadmap(user_id: str, chain_result: dict) -> str:
    """Write a complete AI-generated roadmap to Firestore.

    Creates a new document in the `roadmaps` collection with both legacy
    and enhanced fields. Returns the new document ID.

    Args:
        user_id: Firebase UID of the user who requested the analysis.
        chain_result: Dict from run_analysis_chain with keys:
            "goal" (GoalAnalysis), "gaps" (SkillGapAnalysis),
            "roadmap" (RoadmapPlan), "resources" (CuratedResources).

    Returns:
        Firestore document ID of the newly created roadmap document.

    Raises:
        Exception: Propagates Firestore SDK errors to the router for handling.
    """
    goal = chain_result["goal"]
    gaps = chain_result["gaps"]
    roadmap = chain_result["roadmap"]
    resources = chain_result["resources"]

    db = firestore.client()

    # -----------------------------------------------------------------------
    # Legacy-compatible field construction
    # Matches the exact field names read by lib/models/roadmap.dart Roadmap.fromFirestore()
    # -----------------------------------------------------------------------

    # milestones: list of strings — format mirrors the local AiRoadmapService output
    legacy_milestones = [
        f"{phase.level.capitalize()} -- {phase.title}: {', '.join(phase.tasks[:3])}"
        for phase in roadmap.phases
    ]

    # resources: one URL per phase, mapped by phase index
    # Build an index of phase_index -> first resource URL for that phase
    phase_resource_urls: dict[int, str] = {}
    for resource in resources.resources:
        idx = resource.phase_index
        if idx not in phase_resource_urls:
            phase_resource_urls[idx] = resource.url

    # Produce a flat list in phase order, falling back to the full resources
    # list if a phase has no specific resource mapping
    all_urls = [r.url for r in resources.resources]
    legacy_resources = [
        phase_resource_urls.get(i, all_urls[i % len(all_urls)] if all_urls else "")
        for i in range(len(roadmap.phases))
    ]

    # timeline: human-readable string matching existing app format
    legacy_timeline = (
        f"Approx. {roadmap.estimated_months} months "
        f"at {roadmap.weekly_hours_recommended} hours/week"
    )

    # stageProgress: dict with milestone level keys, all starting at 0.0
    # Matches stageProgress structure used by Roadmap.fromFirestore() and structuredStages
    stage_progress = {phase.level: 0.0 for phase in roadmap.phases}

    # -----------------------------------------------------------------------
    # Compose the full Firestore document
    # -----------------------------------------------------------------------
    doc_ref = db.collection("roadmaps").document()
    doc_id = doc_ref.id

    doc_data = {
        # --- Legacy fields (required by existing Flutter Roadmap.fromFirestore) ---
        "userId": user_id,
        "roadmapId": doc_id,
        "targetRole": goal.target_role,
        "milestones": legacy_milestones,
        "resources": legacy_resources,
        "timeline": legacy_timeline,
        "stageProgress": stage_progress,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        # --- Enhanced fields (for new UI, ignored by current Flutter code) ---
        "goalAnalysis": goal.model_dump(),
        "skillGaps": gaps.model_dump(),
        "roadmapPlan": roadmap.model_dump(),
        "curatedResources": resources.model_dump(),
        "version": 2,
        "generatedBy": "gemini-2.5-flash",
    }

    doc_ref.set(doc_data)

    log.info(
        "roadmap_written",
        roadmap_id=doc_id,
        user_id=user_id,
        target_role=goal.target_role,
        phases_count=len(roadmap.phases),
    )

    return doc_id
