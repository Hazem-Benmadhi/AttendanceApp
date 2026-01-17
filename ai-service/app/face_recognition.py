"""
Face Recognition Module

Provides face recognition capabilities with multi-strategy detection for maximum
compatibility and reliability across various image conditions.
"""

import os
import pickle
import base64
import numpy as np
import logging
from typing import List, Tuple, Optional, Dict
from io import BytesIO
from PIL import Image
from deepface import DeepFace
from app.config import settings

logger = logging.getLogger(__name__)

class FaceRecognizer:
    """
    Face recognizer with optimized caching and multi-strategy detection.
    
    Features:
    - Pre-computed embeddings: Load student embeddings from disk for instant recognition
    - Session caching: Cache embeddings during a session to avoid re-extraction
    - Multi-strategy detection: Tries multiple detectors for maximum reliability
    """
    
    def __init__(self):
        """Initialize the face recognizer and load pre-computed embeddings."""
        self.embeddings: Dict[str, List[float]] = {}  # Pre-computed embeddings from disk
        self.session_cache: Dict[str, Dict[str, List[float]]] = {}  # Session-based cache
        self.load_embeddings()

    def load_embeddings(self):
        """Load pre-computed embeddings from disk for fast recognition."""
        self.embeddings = {}
        if not os.path.exists(settings.EMBEDDINGS_DIR):
            os.makedirs(settings.EMBEDDINGS_DIR)
            return

        for filename in os.listdir(settings.EMBEDDINGS_DIR):
            if filename.endswith(".pkl"):
                student_id = filename[:-4]
                try:
                    with open(os.path.join(settings.EMBEDDINGS_DIR, filename), "rb") as f:
                        embedding = pickle.load(f)
                        self.embeddings[student_id] = embedding
                except Exception as e:
                    logger.error(f"Failed to load embedding for {student_id}: {e}")
        
        logger.info(f"Loaded {len(self.embeddings)} pre-computed embeddings from disk")

    def _base64_to_image(self, base64_string: str) -> np.ndarray:
        """
        Convert base64 string to numpy array.
        
        Args:
            base64_string: Base64 encoded image (with or without data URI prefix)
            
        Returns:
            Image as numpy array in RGB format
        """
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
        
        image_data = base64.b64decode(base64_string)
        image = Image.open(BytesIO(image_data))
        
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        return np.array(image)

    @staticmethod
    def compute_cosine_distance(embedding1: List[float], embedding2: List[float]) -> float:
        """
        Calculate cosine distance between two embeddings.
        
        Args:
            embedding1: First face embedding
            embedding2: Second face embedding
            
        Returns:
            Cosine distance (0.0 = identical, 1.0 = completely different)
        """
        a = np.array(embedding1)
        b = np.array(embedding2)
        return 1 - (np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
    
    def extract_embedding(self, image_input) -> Optional[List[float]]:
        """
        Extract face embedding using multi-strategy detection.
        
        Tries multiple detection backends in order for maximum reliability:
        1. OpenCV: Fast, works for most clear images
        2. RetinaFace: More accurate, handles challenging conditions
        3. Relaxed: Last resort for edge cases
        
        Args:
            image_input: Image as numpy array or file path
            
        Returns:
            Face embedding as list of floats, or None if no face detected
        """
        # Strategy 1: OpenCV (fast, primary detector)
        try:
            embedding_objs = DeepFace.represent(
                img_path=image_input,
                model_name=settings.MODEL_NAME,
                enforce_detection=True,
                detector_backend='opencv'
            )
            
            if embedding_objs and len(embedding_objs) > 0:
                logger.debug("Face detected with opencv detector")
                return embedding_objs[0]["embedding"]
                
        except Exception as e:
            logger.debug(f"OpenCV detection failed: {str(e)[:100]}")
        
        # Strategy 2: RetinaFace (accurate, fallback for challenging images)
        try:
            embedding_objs = DeepFace.represent(
                img_path=image_input,
                model_name=settings.MODEL_NAME,
                enforce_detection=True,
                detector_backend='retinaface'
            )
            
            if embedding_objs and len(embedding_objs) > 0:
                logger.info("Face detected with retinaface detector (fallback)")
                return embedding_objs[0]["embedding"]
                
        except Exception as e:
            logger.debug(f"RetinaFace detection failed: {str(e)[:100]}")
        
        # Strategy 3: Relaxed detection (last resort)
        try:
            embedding_objs = DeepFace.represent(
                img_path=image_input,
                model_name=settings.MODEL_NAME,
                enforce_detection=False,
                detector_backend='opencv'
            )
            
            if embedding_objs and len(embedding_objs) > 0:
                logger.warning("Face detected with relaxed detection (less reliable)")
                return embedding_objs[0]["embedding"]
                
        except Exception as e:
            logger.debug(f"Relaxed detection failed: {str(e)[:100]}")
        
        logger.warning("No face detected with any detection strategy")
        return None

    def save_embedding(self, student_id: str, embedding: List[float]) -> bool:
        """
        Save embedding to disk for future fast recognition.
        
        Args:
            student_id: Unique student identifier
            embedding: Face embedding to save
            
        Returns:
            True if saved successfully, False otherwise
        """
        file_path = os.path.join(settings.EMBEDDINGS_DIR, f"{student_id}.pkl")
        try:
            with open(file_path, "wb") as f:
                pickle.dump(embedding, f)
            self.embeddings[student_id] = embedding
            return True
        except Exception as e:
            logger.error(f"Failed to save embedding for {student_id}: {e}")
            return False
    
    def clear_session_cache(self, session_id: str):
        """
        Clear cached embeddings for a specific session.
        
        Args:
            session_id: Session identifier to clear
        """
        if session_id in self.session_cache:
            del self.session_cache[session_id]
            logger.info(f"Cleared cache for session {session_id}")
    
    def get_or_extract_embedding(self, student_id: str, student_image: str, session_id: str) -> Optional[List[float]]:
        """
        Get embedding from cache or extract and cache it.
        
        Checks in order:
        1. Pre-computed embeddings on disk
        2. Session cache
        3. Extract new embedding and cache it
        
        Args:
            student_id: Unique student identifier
            student_image: Base64 encoded student image
            session_id: Current session identifier
            
        Returns:
            Face embedding or None if extraction fails
        """
        # Check pre-computed embeddings
        if student_id in self.embeddings:
            logger.debug(f"Using pre-computed embedding for {student_id}")
            return self.embeddings[student_id]
        
        # Check session cache
        if session_id in self.session_cache and student_id in self.session_cache[session_id]:
            logger.debug(f"Using cached embedding for {student_id} from session {session_id}")
            return self.session_cache[session_id][student_id]
        
        # Extract new embedding
        student_image_array = self._base64_to_image(student_image)
        embedding = self.extract_embedding(student_image_array)
        
        if embedding:
            # Cache in session
            if session_id not in self.session_cache:
                self.session_cache[session_id] = {}
            self.session_cache[session_id][student_id] = embedding
            logger.debug(f"Extracted and cached new embedding for {student_id}")
        
        return embedding


    def recognize_face_from_students(self, uploaded_base64_image: str, students: List[Dict], session_id: str) -> Tuple[Optional[str], Optional[str], float]:
        """
        Recognize face from uploaded image against student list.
        
        Uses cached embeddings for efficiency to avoid re-extracting embeddings
        for every attendance mark within the same session.
        
        Args:
            uploaded_base64_image: Base64 encoded image from mobile app
            students: List of student dicts with 'id', 'nom', 'image' fields
            session_id: Session ID for caching embeddings
            
        Returns:
            Tuple of (student_id, student_name, confidence)
            Returns (None, None, confidence) if no match found
        """
        # Extract embedding from uploaded image
        logger.info("Extracting embedding from uploaded image...")
        uploaded_image = self._base64_to_image(uploaded_base64_image)
        uploaded_embedding = self.extract_embedding(uploaded_image)
        
        if uploaded_embedding is None:
            logger.warning("No face detected in uploaded image")
            return None, None, 0.0
        
        logger.info("Successfully extracted embedding from uploaded image")
        
        # Initialize cache for this session if needed
        if session_id not in self.session_cache:
            self.session_cache[session_id] = {}
            logger.info(f"Initialized cache for session {session_id}")
        
        # Compare with students
        best_match_id = None
        best_match_name = None
        min_distance = 1.0
        cached_count = 0
        extracted_count = 0
        
        logger.info(f"Comparing with {len(students)} students...")
        
        for i, student in enumerate(students, 1):
            student_id = student.get('id')
            student_name = student.get('nom', 'Unknown')
            student_image = student.get('image')
            
            if not student_image:
                continue
            
            try:
                # Get or extract embedding with caching
                student_embedding = self.get_or_extract_embedding(student_id, student_image, session_id)
                
                if student_embedding is None:
                    logger.warning(f"Could not get embedding for {student_name}")
                    continue
                
                # Track cache usage
                if student_id in self.embeddings or (session_id in self.session_cache and student_id in self.session_cache[session_id]):
                    cached_count += 1
                else:
                    extracted_count += 1
                
                # Calculate distance
                distance = self.compute_cosine_distance(uploaded_embedding, student_embedding)
                
                # Track best match
                if distance < min_distance:
                    min_distance = distance
                    best_match_id = student_id
                    best_match_name = student_name
                    logger.info(f"[{i}/{len(students)}] New best match: {student_name} (distance: {distance:.4f})")
                    
            except Exception as e:
                logger.error(f"Error processing student {student_name}: {e}")
                continue
        
        logger.info(f"Recognition complete: {cached_count} cached, {extracted_count} newly extracted")
        
        # Check if best match exceeds threshold
        confidence = 1 - min_distance
        
        if min_distance <= settings.RECOGNITION_THRESHOLD:
            logger.info(f"✓ Match found: {best_match_name} with confidence {confidence:.2%}")
            return best_match_id, best_match_name, confidence
        else:
            logger.info(f"✗ No match found. Best distance: {min_distance:.4f} (threshold: {settings.RECOGNITION_THRESHOLD})")
            return None, None, confidence

 