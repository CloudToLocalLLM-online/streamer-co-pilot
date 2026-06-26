"""Event bus: typed event model and async pub/sub for all platform events."""

from __future__ import annotations
import json
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Callable, Awaitable
import asyncio
import logging

logger = logging.getLogger(__name__)


class EventType(str, Enum):
    DONATION = "donation"
    FOLLOW = "follow"
    SUBSCRIPTION = "subscription"
    SUBSCRIPTION_GIFT = "subscription_gift"
    RAID = "raid"
    HOST = "host"
    CHEER = "cheer"
    BITS = "bits"


@dataclass
class PlatformEvent:
    """Normalised cross-platform event."""

    type: EventType
    user_name: str
    user_id: str = ""
    amount: float = 0.0
    currency: str = "USD"
    message: str = ""
    tier: str = ""
    months: int = 0
    cumulative_months: int = 0
    gifter_name: str = ""
    raid_viewers: int = 0
    host_viewers: int = 0
    cheer_amount: int = 0
    source: str = ""
    platform: str = field(default="twitch")
    timestamp: float = field(default_factory=lambda: __import__("time").time())

    def to_dict(self) -> dict:
        d = asdict(self)
        d["type"] = self.type.value
        return d

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), default=str)

    @classmethod
    def from_dict(cls, d: dict) -> "PlatformEvent":
        d = dict(d)
        if isinstance(d.get("type"), str):
            d["type"] = EventType(d["type"])
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


EventHandler = Callable[[PlatformEvent], Awaitable[None]]


class EventBus:
    """Async pub/sub for platform events."""

    def __init__(self):
        self._subscribers: list[EventHandler] = []
        self._history: list[PlatformEvent] = []
        self._max_history = 200

    def subscribe(self, handler: EventHandler):
        self._subscribers.append(handler)

    def unsubscribe(self, handler: EventHandler):
        if handler in self._subscribers:
            self._subscribers.remove(handler)

    async def publish(self, event: PlatformEvent):
        self._history.append(event)
        if len(self._history) > self._max_history:
            self._history = self._history[-self._max_history:]
        results = await asyncio.gather(
            *[handler(event) for handler in self._subscribers],
            return_exceptions=True,
        )
        for i, r in enumerate(results):
            if isinstance(r, Exception):
                logger.error("EventBus subscriber[%d] error: %s", i, r)

    def recent_events(self, count: int = 50) -> list[PlatformEvent]:
        return list(reversed(self._history[-count:]))


# Singleton
event_bus = EventBus()