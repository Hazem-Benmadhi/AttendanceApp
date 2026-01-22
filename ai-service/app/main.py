from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.models import (
    MarkAttendanceRequest,
    AttendanceResult,
    SessionInfo,
    TeacherInfo,
)
from app.capture import router as capture_router
from app.capture import router as capture_router, notify_capture_watchers
from app.face_recognition import FaceRecognizer
from app.firebase_service import FirebaseService
from app.config import settings
import logging
import os
import json
import base64
from datetime import datetime
from typing import Optional, List

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai_service")

app = FastAPI(
    title=settings.APP_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS config
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(capture_router, tags=["Capture"])

# Initialize global instances
recognizer = FaceRecognizer()
firebase_service: Optional[FirebaseService] = None

@app.on_event("startup")
async def startup_event():
    """Initialize Firebase on startup."""
    global firebase_service
    try:
        firebase_service = FirebaseService()
        logger.info("Firebase service initialized")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase service: {e}")
        logger.warning("Attendance marking will not be available")

@app.get("/", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": settings.APP_NAME}

@app.get("/sessions", response_model=List[SessionInfo], tags=["Sessions"])
async def list_sessions(prof: Optional[str] = None):
    if firebase_service is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase service not available"
        )

    try:
        sessions = firebase_service.get_sessions(prof_reference=prof)
        results: List[SessionInfo] = []
        for session in sessions:
            date_value = session.get('date') or session.get('Date')
            if hasattr(date_value, 'isoformat'):
                date_str = date_value.isoformat()
            elif hasattr(date_value, 'to_datetime'):
                date_str = date_value.to_datetime().isoformat()
            elif isinstance(date_value, datetime):
                date_str = date_value.isoformat()
            elif isinstance(date_value, str):
                date_str = date_value
            else:
                date_str = None

            prof_value = (
                session.get('prof')
                or session.get('prof_reference')
                or session.get('profRef')
                or None
            )

            if prof_value is not None and not isinstance(prof_value, str):
                if hasattr(prof_value, 'path') and prof_value.path:
                    prof_value = prof_value.path
                elif hasattr(prof_value, 'id') and prof_value.id:
                    prof_value = prof_value.id
                else:
                    prof_value = str(prof_value)

            session_info = SessionInfo(
                id=session.get('id', ''),
                nom_seance=session.get('nom_seance') or session.get('nomSeance') or session.get('nom') or '',
                classe=session.get('classe') or session.get('Classe') or '',
                date=date_str,
                prof=prof_value
            )
            results.append(session_info)

        return results
    except Exception as e:
        logger.error(f"Failed to list sessions: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to fetch sessions"
        )


@app.get("/teachers", response_model=List[TeacherInfo], tags=["Teachers"])
async def list_teachers():
    if firebase_service is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase service not available"
        )

    try:
        teachers = firebase_service.get_teachers()
        results: List[TeacherInfo] = []

        for teacher in teachers:
            cin_value = (
                teacher.get('cin')
                or teacher.get('CIN')
                or teacher.get('Cin')
                or teacher.get('CinProf')
            )
            name_value = (
                teacher.get('nom')
                or teacher.get('Nom')
                or teacher.get('name')
                or teacher.get('fullName')
            )

            if not cin_value or not name_value:
                logger.debug(
                    "Skipping teacher %s due to missing cin (%s) or name (%s)",
                    teacher.get('id'),
                    cin_value,
                    name_value,
                )
                continue

            subject_value = (
                teacher.get('matiere')
                or teacher.get('matière')
                or teacher.get('subject')
            )

            teacher_info = TeacherInfo(
                id=str(teacher.get('id', '')),
                cin=str(cin_value),
                nom=str(name_value),
                matiere=str(subject_value) if subject_value is not None else None,
            )
            results.append(teacher_info)

        logger.info("Returning %d teachers", len(results))
        return results
    except Exception as exc:
        logger.error(f"Failed to list teachers: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to fetch teachers",
        )

@app.post("/attendance/mark", response_model=AttendanceResult, tags=["Attendance"])
async def mark_attendance(request: MarkAttendanceRequest):
    """
    Mark attendance using face recognition with caching.
    
    Workflow:
    1. Fetch students from class
    2. Extract embedding from uploaded image
    3. Compare with students using cached embeddings
    4. Mark as present if match found
    """
    if firebase_service is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase service not available"
        )
    
    logger.info(f"Processing attendance for session: {request.session.id}, class: {request.session.classe}")
    
    async def _send_capture_update(result: AttendanceResult) -> None:
        if not request.capture_token:
            return

        payload = {
            "type": "attendance_result",
            "result": result.dict(),
            "session": request.session.dict(),
        }

        try:
            await notify_capture_watchers(request.capture_token, payload)
            logger.info("Capture listeners notified for token %s", request.capture_token)
        except ValueError:
            logger.warning("Capture token %s is no longer active", request.capture_token)
        except Exception as exc:
            logger.error(
                "Failed to notify capture listeners for token %s: %s",
                request.capture_token,
                exc,
            )

    # Step 1: Save uploaded image and session info temporarily
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
    temp_filename = f"temp_{request.session.id}_{timestamp}"
    
    # Save uploaded image
    uploaded_image_path = os.path.join(settings.TEMP_IMAGES_DIR, f"{temp_filename}_uploaded.jpg")
    try:
        # Decode and save base64 image
        if "," in request.image:
            image_data = request.image.split(",")[1]
        else:
            image_data = request.image
        
        with open(uploaded_image_path, "wb") as f:
            f.write(base64.b64decode(image_data))
        logger.info(f"Saved uploaded image: {uploaded_image_path}")
        
        # Save session metadata
        metadata_path = os.path.join(settings.TEMP_IMAGES_DIR, f"{temp_filename}_session.json")
        with open(metadata_path, "w") as f:
            json.dump(request.session.dict(), f, indent=2)
        logger.info(f"Saved session metadata: {metadata_path}")
        
    except Exception as e:
        logger.error(f"Error saving temporary files: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save temporary files"
        )
    
    try:
        # Step 2: Fetch all students in the class from Firebase
        logger.info(f"Fetching students for class: {request.session.classe}")
        students = firebase_service.get_students_by_class(request.session.classe)
        
        if not students:
            result = AttendanceResult(
                success=False,
                message=f"No students found in class '{request.session.classe}'",
                confidence=0.0
            )
            await _send_capture_update(result)
            return result
        
        logger.info(f"Found {len(students)} students in class {request.session.classe}")
        
        # Step 3: Save student list locally
        students_list_path = os.path.join(settings.TEMP_IMAGES_DIR, f"{temp_filename}_students.json")
        with open(students_list_path, "w") as f:
            # Save without image data (too large for JSON)
            students_summary = [{
                'id': s.get('id'),
                'nom': s.get('nom'),
                'cin': s.get('CIN') or s.get('cin'),
                'classe': s.get('classe') or s.get('Classe'),
                'has_image': bool(s.get('image'))
            } for s in students]
            json.dump(students_summary, f, indent=2)
        logger.info(f"Saved student list: {students_list_path}")
        
        # Step 4: Recognize face with caching (reuses embeddings within same session)
        logger.info("Starting face recognition process with caching...")
        recognized_id, recognized_name, confidence = recognizer.recognize_face_from_students(
            request.image,
            students,
            request.session.id  # Pass session ID for caching
        )
        
        if not recognized_id:
            logger.info("Recognition result: no match")
            result = AttendanceResult(
                success=False,
                message="No face detected or no match found among class students",
                confidence=confidence
            )
            await _send_capture_update(result)
            return result
        
        logger.info(f"Face recognized: {recognized_name} ({recognized_id}) with confidence {confidence:.2f}")
        
        # Step 5: Mark student as present in Firebase
        logger.info(f"Marking {recognized_name} as present in session {request.session.id}")
        success = firebase_service.mark_student_present(request.session.id, recognized_id)
        
        if success:
            logger.info(f"Successfully marked {recognized_name} ({recognized_id}) as present")
            
            result = AttendanceResult(
                success=True,
                student_id=recognized_id,
                student_name=recognized_name,
                confidence=confidence,
                status="present",
                message=f"Attendance marked successfully for {recognized_name}"
            )
            await _send_capture_update(result)
            return result
        else:
            logger.info(f"Failed to persist attendance for {recognized_name} ({recognized_id})")
            result = AttendanceResult(
                success=False,
                student_id=recognized_id,
                student_name=recognized_name,
                confidence=confidence,
                message="Failed to update attendance in database"
            )
            await _send_capture_update(result)
            return result
            
    except Exception as e:
        logger.error(f"Error processing attendance: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error processing attendance: {str(e)}"
        )
    
    finally:
        # Cleanup: Delete temporary files after processing (optional - keep for debugging)
        try:
            # Keep files for audit trail - uncomment to delete
            # if os.path.exists(uploaded_image_path):
            #     os.remove(uploaded_image_path)
            # if os.path.exists(metadata_path):
            #     os.remove(metadata_path)
            # if os.path.exists(students_list_path):
            #     os.remove(students_list_path)
            # logger.info("Cleaned up temporary files")
            pass
        except Exception as e:
            logger.warning(f"Failed to cleanup temporary files: {e}")
