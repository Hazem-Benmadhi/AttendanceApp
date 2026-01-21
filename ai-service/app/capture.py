from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File, Form, Body
from app.ws_manager import manager
from app.models import SessionInfo
from pydantic import BaseModel
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any
import logging
import base64

router = APIRouter()
logger = logging.getLogger("ai_service")

# In-memory storage for active capture sessions
# token -> { "session_info": dict, "created_at": datetime }
capture_sessions: Dict[str, Any] = {}
SESSION_TTL = 300  # 5 minutes

class CaptureStartRequest(BaseModel):
    session: SessionInfo

@router.post("/capture/start")
async def start_capture_session(request: CaptureStartRequest):
    """
    Desktop calls this to start a QR capture session.
    Returns a unique token to be encoded in the QR code.
    """
    token = str(uuid.uuid4())
    capture_sessions[token] = {
        "session_info": request.session.dict(),
        "created_at": datetime.utcnow()
    }
    
    # Cleanup old sessions
    now = datetime.utcnow()
    expired = [t for t, data in capture_sessions.items() 
               if (now - data["created_at"]).total_seconds() > SESSION_TTL]
    for t in expired:
        del capture_sessions[t]

    return {"token": token, "expires_in": SESSION_TTL}

@router.websocket("/ws/capture/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """
    Desktop connects here to listen for the uploaded image.
    """
    logger.info(f"WebSocket connection attempt for token: {token}")
    if token not in capture_sessions:
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

class ImageUploadRequest(BaseModel):
    image: str

@router.post("/capture/upload/{token}")
async def upload_capture(token: str, request: ImageUploadRequest):
    """
    Mobile phone uploads the image here.
    """
    logger.info(f"Upload request received for token: {token}")
    if token not in capture_sessions:
        logger.warning(f"Upload failed - token {token} not found")
        raise HTTPException(status_code=404, detail="Session expired or invalid")

    session_data = capture_sessions[token]
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
    logger.info(f"Active sessions: {list(capture_sessions.keys())}")
    if token not in capture_sessions:
        logger.warning(f"Token {token} not found in active sessions")
        raise HTTPException(status_code=404, detail="Invalid token")
    logger.info(f"Token {token} validated successfully")
    return {"valid": True}
