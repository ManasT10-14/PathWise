"""Learner memory read/write operations for the adaptive intelligence system.

Manages the users/{uid}/learner_memory subcollection which stores:
  - analysis_history: snapshots of past roadmap analyses (max 10)
  - expert_annotations: mentor/expert notes on specific milestones

These memory documents are injected into the replan prompt chain so that
future roadmap adjustments take into account the learner's full history.

All functions are synchronous (matching the google-genai SDK pattern).
Memory read/write failure must never fail the primary API operation —
callers must wrap in try/except.
"""

import structlog
from firebase_admin import firestore
from google.cloud.firestore_v1 import ArrayUnion

log = structlog.get_logger(__name__)

_MAX_HISTORY_ENTRIES = 10


def write_analysis_memory(user_id: str, chain_result: dict, roadmap_id: str) -> None:
    """Append an analysis snapshot to users/{uid}/learner_memory/analysis_history.

    Reads the existing document, appends the new entry (trimming to at most
    _MAX_HISTORY_ENTRIES, dropping oldest), and rewrites the document.

    On the first call the document won't exist — uses set() with merge=False
    to create it fresh.

    Args:
        user_id: Firebase UID of the learner.
        chain_result: The dict returned by run_analysis_chain() containing
            "goal" (GoalAnalysis), "gaps" (SkillGapAnalysis),
            "roadmap" (RoadmapPlan), "resources" (CuratedResources).
        roadmap_id: Firestore document ID of the newly written roadmap.
    """
    goal = chain_result["goal"]
    gaps = chain_result["gaps"]
    roadmap = chain_result["roadmap"]

    new_entry = {
        "roadmap_id": roadmap_id,
        "target_role": goal.target_role,
        "gap_count": len(gaps.gaps),
        "phase_count": len(roadmap.phases),
        "analyzed_at": firestore.SERVER_TIMESTAMP,
    }

    db = firestore.client()
    doc_ref = (
        db.collection("users")
        .document(user_id)
        .collection("learner_memory")
        .document("analysis_history")
    )

    existing_doc = doc_ref.get()
    if existing_doc.exists:
        existing_entries = existing_doc.to_dict().get("entries", [])
    else:
        existing_entries = []

    # Append new entry, then trim to keep only the most recent N entries.
    # We append first (before trim) so the new entry is always included.
    updated_entries = existing_entries + [new_entry]
    if len(updated_entries) > _MAX_HISTORY_ENTRIES:
        updated_entries = updated_entries[-_MAX_HISTORY_ENTRIES:]

    doc_ref.set({"entries": updated_entries}, merge=False)

    log.info("memory_written", user_id=user_id, roadmap_id=roadmap_id, entry_count=len(updated_entries))


def write_expert_annotation(
    user_id: str,
    roadmap_id: str,
    milestone_level: str,
    annotation_text: str,
    expert_id: str,
) -> None:
    """Append an expert annotation to users/{uid}/learner_memory/expert_annotations.

    Uses Firestore ArrayUnion so concurrent writes from multiple experts don't
    clobber each other. If the document doesn't exist yet, set() creates it.

    Args:
        user_id: Firebase UID of the learner.
        roadmap_id: Firestore document ID of the roadmap being annotated.
        milestone_level: The roadmap phase level being annotated
            (e.g., "beginner", "intermediate", "advanced").
        annotation_text: The expert's written annotation.
        expert_id: Firebase UID of the expert writing the annotation.
    """
    annotation_entry = {
        "roadmap_id": roadmap_id,
        "milestone_level": milestone_level,
        "annotation": annotation_text,
        "expert_id": expert_id,
        "annotated_at": firestore.SERVER_TIMESTAMP,
    }

    db = firestore.client()
    doc_ref = (
        db.collection("users")
        .document(user_id)
        .collection("learner_memory")
        .document("expert_annotations")
    )

    existing_doc = doc_ref.get()
    if existing_doc.exists:
        # ArrayUnion appends without duplicating identical entries
        doc_ref.update({"annotations": ArrayUnion([annotation_entry])})
    else:
        doc_ref.set({"annotations": [annotation_entry]})

    log.info(
        "annotation_written",
        user_id=user_id,
        roadmap_id=roadmap_id,
        milestone_level=milestone_level,
        expert_id=expert_id,
    )


def read_learner_memory(user_id: str) -> dict:
    """Read all learner_memory subdocuments and return a merged dict for prompt injection.

    Reads analysis_history and expert_annotations from the learner_memory
    subcollection. Returns a safe empty structure on any error so that memory
    context is always treated as optional enrichment — never a hard dependency.

    Args:
        user_id: Firebase UID of the learner.

    Returns:
        Dict with keys:
            "analysis_history": list[dict] — entries from analysis_history doc, or []
            "expert_annotations": list[dict] — annotations from expert_annotations doc, or []
            "has_memory": bool — True if either list is non-empty
    """
    empty_result: dict = {
        "analysis_history": [],
        "expert_annotations": [],
        "has_memory": False,
    }

    try:
        db = firestore.client()
        memory_col = (
            db.collection("users")
            .document(user_id)
            .collection("learner_memory")
        )

        history_doc = memory_col.document("analysis_history").get()
        annotations_doc = memory_col.document("expert_annotations").get()

        analysis_history: list[dict] = []
        if history_doc.exists:
            analysis_history = history_doc.to_dict().get("entries", [])

        expert_annotations: list[dict] = []
        if annotations_doc.exists:
            expert_annotations = annotations_doc.to_dict().get("annotations", [])

        has_memory = bool(analysis_history or expert_annotations)

        log.info(
            "memory_read",
            user_id=user_id,
            history_count=len(analysis_history),
            annotation_count=len(expert_annotations),
            has_memory=has_memory,
        )

        return {
            "analysis_history": analysis_history,
            "expert_annotations": expert_annotations,
            "has_memory": has_memory,
        }

    except Exception as exc:  # noqa: BLE001
        log.warning("memory_read_failed", user_id=user_id, error=str(exc))
        return empty_result
