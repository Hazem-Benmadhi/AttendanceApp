import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "AI Face Recognition Service"
    API_V1_STR: str = "/api/v1"
    
    # Face Recognition Settings
    RECOGNITION_THRESHOLD: float = 0.45  # Tuned for Cosine distance
    MODEL_NAME: str = "VGG-Face"
    DISTANCE_METRIC: str = "cosine"
    DETECTOR_BACKEND: str = "opencv"  # Primary detector (opencv, retinaface, ssd, etc.)
    # Note: Service uses multi-strategy detection with automatic fallback:
    # 1. opencv (fast) -> 2. retinaface (accurate) -> 3. opencv relaxed (fallback)
    
    # Storage Settings
    EMBEDDINGS_DIR: str = os.path.join(os.path.dirname(os.path.dirname(__file__)), "embeddings")
    TEMP_IMAGES_DIR: str = os.path.join(os.path.dirname(os.path.dirname(__file__)), "temp_images")
    
    # Firebase Settings
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "")
    
    class Config:
        case_sensitive = True

settings = Settings()

# Ensure directories exist
os.makedirs(settings.EMBEDDINGS_DIR, exist_ok=True)
os.makedirs(settings.TEMP_IMAGES_DIR, exist_ok=True)
