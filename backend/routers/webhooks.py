"""Razorpay webhook handler.

PAY-03: POST /api/v1/webhooks/razorpay
  - Verifies the ``x-razorpay-signature`` header before processing any payload.
  - Processes ``payment.captured`` events idempotently via the state machine.
  - Always returns HTTP 200 to Razorpay (prevents unnecessary retries on
    business-logic failures like duplicate events or unknown consultations).
  - NO authentication dependency — requests come from Razorpay, not from users.
"""

import json

import structlog
from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from starlette.requests import Request
from starlette.responses import Response

from services.payment_service import update_consultation_status, verify_webhook

log = structlog.get_logger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/razorpay")
async def razorpay_webhook(request: Request) -> Response:
    """Process Razorpay webhook events.

    Signature verification happens before JSON parsing so that invalid
    requests are rejected early without touching any business logic.

    Supported events:
      - ``payment.captured`` — transitions consultation to 'captured'

    All other events are acknowledged with 200 and logged.
    """
    # Read raw body FIRST (before any decoding) — required for HMAC check.
    body: bytes = await request.body()
    signature: str = request.headers.get("x-razorpay-signature", "")

    if not verify_webhook(body, signature):
        log.warning("webhook_invalid_signature", signature_present=bool(signature))
        # Return 400 only for signature failures — Razorpay will not retry
        # based on 4xx responses, which is correct behaviour here.
        raise HTTPException(status_code=400, detail="Invalid webhook signature")

    try:
        payload: dict = json.loads(body)
    except json.JSONDecodeError as exc:
        log.error("webhook_json_parse_error", error=str(exc))
        # Return 200 so Razorpay stops retrying a malformed payload we can't fix.
        return Response(status_code=200)

    event: str = payload.get("event", "")
    log.info("webhook_received", event=event)

    if event == "payment.captured":
        try:
            entity: dict = payload["payload"]["payment"]["entity"]
            payment_id: str = entity.get("id", "")
            order_id: str = entity.get("order_id", "")
        except (KeyError, TypeError) as exc:
            log.error("webhook_payload_parse_error", event=event, error=str(exc))
            return Response(status_code=200)

        if not order_id:
            log.warning("webhook_missing_order_id", payment_id=payment_id)
            return Response(status_code=200)

        # Look up the consultation by the Razorpay order ID stored on the doc.
        db = firestore.client()
        query = (
            db.collection("consultations")
            .where("orderId", "==", order_id)
            .limit(1)
            .get()
        )

        if not query:
            # Unknown consultation — log and return 200 so Razorpay stops retrying.
            log.warning(
                "webhook_consultation_not_found",
                order_id=order_id,
                payment_id=payment_id,
            )
            return Response(status_code=200)

        consultation_doc = query[0]
        consultation_id: str = consultation_doc.id

        updated = update_consultation_status(
            consultation_id, "captured", payment_id
        )

        log.info(
            "webhook_payment_captured",
            consultation_id=consultation_id,
            order_id=order_id,
            payment_id=payment_id,
            status_updated=updated,
        )

    else:
        # Unhandled event — log and acknowledge.
        log.info("webhook_unhandled_event", event=event)

    # Always return 200 so Razorpay does not retry.
    return Response(status_code=200)
