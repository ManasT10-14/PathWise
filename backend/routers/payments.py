"""Payment endpoints — server-side Razorpay order creation and verification.

PAY-01: POST /api/v1/payments/create-order
  Server reads the price from Firestore (never from the request body) to
  prevent client-side price tampering.

PAY-02: POST /api/v1/payments/verify
  HMAC-SHA256 signature verification via the Razorpay SDK before updating
  consultation status.
"""

import structlog
from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel

from dependencies import get_current_user
from services.payment_service import (
    create_order,
    update_consultation_status,
    verify_signature,
)

log = structlog.get_logger(__name__)

router = APIRouter(prefix="/payments", tags=["payments"])


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class CreateOrderRequest(BaseModel):
    """Body for POST /create-order."""

    consultation_id: str


class VerifyPaymentRequest(BaseModel):
    """Body for POST /verify."""

    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/create-order")
async def create_payment_order(
    body: CreateOrderRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    """Create a Razorpay order for a pending consultation.

    Price is read from the Firestore consultation document — the client
    is never trusted to supply an amount (PAY-01 anti-tampering requirement).

    Returns:
        ``{"order_id": str, "amount": int, "currency": "INR"}``
    """
    db = firestore.client()
    doc_ref = db.collection("consultations").document(body.consultation_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Consultation not found")

    data = doc.to_dict() or {}

    # Only the consultation's own user may initiate payment.
    if data.get("userId") != user["uid"]:
        log.warning(
            "unauthorized_payment_attempt",
            consultation_id=body.consultation_id,
            requester_uid=user["uid"],
            owner_uid=data.get("userId"),
        )
        raise HTTPException(
            status_code=403, detail="You can only pay for your own consultations"
        )

    # Price is always read from Firestore — NEVER from the request body.
    price = data.get("price")
    if price is None:
        raise HTTPException(
            status_code=422, detail="Consultation document is missing the price field"
        )

    amount_paise = int(float(price) * 100)

    try:
        order = create_order(body.consultation_id, amount_paise)
    except Exception as exc:
        log.error("razorpay_order_creation_failed", error=str(exc))
        raise HTTPException(
            status_code=500, detail="Failed to create payment order"
        ) from exc

    # Persist the order ID on the consultation so the webhook can look it up later.
    doc_ref.update({
        "orderId": order["id"],
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })

    log.info(
        "payment_order_created",
        consultation_id=body.consultation_id,
        order_id=order["id"],
        amount_paise=amount_paise,
    )

    return {
        "order_id": order["id"],
        "amount": order["amount"],
        "currency": "INR",
    }


@router.post("/verify")
async def verify_payment(
    body: VerifyPaymentRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    """Verify a Razorpay payment signature and update consultation status.

    Performs HMAC-SHA256 verification via the Razorpay SDK (PAY-02).
    On success, transitions the consultation to 'captured' via the state machine.

    Returns:
        ``{"status": "captured", "consultation_id": str}``
    """
    # Verify the cryptographic signature first — reject early if invalid.
    if not verify_signature(
        body.razorpay_order_id,
        body.razorpay_payment_id,
        body.razorpay_signature,
    ):
        log.warning(
            "payment_signature_invalid",
            order_id=body.razorpay_order_id,
            payment_id=body.razorpay_payment_id,
            uid=user["uid"],
        )
        raise HTTPException(status_code=400, detail="Invalid payment signature")

    # Look up the consultation by the order ID stored in Firestore.
    db = firestore.client()
    query = (
        db.collection("consultations")
        .where("orderId", "==", body.razorpay_order_id)
        .limit(1)
        .get()
    )

    if not query:
        log.error(
            "consultation_not_found_for_order",
            order_id=body.razorpay_order_id,
        )
        raise HTTPException(
            status_code=404,
            detail="No consultation found for this order ID",
        )

    consultation_doc = query[0]
    consultation_id = consultation_doc.id

    success = update_consultation_status(
        consultation_id,
        "captured",
        body.razorpay_payment_id,
    )

    if not success:
        raise HTTPException(
            status_code=409,
            detail="Unable to transition consultation to captured state",
        )

    log.info(
        "payment_verified",
        consultation_id=consultation_id,
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
    )

    return {"status": "captured", "consultation_id": consultation_id}
