from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from app.ws_manager import manager
from app.models import SessionInfo
from pydantic import BaseModel
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import logging

router = APIRouter()
logger = logging.getLogger("ai_service")

# In-memory storage for active capture sessions
# token -> { "session_info": dict, "created_at": datetime }
capture_sessions: Dict[str, Any] = {}
SESSION_TTL = 3600  # 1 hour default

class CaptureStartRequest(BaseModel):
    session: SessionInfo

class ImageUploadRequest(BaseModel):
    image: str


def _cleanup_sessions() -> None:
    if not capture_sessions:
        return

    now = datetime.utcnow()
    expired = [
        token
        for token, data in capture_sessions.items()
        if (now - data["created_at"]).total_seconds() > SESSION_TTL
    ]
    for token in expired:
        logger.info("Expiring capture session %s", token)
        capture_sessions.pop(token, None)


def _get_capture_session(token: str) -> Optional[Dict[str, Any]]:
    _cleanup_sessions()
    session = capture_sessions.get(token)
    if session is None:
        return None

    age = (datetime.utcnow() - session["created_at"]).total_seconds()
    if age > SESSION_TTL:
        logger.info("Capture session %s expired (age %.1fs)", token, age)
        capture_sessions.pop(token, None)
        return None
    return session

@router.post("/capture/start")
async def start_capture_session(request: CaptureStartRequest):
    _cleanup_sessions()
    token = str(uuid.uuid4())
    capture_sessions[token] = {
        "session_info": request.session.dict(),
        "created_at": datetime.utcnow(),
    }

    return {"token": token, "expires_in": SESSION_TTL}


@router.get("/capture/session/{token}")
async def fetch_capture_session(token: str):
    session = _get_capture_session(token)
    if session is None:
        raise HTTPException(status_code=404, detail="Invalid or expired session")

    try:
        return SessionInfo(**session["session_info"])
    except Exception as exc:
        logger.error("Failed to hydrate session info for token %s: %s", token, exc)
        raise HTTPException(status_code=500, detail="Corrupted session info")

@router.websocket("/ws/capture/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """
    Desktop connects here to listen for the uploaded image.
    """
    logger.info(f"WebSocket connection attempt for token: {token}")
    if _get_capture_session(token) is None:
        logger.warning(f"WebSocket rejected - token {token} not found")
        await websocket.close(code=4003) # Forbidden/Invalid
        return

    await manager.connect(websocket, token)
    logger.info(f"WebSocket connected successfully for token: {token}")
    try:
        while True:
            # Keep alive / Heartbeat
            msg = await websocket.receive_text()
            logger.debug(f"WebSocket heartbeat received: {msg}")
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for token: {token}")
        manager.disconnect(token)
    except Exception as e:
        logger.error(f"WebSocket error for token {token}: {e}")
        manager.disconnect(token)

@router.post("/capture/upload/{token}")
async def upload_capture(token: str, request: ImageUploadRequest):
    """
    Mobile phone uploads the image here.
    """
    logger.info(f"Upload request received for token: {token}")
    session = _get_capture_session(token)
    if session is None:
        logger.warning(f"Upload failed - token {token} not found")
        raise HTTPException(status_code=404, detail="Session expired or invalid")

    logger.info(f"Session found, notifying desktop via WebSocket")
    
    # Notify desktop
    try:
        await manager.send_message({
            "type": "image_received",
            "image": request.image,
            "timestamp": datetime.utcnow().isoformat()
        }, token)
        logger.info(f"Desktop notified successfully for token: {token}")
    except Exception as e:
        logger.error(f"Failed to send WebSocket message: {e}")
        raise HTTPException(status_code=500, detail="Failed to notify desktop")
    
    return {"status": "success", "message": "Image uploaded and sent to desktop"}

@router.get("/capture/validate/{token}")
async def validate_token(token: str):
    logger.info(f"Validating token: {token}")
    session = _get_capture_session(token)
    if session is None:
        logger.warning(f"Token {token} not found in active sessions")
        raise HTTPException(status_code=404, detail="Invalid token")
    logger.info(f"Token {token} validated successfully")
    remaining = SESSION_TTL - int((datetime.utcnow() - session["created_at"]).total_seconds())
    return {"valid": True, "expires_in": max(0, remaining)}


def is_capture_token_active(token: str) -> bool:
    return _get_capture_session(token) is not None


async def notify_capture_watchers(token: str, payload: Dict[str, Any]) -> None:
    session = _get_capture_session(token)
    if session is None:
        raise ValueError("Invalid or expired capture token")
    await manager.send_message(payload, token)


@router.delete("/capture/session/{token}")
async def end_capture_session(token: str):
    session = capture_sessions.pop(token, None)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")

    manager.disconnect(token)
    logger.info("Capture session %s terminated by user", token)
    return {"status": "ended"}