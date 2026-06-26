"""Streamer Co-Pilot backend — FastAPI application.

Extends the core Twitch/Kick bot with donation/event tracking,
alert management, SSE event feed, and webhooks.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from typing import Optional

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, Response
from pydantic import BaseModel
from sse_starlette.sse import EventSourceResponse

from alerts import AlertManager
from events import EventBus, EventType, PlatformEvent, event_bus as _global_bus
from integrations.streamelements import create_streamelements_client

# ── Logging ──
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
logger = logging.getLogger("api")

# ── Config ──
load_dotenv()
PORT = int(os.getenv("TWITCH_BOT_PORT", "8510"))

# ── State ──
event_bus = _global_bus
alert_manager: AlertManager | None = None
se_client: any = None
sse_queues: list[asyncio.Queue] = []

# In-memory chat (shared with existing bot)
_recent_chat: list[dict] = []
_stream_status: dict = {"status": "unknown", "viewers": 0, "game": "", "title": ""}

# ── Lifecycle ──

@asynccontextmanager
async def lifespan(app: FastAPI):
    global alert_manager, se_client
    alert_manager = AlertManager(event_bus)
    se_client = create_streamelements_client(os.environ, event_bus)
    if se_client:
        await se_client.start()
    logger.info("Donations & events backend started")
    yield
    if se_client:
        await se_client.stop()
    logger.info("Donations & events backend stopped")


app = FastAPI(title="Streamer Co-Pilot", version="1.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── SSE helpers ──

async def _broadcast_event(event_type: str, data: dict):
    """Push an SSE event to all connected clients."""
    payload = json.dumps(data, default=str)
    dead: list[int] = []
    for i, q in enumerate(sse_queues):
        try:
            q.put_nowait({"event": event_type, "data": payload})
        except asyncio.QueueFull:
            dead.append(i)
    for i in reversed(dead):
        sse_queues.pop(i)


# ── Wire up event bus to SSE ──

async def _event_to_sse(event: PlatformEvent):
    await _broadcast_event(event.type.value, event.to_dict())


# ── REST models ──

class DonationEvent(BaseModel):
    """Incoming donation from external webhook."""
    source: str = "manual"
    user_name: str
    amount: float
    currency: str = "USD"
    message: str = ""


class AlertConfigUpdate(BaseModel):
    event_type: str
    enabled: Optional[bool] = None
    duration: Optional[float] = None
    sound_url: Optional[str] = None
    tts_enabled: Optional[bool] = None


# ── Routes ──

@app.get("/health")
async def health():
    return {"status": "ok", "events_enabled": True}


@app.get("/stream/status")
async def stream_status():
    return _stream_status


@app.get("/chat/recent")
async def recent_chat(count: int = 30):
    return {"messages": _recent_chat[-count:]}


@app.post("/chat/send")
async def send_chat(request: Request):
    body = await request.json()
    msg = body.get("message", "")
    if not msg:
        raise HTTPException(400, "message is required")
    return {"ok": True, "message": msg}


@app.get("/errors")
async def errors():
    return {"errors": []}


# ── Events SSE → dedicated event channel ──

@app.get("/events/stream")
async def event_stream(request: Request):
    """SSE endpoint for chat + status events (legacy consumers)."""
    # Hook event bus to SSE on first connection
    if not hasattr(app.state, "_sse_subscribed"):
        event_bus.subscribe(_event_to_sse)
        app.state._sse_subscribed = True

    queue: asyncio.Queue = asyncio.Queue(maxsize=100)
    sse_queues.append(queue)

    async def generate():
        try:
            # Initial state
            yield {"event": "status", "data": json.dumps(_stream_status)}
            yield {"event": "chat_history", "data": json.dumps({"messages": _recent_chat[-30:]})}

            while True:
                if await request.is_disconnected():
                    break
                try:
                    msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                    yield msg
                except asyncio.TimeoutError:
                    yield {"comment": "heartbeat"}
        finally:
            if queue in sse_queues:
                sse_queues.remove(queue)

    return EventSourceResponse(generate())


# ── Events-only SSE (for donation/event overlay) ──

@app.get("/events/live")
async def live_events(request: Request):
    """SSE endpoint for donation/event data only — leaner for overlay."""
    if not hasattr(app.state, "_sse_subscribed"):
        event_bus.subscribe(_event_to_sse)
        app.state._sse_subscribed = True

    queue: asyncio.Queue = asyncio.Queue(maxsize=100)
    sse_queues.append(queue)

    async def generate():
        try:
            while True:
                if await request.is_disconnected():
                    break
                try:
                    msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                    if msg.get("event") not in ("status", "chat_history"):
                        yield msg
                except asyncio.TimeoutError:
                    yield {"comment": "heartbeat"}
        finally:
            if queue in sse_queues:
                sse_queues.remove(queue)

    return EventSourceResponse(generate())


# ── Alert management ──

@app.get("/alerts/latest")
async def latest_alert():
    """Get the most recent alert."""
    if not alert_manager:
        return {"alert": None}
    alert = alert_manager.peek_latest()
    return {"alert": alert.to_dict() if alert else None}


@app.get("/alerts/queue")
async def alert_queue():
    """Get pending alerts from the queue (non-destructive peek)."""
    alerts: list[dict] = []
    if alert_manager:
        try:
            while True:
                a = alert_manager._alert_queue.get_nowait()
                alerts.append(a.to_dict())
        except asyncio.QueueEmpty:
            pass
    return {"alerts": alerts}


@app.get("/alerts/config")
async def get_alert_configs():
    if not alert_manager:
        return {"configs": {}}
    return {"configs": alert_manager.get_configs()}


@app.post("/alerts/config")
async def update_alert_config(update: AlertConfigUpdate):
    if not alert_manager:
        raise HTTPException(503, "Alert manager not ready")
    kwargs = update.model_dump(exclude={"event_type"}, exclude_none=True)
    alert_manager.update_config(update.event_type, **kwargs)
    return {"ok": True}


# ── Donations ──

@app.post("/donations/manual")
async def manual_donation(event: DonationEvent):
    """Inject a donation event manually (for testing or external tooling)."""
    pe = PlatformEvent(
        type=EventType.DONATION,
        user_name=event.user_name,
        amount=event.amount,
        currency=event.currency,
        message=event.message,
        source=event.source,
    )
    await event_bus.publish(pe)
    return {"ok": True, "event": pe.to_dict()}


@app.get("/donations/recent")
async def recent_donations(limit: int = 20):
    """Get recent donation events."""
    events = event_bus.recent_events(limit)
    return {"donations": [e.to_dict() for e in events if e.type == EventType.DONATION]}


# ── Webhooks ──

@app.post("/webhooks/streamelements")
async def streamelements_webhook(request: Request):
    """Receive StreamElements webhook events."""
    if not se_client:
        raise HTTPException(503, "StreamElements not configured")
    body = await request.json()
    ok = await se_client.handle_webhook(body)
    return {"ok": ok}


@app.post("/webhooks/streamlabs")
async def streamlabs_webhook(request: Request):
    """Receive StreamLabs webhook events."""
    body = await request.json()
    event_type = body.get("type", "")
    data = body.get("message", [{}])
    message = data[0] if isinstance(data, list) else data

    mapping = {
        "donation": EventType.DONATION,
        "follow": EventType.FOLLOW,
        "subscription": EventType.SUBSCRIPTION,
        "bits": EventType.CHEER,
        "host": EventType.HOST,
        "raid": EventType.RAID,
    }

    et = mapping.get(event_type)
    if not et:
        return {"ok": False, "reason": f"Unknown event type: {event_type}"}

    event = PlatformEvent(
        type=et,
        user_name=message.get("name", message.get("from", "Anonymous")),
        user_id=message.get("id", ""),
        amount=float(message.get("amount", 0)),
        currency=message.get("currency", "USD"),
        message=message.get("message", ""),
        tier=str(message.get("sub_plan", "")),
        months=int(message.get("months", 1)),
        raid_viewers=int(message.get("raiders", 0)),
        source="streamlabs",
    )
    await event_bus.publish(event)
    return {"ok": True}


@app.get("/events/history")
async def event_history(limit: int = 50):
    """Get recent platform events."""
    events = event_bus.recent_events(limit)
    return {"events": [e.to_dict() for e in events]}


# ── Static overlay (for OBS) ──

@app.get("/overlay/alerts")
async def overlay_alerts():
    """Serve the event alerts overlay for OBS browser source."""
    html = _ALERTS_OVERLAY_HTML
    return HTMLResponse(html)


# ── TTS proxy ──

@app.post("/tts/generate")
async def generate_tts(request: Request):
    """Generate TTS audio from text (returns mp3 bytes or a URL)."""
    body = await request.json()
    text = body.get("text", "")
    voice = body.get("voice", "en-US-JennyNeural")
    if not text:
        raise HTTPException(400, "text is required")

    try:
        import edge_tts
        communicate = edge_tts.Communicate(text, voice)
        audio_data = b""
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_data += chunk["data"]
        return Response(content=audio_data, media_type="audio/mpeg")
    except ImportError:
        # Fallback — return download URL
        return JSONResponse({
            "url": f"https://api.streamelements.com/kappa/v2/speech?voice={voice}&text={text[:200]}",
        })


# ── Static files ──

@app.get("/sounds/{filename}")
async def serve_sound(filename: str):
    sound_dir = os.path.join(os.path.dirname(__file__), "static", "sounds")
    path = os.path.join(sound_dir, filename)
    if not os.path.exists(path):
        raise HTTPException(404, "Sound not found")
    with open(path, "rb") as f:
        return Response(content=f.read(), media_type="audio/mpeg")


# ── Embedded alert overlay HTML ──

_ALERTS_OVERLAY_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SCP Alerts Overlay</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');
  body {
    font-family: 'Inter', -apple-system, sans-serif;
    background: transparent;
    overflow: hidden;
    width: 1920px; height: 1080px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  #alert-container {
    position: relative;
    width: 800px;
    text-align: center;
    opacity: 0;
    transform: scale(0.8) translateY(20px);
    transition: all 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  }
  #alert-container.show {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
  #alert-container.hide {
    opacity: 0;
    transform: scale(1.1) translateY(-20px);
    transition: all 0.3s ease-in;
  }
  .alert-card {
    background: linear-gradient(135deg, rgba(20, 20, 40, 0.92), rgba(40, 20, 60, 0.92));
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 24px;
    padding: 40px 48px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.5);
  }
  .alert-type-badge {
    display: inline-block;
    padding: 6px 16px;
    border-radius: 20px;
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 12px;
  }
  .alert-type-badge.donation { background: #f59e0b; color: #000; }
  .alert-type-badge.follow { background: #3b82f6; color: #fff; }
  .alert-type-badge.subscription { background: #8b5cf6; color: #fff; }
  .alert-type-badge.raid { background: #ef4444; color: #fff; }
  .alert-type-badge.cheer { background: #10b981; color: #fff; }
  .alert-user {
    font-size: 36px;
    font-weight: 800;
    color: #fff;
    margin-bottom: 8px;
  }
  .alert-title {
    font-size: 22px;
    color: #ddd;
    margin-bottom: 8px;
  }
  .alert-amount {
    font-size: 48px;
    font-weight: 800;
    background: linear-gradient(135deg, #f59e0b, #f97316);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin: 8px 0;
  }
  .alert-message {
    font-size: 18px;
    color: #bbb;
    font-style: italic;
    margin-top: 8px;
    max-height: 80px;
    overflow-y: auto;
  }
  .alert-timer {
    width: 100%;
    height: 4px;
    background: rgba(255,255,255,0.1);
    border-radius: 2px;
    margin-top: 24px;
    overflow: hidden;
  }
  .alert-timer-bar {
    height: 100%;
    background: linear-gradient(90deg, #8b5cf6, #f59e0b);
    border-radius: 2px;
    transition: width 0.1s linear;
  }
</style>
</head>
<body>
<div id="alert-container">
  <div class="alert-card">
    <div id="type-badge" class="alert-type-badge">Event</div>
    <div id="user-name" class="alert-user">User</div>
    <div id="alert-title" class="alert-title">Did something!</div>
    <div id="alert-amount" class="alert-amount" style="display:none;"></div>
    <div id="alert-message" class="alert-message"></div>
    <div class="alert-timer">
      <div id="timer-bar" class="alert-timer-bar" style="width:100%;"></div>
    </div>
  </div>
</div>

<script>
const params = new URLSearchParams(window.location.search);
const BOT_URL = params.get('url') || 'http://localhost:8510';
const ALERT_DEFAULT_DURATION = parseFloat(params.get('duration')) || 8;
const container = document.getElementById('alert-container');
const typeBadge = document.getElementById('type-badge');
const userName = document.getElementById('user-name');
const alertTitle = document.getElementById('alert-title');
const alertAmount = document.getElementById('alert-amount');
const alertMessage = document.getElementById('alert-message');
const timerBar = document.getElementById('timer-bar');

let currentTimeout = null;
let currentAudio = null;
let isShowing = false;

function showAlert(alert) {
  if (currentTimeout) clearTimeout(currentTimeout);
  if (currentAudio) { currentAudio.pause(); currentAudio = null; }

  const duration = alert.duration || ALERT_DEFAULT_DURATION;

  // Set content
  typeBadge.textContent = alert.event_type.toUpperCase();
  typeBadge.className = 'alert-type-badge ' + alert.event_type;
  userName.textContent = alert.user_name;
  alertTitle.textContent = alert.title;

  if (alert.amount > 0 && ['donation', 'cheer'].includes(alert.event_type)) {
    alertAmount.style.display = 'block';
    alertAmount.textContent = alert.currency
      ? alert.currency + ' ' + alert.amount.toFixed(2)
      : '$' + alert.amount.toFixed(2);
  } else {
    alertAmount.style.display = 'none';
  }

  alertMessage.textContent = alert.message || '';

  // Play sound
  if (alert.sound_url && alert.sound_url.startsWith('http')) {
    currentAudio = new Audio(alert.sound_url);
    currentAudio.volume = 0.7;
    currentAudio.play().catch(() => {});
  }

  // Show animation
  container.className = 'show';
  isShowing = true;

  // Timer
  const startTime = Date.now();
  function updateTimer() {
    const elapsed = Date.now() - startTime;
    const remaining = Math.max(0, 1 - elapsed / (duration * 1000));
    timerBar.style.width = (remaining * 100) + '%';
    if (remaining > 0) {
      requestAnimationFrame(updateTimer);
    }
  }
  requestAnimationFrame(updateTimer);

  // Auto-hide
  currentTimeout = setTimeout(() => {
    container.className = 'hide';
    isShowing = false;
    setTimeout(() => {
      container.className = '';
    }, 300);
  }, duration * 1000);
}

// SSE connection for events
let eventSource = null;
function connect() {
  if (eventSource) eventSource.close();
  eventSource = new EventSource(BOT_URL + '/events/live');

  const eventTypes = ['donation', 'follow', 'subscription', 'subscription_gift', 'raid', 'host', 'cheer', 'bits'];
  eventTypes.forEach(type => {
    eventSource.addEventListener(type, (e) => {
      try {
        const event = JSON.parse(e.data);
        showAlert(event);
      } catch (err) {
        console.error('Alert parse error:', err);
      }
    });
  });

  eventSource.onerror = () => {
    setTimeout(connect, 5000);
  };
}

connect();
</script>
</body>
</html>"""


# ── Entry ──

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)