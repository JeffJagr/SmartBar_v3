import hashlib
import os
from typing import Optional

from firebase_functions import https_fn
from firebase_functions.options import set_global_options
from firebase_admin import firestore, initialize_app, credentials, messaging

# Limit concurrency for cost control.
set_global_options(max_instances=10)

_app = None
_db: Optional[firestore.Client] = None
BACKFILL_TOKEN = os.environ.get("BACKFILL_TOKEN", "")
NOTIFY_TOKEN = os.environ.get("NOTIFY_TOKEN", "")


def _get_db() -> firestore.Client:
  global _app, _db
  if _db is not None:
    return _db
  if _app is None:
    # In production, default credentials are provided by the platform.
    # Locally, ensure ADC is set (gcloud auth application-default login).
    try:
      _app = initialize_app()
    except ValueError:
      # Already initialized elsewhere.
      _app = firestore.client()._client_info  # dummy to satisfy type checker
  _db = firestore.client()
  return _db


def _hash_pin(company_code: str, pin: str) -> str:
  normalized = f"{company_code.strip().upper()}::{pin.strip()}"
  return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


@https_fn.on_call()
def verify_staff_pin(req: https_fn.CallableRequest) -> dict:
  """Secure staff PIN verification via hashed lookup."""
  data = req.data or {}
  company_code = str(data.get("companyCode") or "").strip().upper()
  pin = str(data.get("pin") or "").strip()
  if not company_code or not pin:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
        message="companyCode and pin are required",
    )

  db = _get_db()
  col = db.collection("staffPins")
  pin_hash = _hash_pin(company_code, pin)

  snap = (
      col.where("companyCode", "==", company_code)
      .where("pinHash", "==", pin_hash)
      .limit(1)
      .get()
  )
  # Legacy fallback: if pinHash not present yet, check plaintext and backfill.
  if not snap:
    snap = (
        col.where("companyCode", "==", company_code)
        .where("pin", "==", pin)
        .limit(1)
        .get()
    )
    if snap:
      try:
        snap[0].reference.set({"pinHash": pin_hash, "pin": firestore.DELETE_FIELD}, merge=True)
      except Exception:
        # Best-effort backfill; ignore errors.
        pass

  if not snap:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
        message="Invalid company code or PIN",
    )

  doc = snap[0]
  payload = doc.to_dict() or {}
  return {
      "staffId": doc.id,
      "companyId": payload.get("companyId") or "",
      "displayName": payload.get("displayName") or "Staff",
      "role": payload.get("role") or "staff",
      "permissions": payload.get("permissions") or {},
  }


@https_fn.on_call()
def backfill_staff_pin_hashes(req: https_fn.CallableRequest) -> dict:
  """One-off helper to backfill pinHash and remove plaintext pins (protected by token)."""
  token = (req.data or {}).get("token")
  if not BACKFILL_TOKEN or token != BACKFILL_TOKEN:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
        message="Forbidden",
    )

  db = _get_db()
  col = db.collection("staffPins")
  docs = col.get()
  updated = 0
  cleaned = 0
  for doc in docs:
    data = doc.to_dict() or {}
    pin = data.get("pin")
    company_code = data.get("companyCode")
    if not company_code:
      continue
    if not data.get("pinHash") and pin:
      try:
        doc.reference.set(
            {"pinHash": _hash_pin(company_code, pin), "pin": firestore.DELETE_FIELD},
            merge=True,
        )
        updated += 1
      except Exception:
        continue
    elif "pin" in data:
      try:
        doc.reference.update({"pin": firestore.DELETE_FIELD})
        cleaned += 1
      except Exception:
        pass

  return {"message": f"Backfilled {updated} staffPins; cleaned {cleaned}"}


@https_fn.on_call()
def send_company_notification(req: https_fn.CallableRequest) -> dict:
  """Broadcast a simple notification to a company-scoped topic.

  Args:
    companyId: target company id.
    event: preference key, e.g. lowStock | orderCreated | orderConfirmed.
    title/body: optional notification text.
    token: must match NOTIFY_TOKEN env var to prevent abuse.
  """
  data = req.data or {}
  token = str(data.get("token") or "")
  if not NOTIFY_TOKEN or token != NOTIFY_TOKEN:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
        message="Forbidden",
    )

  company_id = str(data.get("companyId") or "").strip()
  event = str(data.get("event") or "").strip()
  title = str(data.get("title") or "SmartBar Alert")
  body = str(data.get("body") or "")
  payload = data.get("data") or {}

  if not company_id or not event:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
        message="companyId and event are required",
    )

  sanitized_company = company_id.replace(" ", "_")
  topic = f"c_{sanitized_company}_{event}"

  try:
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in payload.items()},
        topic=topic,
    )
    message_id = messaging.send(message)
    return {"messageId": message_id, "topic": topic}
  except Exception as exc:
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.INTERNAL,
        message=f"Failed to send notification: {exc}",
    )
