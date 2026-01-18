import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict, Optional
import logging
from app.config import settings

logger = logging.getLogger(__name__)

class FirebaseService:
    def __init__(self):
        """Initialize Firebase Admin SDK."""
        self.db = None
        self.initialize_firebase()
    
    def initialize_firebase(self):
        """Initialize Firebase connection."""
        try:
            if not firebase_admin._apps:
                if settings.FIREBASE_CREDENTIALS_PATH:
                    cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                    firebase_admin.initialize_app(cred)
                else:
                    # Use default credentials (for deployment environments)
                    firebase_admin.initialize_app()
                
                logger.info("Firebase Admin SDK initialized successfully")
            
            self.db = firestore.client()
            
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")
            raise
    
    def get_students_by_class(self, classe: str) -> List[Dict]:
        """
        Fetch all students from a specific class.
        Handles both 'classe' and 'Classe' field names.
        """
        try:
            students = []
            
            # Query with 'Classe' (capital C)
            students_ref = self.db.collection('Etudiant')
            query1 = students_ref.where('Classe', '==', classe).stream()
            
            for doc in query1:
                student_data = doc.to_dict()
                student_data['id'] = doc.id
                students.append(student_data)
            
            # Query with 'classe' (lowercase c) - avoid duplicates
            query2 = students_ref.where('classe', '==', classe).stream()
            existing_ids = {s['id'] for s in students}
            
            for doc in query2:
                if doc.id not in existing_ids:
                    student_data = doc.to_dict()
                    student_data['id'] = doc.id
                    students.append(student_data)
            
            logger.info(f"Found {len(students)} students in class '{classe}'")
            return students
            
        except Exception as e:
            logger.error(f"Error fetching students by class: {e}")
            return []
    
    def get_student_by_id(self, student_id: str) -> Optional[Dict]:
        """Fetch a single student by ID."""
        try:
            doc = self.db.collection('Etudiant').document(student_id).get()
            if doc.exists:
                student_data = doc.to_dict()
                student_data['id'] = doc.id
                return student_data
            return None
        except Exception as e:
            logger.error(f"Error fetching student {student_id}: {e}")
            return None
    
    def mark_student_present(self, session_id: str, student_id: str) -> bool:
        """
        Mark a student as present for a session.
        Creates or updates a Presence (Attendance) record in Firestore.
        """
        try:
            logger.info(f"Attempting to mark student {student_id} as present for session {session_id}")
            
            # Get references
            session_ref = self.db.collection('Seance').document(session_id)
            student_ref = self.db.collection('Etudiant').document(student_id)
            
            # Verify that session and student exist
            session_doc = session_ref.get()
            student_doc = student_ref.get()
            
            if not session_doc.exists:
                logger.error(f"Session {session_id} does not exist in Firestore")
                return False
            
            if not student_doc.exists:
                logger.error(f"Student {student_id} does not exist in Firestore")
                return False
            
            logger.info(f"Session and student verified in Firestore")
            
            # Check if attendance record already exists
            presence_collection = self.db.collection('Presence')
            
            # Query for existing attendance record
            query = presence_collection.where('Seance_id', '==', session_ref)\
                                      .where('Etudiant_id', '==', student_ref)\
                                      .limit(1)\
                                      .stream()
            
            existing_record = None
            for doc in query:
                existing_record = doc
                break
            
            if existing_record:
                # Update existing record
                logger.info(f"Found existing attendance record: {existing_record.id}")
                existing_record.reference.update({
                    'status': 'present'
                })
                logger.info(f"✓ Updated attendance status to 'present' for student {student_id} in session {session_id}")
            else:
                # Create new attendance record
                logger.info(f"No existing attendance record found, creating new one")
                new_doc_ref = presence_collection.add({
                    'Seance_id': session_ref,
                    'Etudiant_id': student_ref,
                    'status': 'present'
                })
                logger.info(f"✓ Created new attendance record with ID: {new_doc_ref[1].id} for student {student_id} in session {session_id}")
            
            return True
            
        except Exception as e:
            logger.error(f"✗ Error marking attendance: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return False
    
    def get_session(self, session_id: str) -> Optional[Dict]:
        """Fetch session details."""
        try:
            doc = self.db.collection('Seance').document(session_id).get()
            if doc.exists:
                session_data = doc.to_dict()
                session_data['id'] = doc.id
                return session_data
            return None
        except Exception as e:
            logger.error(f"Error fetching session: {e}")
            return None
