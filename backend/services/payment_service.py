"""Server-side Razorpay payment orchestration.

Responsibilities:
  - Create Razorpay orders (amount ALWAYS read from Firestore, never from client)
  - Verify payment signatures via HMAC-SHA256 (PAY-02)
  - Verify webhook signatures (PAY-03)
  - Update consultation status using an idempotent state machine (PAY-04)

PAY-04 state machine transitions:
  pending  -> captured | failed
  captured -> (terminal — no further transitions)
  failed   -> pending  (retry allowed)
"""

import razorpay
import structlog
from firebase_admin import firestore

from config import settings

log = structlog.get_logger(__name__)

# Lazy-initialised so import doesn't fail if env vars are missing at test time.
_razorpay_client: razorpay.Client | None = None


def _client() -> razorpay.Client:
    global _razorpay_client
    if _razorpay_client is None:
        _razorpay_client = razorpay.Client(
            auth=(settings.razorpay_key_id, settings.razorpay_key_secret)
        )
    return _razorpay_client


# ---------------------------------------------------------------------------
# PAY-04: Idempotent payment state machine
# ---------------------------------------------------------------------------

VALID_TRANSITIONS: dict[str, set[str]] = {
    "pending": {"captured", "failed"},
    "captured": set(),      # terminal — no further transitions
    "failed": {"pending"},  # retry is allowed
}


def can_transition(current: str, target: str) -> bool:
    """Return True if the transition from *current* to *target* is valid."""
    return target in VALID_TRANSITIONS.get(current, set())


# ---------------------------------------------------------------------------
# Order creation
# ---------------------------------------------------------------------------

def create_order(consultation_id: str, amount_paise: int) -> dict:
    """Create a Razorpay order.

    Amount is always supplied by the caller after reading from Firestore —
    it is NEVER sourced from the HTTP request body (prevents client-side
    price tampering).

    Args:
        consultation_id: Firestore document ID used as the Razorpay receipt.
        amount_paise: Amount in Indian paise (INR × 100).

    Returns:
        The full Razorpay order dict including ``id``, ``amount``, ``currency``.
    """
    order = _client().order.create({
        "amount": amount_paise,
        "currency": "INR",
        "receipt": consultation_id,
    })
    log.info(
        "razorpay_order_created",
        order_id=order["id"],
        consultation_id=consultation_id,
        amount_paise=amount_paise,
    )
    return order


# ---------------------------------------------------------------------------
# Signature verification
# ---------------------------------------------------------------------------

def verify_signature(order_id: str, payment_id: str, signature: str) -> bool:
    """Verify a Razorpay payment signature using HMAC-SHA256.

    Args:
        order_id: ``razorpay_order_id`` from the Razorpay checkout response.
        payment_id: ``razorpay_payment_id`` from the Razorpay checkout response.
        signature: ``razorpay_signature`` from the Razorpay checkout response.

    Returns:
        True if the signature is valid, False otherwise.
    """
    try:
        _client().utility.verify_payment_signature({
            "razorpay_order_id": order_id,
            "razorpay_payment_id": payment_id,
            "razorpay_signature": signature,
        })
        return True
    except razorpay.errors.SignatureVerificationError:
        log.warning(
            "signature_verification_failed",
            order_id=order_id,
            payment_id=payment_id,
        )
        return False


def verify_webhook(body: bytes, signature: str) -> bool:
    """Verify a Razorpay webhook signature.

    Args:
        body: Raw request body bytes (must NOT be decoded before passing).
        signature: Value of the ``x-razorpay-signature`` header.

    Returns:
        True if the signature matches, False otherwise.
    """
    try:
        _client().utility.verify_webhook_signature(
            body.decode("utf-8"), signature, settings.razorpay_webhook_secret
        )
        return True
    except razorpay.errors.SignatureVerificationError:
        log.warning("webhook_signature_failed")
        return False


# ---------------------------------------------------------------------------
# Consultation status — idempotent update via state machine
# ---------------------------------------------------------------------------

def update_consultation_status(
    consultation_id: str,
    new_status: str,
    payment_id: str = "",
) -> bool:
    """Update a consultation's payment status using the state machine.

    Idempotent: if the consultation is already in *new_status*, returns True
    without writing.  If the transition is invalid, returns False without
    writing.

    Args:
        consultation_id: Firestore document ID of the consultation.
        new_status: Target status (``captured`` or ``failed``).
        payment_id: Razorpay payment ID to store alongside the status update.

    Returns:
        True if the update succeeded (or was already in target state),
        False if the document was not found or transition was invalid.
    """
    db = firestore.client()
    doc_ref = db.collection("consultations").document(consultation_id)
    doc = doc_ref.get()

    if not doc.exists:
        log.error("consultation_not_found", consultation_id=consultation_id)
        return False

    data = doc.to_dict() or {}
    current_status = data.get("status", "pending")

    # Idempotent: already in desired state
    if current_status == new_status:
        log.info(
            "consultation_status_already_set",
            consultation_id=consultation_id,
            status=new_status,
        )
        return True

    if not can_transition(current_status, new_status):
        log.warning(
            "invalid_transition",
            consultation_id=consultation_id,
            current=current_status,
            target=new_status,
        )
        return False

    update_data: dict = {
        "status": new_status,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if payment_id:
        update_data["paymentId"] = payment_id

    doc_ref.update(update_data)
    log.info(
        "consultation_status_updated",
        consultation_id=consultation_id,
        old_status=current_status,
        new_status=new_status,
        payment_id=payment_id or None,
    )
    return True
