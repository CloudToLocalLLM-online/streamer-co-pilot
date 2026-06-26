"""Alert manager: handles visual/audio event alerts with customisation.

Provides per-event toggle, duration control, sound effects, and TTS.
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Optional

from events import EventBus, PlatformEvent, EventType

logger = logging.getLogger(__name__)


# ── Alert model ──

class AlertEvent:
    """Serialisable alert ready for overlay consumption."""

    def __init__(
        self,
        event_type: str,
        user_name: str,
        title: str,
        message: str = "",
        image_url: str = "",
        amount: float = 0.0,
        currency: str = "",
        sub_tier: str = "",
        raid_viewers: int = 0,
        duration: float = 8.0,
        sound_url: str = "",
        tts_text: str = "",
        alert_id: str = "",
    ):
        self.event_type = event_type
        self.user_name = user_name
        self.title = title
        self.message = message
        self.image_url = image_url
        self.amount = amount
        self.currency = currency
        self.sub_tier = sub_tier
        self.raid_viewers = raid_viewers
        self.duration = duration
        self.sound_url = sound_url
        self.tts_text = tts_text
        self.alert_id = alert_id

    def to_dict(self) -> dict:
        return {k: v for k, v in self.__dict__.items()}

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), default=str)


class AlertConfig:
    """Per-event-type customisation."""

    def __init__(
        self,
        enabled: bool = True,
        duration: float = 8.0,
        sound_url: str = "",
        tts_enabled: bool = False,
        tts_prefix: str = "",
    ):
        self.enabled = enabled
        self.duration = duration
        self.sound_url = sound_url
        self.tts_enabled = tts_enabled
        self.tts_prefix = tts_prefix

    def to_dict(self) -> dict:
        return {k: v for k, v in self.__dict__.items() if not k.startswith("_")}


class AlertManager:
    """Manages event-to-alert conversion with per-event customisation."""

    def __init__(self, event_bus: EventBus):
        self.bus = event_bus
        self._latest_alert: Optional[AlertEvent] = None
        self._alert_queue: asyncio.Queue[AlertEvent] = asyncio.Queue()
        self._alert_id_counter = 0

        # Default configs
        self.configs: dict[str, AlertConfig] = {
            "donation": AlertConfig(duration=10.0, tts_enabled=True, tts_prefix="Donation from"),
            "follow": AlertConfig(duration=6.0, tts_enabled=False, tts_prefix="New follower"),
            "subscription": AlertConfig(duration=8.0, tts_enabled=True, tts_prefix="New subscriber"),
            "subscription_gift": AlertConfig(duration=8.0, tts_enabled=True, tts_prefix="Gift sub from"),
            "raid": AlertConfig(duration=8.0, tts_enabled=True, tts_prefix="Raid from"),
            "host": AlertConfig(duration=6.0, tts_enabled=True, tts_prefix="Host from"),
            "cheer": AlertConfig(duration=8.0, tts_enabled=True, tts_prefix="Cheers from"),
            "bits": AlertConfig(duration=6.0, tts_enabled=False, tts_prefix="Bits from"),
        }

        # Subscribe to events
        self.bus.subscribe(self._handle_event)

    def _next_alert_id(self) -> str:
        self._alert_id_counter += 1
        return f"alert_{self._alert_id_counter}_{asyncio.get_event_loop().time():.0f}"

    async def _handle_event(self, event: PlatformEvent):
        cfg = self.configs.get(event.type.value)
        if not cfg or not cfg.enabled:
            return

        title = self._build_title(event)
        tts_text = self._build_tts(event, cfg)
        sound = self._find_sound(event.type, cfg)

        alert = AlertEvent(
            event_type=event.type.value,
            user_name=event.user_name,
            title=title,
            message=event.message,
            amount=event.amount,
            currency=event.currency,
            sub_tier=event.tier,
            raid_viewers=event.raid_viewers,
            duration=cfg.duration,
            sound_url=sound,
            tts_text=tts_text,
            alert_id=self._next_alert_id(),
        )

        self._latest_alert = alert
        await self._alert_queue.put(alert)

    def _build_title(self, event: PlatformEvent) -> str:
        templates = {
            EventType.DONATION: f"{event.user_name} donated ${event.amount:.2f}",
            EventType.FOLLOW: f"{event.user_name} followed!",
            EventType.SUBSCRIPTION: f"{event.user_name} subscribed! (Tier {event.tier})",
            EventType.SUBSCRIPTION_GIFT: f"{event.gifter_name} gifted a sub to {event.user_name}!",
            EventType.RAID: f"{event.user_name} raided! ({event.raid_viewers} viewers)",
            EventType.HOST: f"{event.user_name} hosted! ({event.host_viewers} viewers)",
            EventType.CHEER: f"{event.user_name} cheered {event.cheer_amount} bits!",
            EventType.BITS: f"{event.user_name} used {event.cheer_amount} bits!",
        }
        return templates.get(event.type, f"Event from {event.user_name}")

    def _build_tts(self, event: PlatformEvent, cfg: AlertConfig) -> str:
        if not cfg.tts_enabled:
            return ""
        templates = {
            EventType.DONATION: f"{cfg.tts_prefix} {event.user_name}: {event.message}" if event.message else f"{cfg.tts_prefix} {event.user_name}, ${event.amount:.2f}",
            EventType.FOLLOW: f"{cfg.tts_prefix}: {event.user_name}",
            EventType.SUBSCRIPTION: f"{cfg.tts_prefix} {event.user_name}",
            EventType.RAID: f"{cfg.tts_prefix} {event.user_name} with {event.raid_viewers} viewers",
        }
        return templates.get(event.type, f"{cfg.tts_prefix} {event.user_name}")

    def _find_sound(self, event_type: EventType, cfg: AlertConfig) -> str:
        if cfg.sound_url:
            return cfg.sound_url
        sounds = {
            EventType.DONATION: "/sounds/cha-ching.mp3",
            EventType.FOLLOW: "/sounds/follow.mp3",
            EventType.SUBSCRIPTION: "/sounds/sub.mp3",
            EventType.RAID: "/sounds/raid.mp3",
        }
        return sounds.get(event_type, "")

    async def next_alert(self) -> AlertEvent:
        return await self._alert_queue.get()

    def peek_latest(self) -> Optional[AlertEvent]:
        return self._latest_alert

    def update_config(self, event_type: str, **kwargs):
        if event_type in self.configs:
            cfg = self.configs[event_type]
            for k, v in kwargs.items():
                if hasattr(cfg, k):
                    setattr(cfg, k, v)

    def get_configs(self) -> dict:
        return {k: v.to_dict() for k, v in self.configs.items()}