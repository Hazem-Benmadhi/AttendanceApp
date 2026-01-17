from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

# Models for attendance marking
class SessionInfo(BaseModel):
    id: str = Field(..., description="Session/Seance ID from Firebase")
    nom_seance: str = Field(..., description="Session name")
    classe: str = Field(..., description="Class name")
    date: Optional[str] = None
    prof: Optional[str] = None

class MarkAttendanceRequest(BaseModel):
    image: str = Field(..., description="Base64 encoded image of student")
    session: SessionInfo = Field(..., description="Session information")

class AttendanceResult(BaseModel):
    success: bool
    student_id: Optional[str] = None
    student_name: Optional[str] = None
    confidence: float = 0.0
    status: str = Field(default="absent", description="present or absent")
    message: str
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

