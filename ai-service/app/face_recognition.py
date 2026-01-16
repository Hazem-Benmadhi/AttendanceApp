import os
import pickle
import base64
import numpy as np
from typing import List, Tuple, Optional, Dict
from io import BytesIO
from PIL import Image
from deepface import DeepFace
from app.config import settings
import logging

# Configure logging
logger = logging.getLogger(__name__)

class FaceRecognizer:
    def __init__(self):
        self.embeddings: Dict[str, List[float]] = {}  # Pre-computed embeddings from disk
        self.session_cache: Dict[str, Dict[str, List[float]]] = {}  # Session-based cache: {session_id: {student_id: embedding}}
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
        """Convert base64 string to numpy array (opencv format)."""
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
        
        image_data = base64.b64decode(base64_string)
        image = Image.open(BytesIO(image_data))
        
        # Convert to RGB (DeepFace expects RGB/BGR)
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        # Convert to numpy array
        return np.array(image)

    @staticmethod
    def compute_cosine_distance(embedding1: List[float], embedding2: List[float]) -> float:
        """Calculate cosine distance between two embeddings."""
        a = np.array(embedding1)
        b = np.array(embedding2)
        return 1 - (np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
    
    def extract_embedding(self, image_input) -> Optional[List[float]]:
        """Extract face embedding using DeepFace."""
        try:
            # DeepFace.represent returns a list of dicts
            embedding_objs = DeepFace.represent(
                img_path=image_input,
                model_name=settings.MODEL_NAME,
                enforce_detection=True,
                detector_backend=settings.DETECTOR_BACKEND
            )
            
            if not embedding_objs or len(embedding_objs) == 0:
                logger.warning("No face detected")
                return None
            
            # Retrieve the most prominent face (usually the first/largest one returned)
            embedding = embedding_objs[0]["embedding"]
            return embedding
            
        except ValueError as e:
            # Face could not be detected
            logger.warning(f"Face detection failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Error extracting embedding: {e}")
            return None

    def save_embedding(self, student_id: str, embedding: List[float]) -> bool:
        """Save embedding to disk for future fast recognition."""
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
        """Clear cached embeddings for a specific session."""
        if session_id in self.session_cache:
            del self.session_cache[session_id]
            logger.info(f"Cleared cache for session {session_id}")
    
    def get_or_extract_embedding(self, student_id: str, student_image: str, session_id: str) -> Optional[List[float]]:
        """Get embedding from cache or extract and cache it."""
        # Check if we have pre-computed embedding on disk
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
        Recognize face using cached embeddings for efficiency.
        
        Optimization: Reuses cached embeddings for students within the same session.
        This avoids re-extracting embeddings for every attendance mark.
        
        Args:
            uploaded_base64_image: Base64 encoded image from mobile app
            students: List of student dicts with 'id', 'nom', 'image' fields
            session_id: Session ID for caching embeddings
            
        Returns:
            Tuple of (student_id, student_name, confidence)
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
                # Get or extract embedding (with caching)
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
        if min_distance <= settings.RECOGNITION_THRESHOLD:
            confidence = 1 - min_distance
            logger.info(f"✓ Match found: {best_match_name} with confidence {confidence:.2%}")
            return best_match_id, best_match_name, confidence
        else:
            confidence = 1 - min_distance
            logger.info(f"✗ No match found. Best distance: {min_distance:.4f} (threshold: {settings.RECOGNITION_THRESHOLD})")
            return None, None, confidence

 