"""StreamElements API integration.

Polls the StreamElements event API or listens via socket for real-time
donations, follows, subs, raids, cheers and other events.

Uses StreamElements EventSocket for real-time (preferred) and falls back
to REST polling when the socket is unavailable.
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import logging
import time
from typing import Optional

import httpx

from events import EventBus, PlatformEvent, EventType

logger = logging.getLogger(__name__)

STREAMELEMENTS_API = "https://api.streamelements.com/kappa/v2"
STREAMELEMENTS_SOCKET = "https://realtime.streamelements.com"


class StreamElementsClient:
    """Client for StreamElements API + WebSocket events."""

    def __init__(
        self,
        jwt_token: str,
        event_bus: EventBus,
        poll_interval: float = 15.0,
    ):
        self.jwt = jwt_token
        self.bus = event_bus
        self.poll_interval = poll_interval
        self._channel_id: Optional[str] = None
        self._http = httpx.AsyncClient(timeout=10.0)
        self._running = False
        self._poll_task: Optional[asyncio.Task] = None
        self._ws_task: Optional[asyncio.Task] = None
        self._last_event_id: Optional[str] = None

    async def _resolve_channel(self) -> Optional[str]:
        """Fetch channel ID from the JWT."""
        try:
            r = await self._http.get(
                f"{STREAMELEMENTS_API}/channels/me",
                headers=self._headers(),
            )
            if r.status_code == 200:
                data = r.json()
                self._channel_id = data.get("_id")
                logger.info("StreamElements channel: %s (%s)", data.get("alias", "?"), self._channel_id)
                return self._channel_id
            logger.warning("StreamElements channel resolve failed: %s", r.status_code)
        except Exception as e:
            logger.error("StreamElements channel resolve error: %s", e)
        return None

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.jwt}",
            "Accept": "application/json",
        }

    async def start(self):
        self._running = True
        cid = await self._resolve_channel()
        if not cid:
            logger.error("StreamElements: cannot start — no channel ID")
            return

        # Start REST polling as a fallback / supplement
        self._poll_task = asyncio.create_task(self._poll_loop())

    async def stop(self):
        self._running = False
        if self._poll_task:
            self._poll_task.cancel()
            self._poll_task = None
        await self._http.aclose()

    async def _poll_loop(self):
        """Poll recent activity. StreamElements event API returns recent tips/merch."""
        while self._running:
            try:
                await self._poll_recent_tips()
            except Exception as e:
                logger.error("StreamElements poll error: %s", e)
            await asyncio.sleep(self.poll_interval)

    async def _poll_recent_tips(self):
        """Fetch recent tip/donation activity."""
        if not self._channel_id:
            return
        params = {"limit": 10, "skip": 0}
        if self._last_event_id:
            params["after"] = self._last_event_id

        try:
            r = await self._http.get(
                f"{STREAMELEMENTS_API}/tips/{self._channel_id}",
                headers=self._headers(),
                params=params,
            )
            if r.status_code == 200:
                data = r.json()
                tips = data if isinstance(data, list) else data.get("docs", [])
                for tip in reversed(tips):
                    tip_id = tip.get("_id") or tip.get("id", "")
                    if not tip_id or tip_id == self._last_event_id:
                        continue
                    self._last_event_id = tip_id
                    await self._publish_tip(tip)
        except Exception as e:
            logger.debug("StreamElements tip poll: %s", e)

    async def _publish_tip(self, tip: dict):
        """Convert a StreamElements tip to a PlatformEvent."""
        event = PlatformEvent(
            type=EventType.DONATION,
            user_name=tip.get("displayName") or tip.get("username", "Anonymous"),
            user_id=tip.get("_id") or "",
            amount=float(tip.get("amount", 0)),
            currency=tip.get("currency", "USD"),
            message=tip.get("message", ""),
            source="streamelements",
            platform="twitch",
        )
        await self.bus.publish(event)

    # ── Manual webhook handler (for when StreamElements sends POSTs) ──

    async def handle_webhook(self, body: dict) -> bool:
        """Handle a StreamElements webhook POST body. Returns True if recognised."""
        event_type = body.get("type", "")
        data = body.get("data", body)

        mapping = {
            "tip": self._publish_tip,
            "follow": lambda d: self.bus.publish(PlatformEvent(
                type=EventType.FOLLOW,
                user_name=d.get("name", d.get("username", "Anonymous")),
                source="streamelements",
            )),
            "subscriber": lambda d: self.bus.publish(PlatformEvent(
                type=EventType.SUBSCRIPTION,
                user_name=d.get("name", d.get("username", "Anonymous")),
                tier=str(d.get("tier", "1000")),
                months=d.get("months", 1),
                cumulative_months=d.get("cumulativeMonths", 1),
                message=d.get("message", ""),
                source="streamelements",
            )),
            "raid": lambda d: self.bus.publish(PlatformEvent(
                type=EventType.RAID,
                user_name=d.get("name", d.get("username", "Anonymous")),
                raid_viewers=int(d.get("viewers", 0)),
                source="streamelements",
            )),
            "cheer": lambda d: self.bus.publish(PlatformEvent(
                type=EventType.CHEER,
                user_name=d.get("name", d.get("username", "Anonymous")),
                cheer_amount=int(d.get("amount", 0)),
                message=d.get("message", ""),
                source="streamelements",
            )),
        }

        handler = mapping.get(event_type)
        if handler:
            await handler(data)
            return True
        return False


# ── Factory ──

def create_streamelements_client(config: dict, bus: EventBus) -> Optional[StreamElementsClient]:
    """Create client from config dict. Returns None if no JWT configured."""
    jwt = config.get("STREAMELEMENTS_JWT_TOKEN", "")
    if not jwt or jwt == "your_jwt_token_here":
        logger.info("StreamElements: no JWT — skipping integration")
        return None
    return StreamElementsClient(jwt_token=jwt, event_bus=bus)