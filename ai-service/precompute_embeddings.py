"""
Pre-compute and store student face embeddings for faster recognition.

This script extracts embeddings from all students' images in Firebase
and saves them to the embeddings/ folder. Once pre-computed, the AI
service can use these embeddings for instant face recognition without
needing to extract embeddings on every attendance mark.

Usage:
    python precompute_embeddings.py [--class CLASSE]

Options:
    --class CLASSE    Only process students from a specific class
    
Performance:
    - Initial extraction: ~1-2 seconds per student
    - Recognition with pre-computed embeddings: <0.1 seconds per student
"""

import sys
import os
import argparse
import firebase_admin
from firebase_admin import credentials, firestore
from app.face_recognition import FaceRecognizer
from app.config import settings
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-credentials.json")
        
        if not os.path.exists(cred_path):
            logger.error(f"Firebase credentials not found at: {cred_path}")
            logger.error("Please set FIREBASE_CREDENTIALS_PATH environment variable or place firebase-credentials.json in the ai-service folder")
            sys.exit(1)
        
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            logger.info("✓ Firebase initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")
            sys.exit(1)
    
    return firestore.client()

def fetch_students(db, classe: str = None):
    """Fetch students from Firebase."""
    students_ref = db.collection('Etudiant')
    
    if classe:
        logger.info(f"Fetching students from class: {classe}")
        # Try both 'Classe' and 'classe' fields
        query1 = students_ref.where('Classe', '==', classe).stream()
        query2 = students_ref.where('classe', '==', classe).stream()
        
        students = []
        ids_seen = set()
        
        for doc in query1:
            data = doc.to_dict()
            data['id'] = doc.id
            students.append(data)
            ids_seen.add(doc.id)
        
        for doc in query2:
            if doc.id not in ids_seen:
                data = doc.to_dict()
                data['id'] = doc.id
                students.append(data)
    else:
        logger.info("Fetching all students")
        students = []
        for doc in students_ref.stream():
            data = doc.to_dict()
            data['id'] = doc.id
            students.append(data)
    
    return students

def precompute_embeddings(classe: str = None):
    """Main function to pre-compute embeddings."""
    logger.info("=" * 60)
    logger.info("Student Face Embeddings Pre-computation")
    logger.info("=" * 60)
    
    # Initialize services
    db = initialize_firebase()
    recognizer = FaceRecognizer()
    
    # Fetch students
    students = fetch_students(db, classe)
    logger.info(f"Found {len(students)} students to process\n")
    
    if not students:
        logger.warning("No students found!")
        return
    
    # Process each student
    success_count = 0
    skip_count = 0
    fail_count = 0
    
    for i, student in enumerate(students, 1):
        student_id = student.get('id')
        student_name = student.get('nom', 'Unknown')
        student_image = student.get('image')
        
        logger.info(f"[{i}/{len(students)}] Processing: {student_name} ({student_id})")
        
        # Check if already exists
        embedding_path = os.path.join(settings.EMBEDDINGS_DIR, f"{student_id}.pkl")
        if os.path.exists(embedding_path):
            logger.info(f"  ⊙ Embedding already exists, skipping")
            skip_count += 1
            continue
        
        # Check if student has image
        if not student_image:
            logger.warning(f"  ✗ No image available")
            fail_count += 1
            continue
        
        try:
            # Extract embedding
            student_image_array = recognizer._base64_to_image(student_image)
            embedding = recognizer.extract_embedding(student_image_array)
            
            if embedding is None:
                logger.warning(f"  ✗ Failed to extract embedding (no face detected)")
                fail_count += 1
                continue
            
            # Save embedding
            if recognizer.save_embedding(student_id, embedding):
                logger.info(f"  ✓ Embedding saved successfully")
                success_count += 1
            else:
                logger.error(f"  ✗ Failed to save embedding")
                fail_count += 1
                
        except Exception as e:
            logger.error(f"  ✗ Error: {e}")
            fail_count += 1
    
    # Summary
    logger.info("\n" + "=" * 60)
    logger.info("Pre-computation Complete")
    logger.info("=" * 60)
    logger.info(f"✓ Successfully processed: {success_count}")
    logger.info(f"⊙ Skipped (already exist): {skip_count}")
    logger.info(f"✗ Failed: {fail_count}")
    logger.info(f"Total students: {len(students)}")
    logger.info("=" * 60)
    
    if success_count > 0:
        logger.info("\n💡 Tip: Restart the AI service to load new embeddings:")
        logger.info("   uvicorn app.main:app --reload --port 8001")

def main():
    """Parse arguments and run pre-computation."""
    parser = argparse.ArgumentParser(
        description="Pre-compute student face embeddings for faster recognition"
    )
    parser.add_argument(
        '--class',
        dest='classe',
        type=str,
        help='Only process students from a specific class (e.g., "DSI32")'
    )
    
    args = parser.parse_args()
    precompute_embeddings(args.classe)

if __name__ == "__main__":
    main()
