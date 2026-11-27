"""Issue room credentials for the original oral-practice client in guest mode."""

import hashlib
import hmac
import os
import time
from uuid import UUID

from fastapi import FastAPI
from pydantic import BaseModel

from .rtc_gateway import issue_rtc_token


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
_app_id = os.environ["ORAL_PRACTICE_VOLC_APP_ID"]
_app_key = os.environ["ORAL_PRACTICE_VOLC_RTC_APP_KEY"]


class GuestBootstrapRequest(BaseModel):
    client_id: UUID


@app.post("/bootstrap")
def bootstrap(request: GuestBootstrapRequest) -> dict[str, str | int]:
    guest = hmac.new(
        _app_key.encode(),
        b"saypal:oral-practice:guest:" + request.client_id.bytes,
        hashlib.sha256,
    ).hexdigest()[:24]
    user_id = f"saypal_guest_{guest}"
    room_id = f"room_{user_id}"
    expires_at = int(time.time()) + 30 * 60
    return {
        "user_id": user_id,
        "room_id": room_id,
        "app_id": _app_id,
        "user_rtc_token": issue_rtc_token(
            app_id=_app_id,
            app_key=_app_key,
            room_id=room_id,
            user_id=user_id,
            expires_at=expires_at,
        ),
        "expires_at": expires_at,
    }
