from typing import Dict
from fastapi import WebSocket
import logging

logger = logging.getLogger("ai_service")

class ConnectionManager:
    def __init__(self):
        # Map session_token -> WebSocket connection
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, token: str):
        await websocket.accept()
        self.active_connections[token] = websocket
        logger.info(f"WebSocket connected for token: {token}")

    def disconnect(self, token: str):
        if token in self.active_connections:
            del self.active_connections[token]
            logger.info(f"WebSocket disconnected for token: {token}")

    async def send_message(self, message: dict, token: str):
        if token in self.active_connections:
            await self.active_connections[token].send_json(message)

manager = ConnectionManager()