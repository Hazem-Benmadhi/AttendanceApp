import { Injectable } from '@angular/core';
import { Observable, from, of, forkJoin } from 'rxjs';
import { map, switchMap, tap } from 'rxjs/operators';
import { Session, Student } from '../models/models';
import { getFirestore, collection, query, where, getDocs, doc, getDoc, getDocFromServer, updateDoc, addDoc, DocumentReference, DocumentSnapshot } from 'firebase/firestore';
import { app } from '../../firebase.config';

@Injectable({
    providedIn: 'root'
})
export class DataService {
    private db = getFirestore(app);
    private currentUser: any = null;

    constructor() { }

    setCurrentUser(user: any) {
        this.currentUser = user;
    }

    getCurrentUser() {
        return this.currentUser;
    }

    // Login method
    login(cin: string, name: string): Observable<{ userType: 'teacher' | 'student', userData: any } | null> {
        return from(this.checkLogin(cin, name));
    }

    private async checkLogin(cin: string, name: string): Promise<{ userType: 'teacher' | 'student', userData: any } | null> {
        console.log(`Checking login for CIN: ${cin}, Name: ${name}`);

        try {
            // Check Teacher
            const teachersRef = collection(this.db, 'PROF');
            const qTeacher = query(teachersRef, where('CIN', '==', cin), where('nom', '==', name));
            const teacherSnap = await getDocs(qTeacher);

            if (!teacherSnap.empty) {
                console.log('Teacher found');
                const doc = teacherSnap.docs[0];
                return { userType: 'teacher', userData: { id: doc.id, ...doc.data() } };
            }

            // Check Student
            const studentsRef = collection(this.db, 'Etudiant');
            const qStudent = query(studentsRef, where('CIN', '==', cin), where('nom', '==', name));
            const studentSnap = await getDocs(qStudent);

            if (!studentSnap.empty) {
                console.log('Student found');
                const doc = studentSnap.docs[0];
                const data = doc.data();
                // Normalize 'classe' field (handle 'Classe' from DB)
                const userData = {
                    id: doc.id,
                    ...data,
                    classe: data['classe'] || data['Classe']
                };
                return { userType: 'student', userData: userData };
            }

            console.log('No user found');
            return null;
        } catch (error: any) {
            console.error('Login error:', error);
            if (error.code === 'unavailable' || error.message.includes('ERR_BLOCKED_BY_CLIENT')) {
                throw new Error('Connection blocked. Please disable ad-blockers or check your firewall.');
            }
            throw error;
        }
    }

    // Get Sessions for Teacher
    getSessionsForTeacher(teacherId: string): Observable<Session[]> {
        const teacherRef = doc(this.db, 'PROF', teacherId);
        const q = query(collection(this.db, 'Seance'), where('prof', '==', teacherRef));

        return from(getDocs(q)).pipe(
            map(snapshot => snapshot.docs.map(d => ({ id: d.id, ...d.data() } as Session)))
        );
    }

    // Get Sessions for Student (via Presence) - Legacy/Specific use
    getSessionsForStudent(studentId: string): Observable<any[]> {
        const studentRef = doc(this.db, 'Etudiant', studentId);
        const q = query(collection(this.db, 'Presence'), where('Etudiant_id', '==', studentRef));

        return from(getDocs(q)).pipe(
            switchMap(presenceSnap => {
                if (presenceSnap.empty) return of([]);

                const sessionObservables = presenceSnap.docs.map(pDoc => {
                    const presenceData = pDoc.data();
                    const sessionRef = presenceData['Seance_id'] as DocumentReference;

                    return from(getDoc(sessionRef)).pipe(
                        switchMap(sDoc => {
                            if (sDoc.exists()) {
                                const sessionData = sDoc.data();
                                const teacherRef = sessionData['prof'] as DocumentReference;
                                return from(getDoc(teacherRef)).pipe(
                                    map(tDoc => {
                                        const teacherName = tDoc.exists() ? tDoc.data()['nom'] : 'Unknown';
                                        return {
                                            ...sessionData,
                                            id: sDoc.id,
                                            attendanceStatus: presenceData['status'],
                                            teacherName: teacherName
                                        };
                                    })
                                );
                            }
                            return of(null);
                        })
                    );
                });

                return forkJoin(sessionObservables).pipe(
                    map(sessions => sessions.filter(s => s !== null))
                );
            })
        );
    }

    // Get Attendance for a Session (with Student details)
    getAttendanceForSession(sessionId: string): Observable<any[]> {
        const sessionRef = doc(this.db, 'Seance', sessionId);
        const q = query(collection(this.db, 'Presence'), where('Seance_id', '==', sessionRef));

        return from(getDocs(q)).pipe(
            switchMap(presenceSnap => {
                if (presenceSnap.empty) return of([]);

                const studentObservables = presenceSnap.docs.map(pDoc => {
                    const presenceData = pDoc.data();
                    const studentRef = presenceData['Etudiant_id'] as DocumentReference;

                    return from(getDoc(studentRef)).pipe(
                        map(stDoc => {
                            if (stDoc.exists()) {
                                const data = stDoc.data();
                                return {
                                    presenceId: pDoc.id,
                                    student: { id: stDoc.id, ...data, classe: data['classe'] || data['Classe'] },
                                    status: presenceData['status']
                                };
                            }
                            return null;
                        })
                    );
                });

                return forkJoin(studentObservables).pipe(
                    map(records => records.filter(r => r !== null))
                );
            })
        );
    }

    // Mark Attendance
    markAttendance(presenceId: string, status: 'present' | 'absent'): Observable<void> {
        const presenceRef = doc(this.db, 'Presence', presenceId);
        return from(updateDoc(presenceRef, { status }));
    }

    // Helper to get session details
    getSession(sessionId: string): Observable<Session | undefined> {
        console.log(`DataService: getSession called for ${sessionId}`);
        // Use getDocFromServer to bypass potential cache locks
        return from(getDocFromServer(doc(this.db, 'Seance', sessionId))).pipe(
            tap((d: DocumentSnapshot) => console.log(`DataService: Firestore response for ${sessionId}, exists=${d.exists()}`)),
            map((d: DocumentSnapshot) => d.exists() ? { id: d.id, ...d.data() } as Session : undefined)
        );
    }

    // Add Student
    addStudent(student: any): Observable<any> {
        const studentsRef = collection(this.db, 'Etudiant');
        return from(addDoc(studentsRef, student));
    }

    // Add Teacher
    addTeacher(teacher: any): Observable<any> {
        const teachersRef = collection(this.db, 'PROF');
        return from(addDoc(teachersRef, teacher));
    }

    // Add Session
    addSession(session: any): Observable<any> {
        const sessionsRef = collection(this.db, 'Seance');
        // Convert teacherId to DocumentReference
        if (session.prof && typeof session.prof === 'string') {
            session.prof = doc(this.db, 'PROF', session.prof);
        }
        return from(addDoc(sessionsRef, session));
    }

    // Get All Teachers (for dropdowns)
    getAllTeachers(): Observable<any[]> {
        const teachersRef = collection(this.db, 'PROF');
        return from(getDocs(teachersRef)).pipe(
            map(snap => snap.docs.map(d => ({ id: d.id, ...d.data() })))
        );
    }

    // Get Students by Class
    getStudentsByClass(classe: string): Observable<Student[]> {
        console.log(`DataService: Fetching students for class '${classe}'`);

        // Query both 'Classe' and 'classe' to be safe
        const q1 = query(collection(this.db, 'Etudiant'), where('Classe', '==', classe));
        const q2 = query(collection(this.db, 'Etudiant'), where('classe', '==', classe));

        return forkJoin([from(getDocs(q1)), from(getDocs(q2))]).pipe(
            map(([snap1, snap2]) => {
                const studentsMap = new Map<string, Student>();

                // Process first query (Classe)
                snap1.docs.forEach(d => {
                    const data = d.data();
                    studentsMap.set(d.id, { id: d.id, ...data, classe: data['classe'] || data['Classe'] } as Student);
                });

                // Process second query (classe)
                snap2.docs.forEach(d => {
                    if (!studentsMap.has(d.id)) {
                        const data = d.data();
                        studentsMap.set(d.id, { id: d.id, ...data, classe: data['classe'] || data['Classe'] } as Student);
                    }
                });

                const students = Array.from(studentsMap.values());
                console.log(`DataService: Found ${students.length} students for class '${classe}' (combined query)`);
                return students;
            })
        );
    }

    // Set Attendance (Create or Update)
    setAttendance(sessionId: string, studentId: string, status: string): Observable<void> {
        const sessionRef = doc(this.db, 'Seance', sessionId);
        const studentRef = doc(this.db, 'Etudiant', studentId);
        const presenceRef = collection(this.db, 'Presence');

        const q = query(presenceRef,
            where('Seance_id', '==', sessionRef),
            where('Etudiant_id', '==', studentRef)
        );

        return from(getDocs(q)).pipe(
            switchMap(snap => {
                if (snap.empty) {
                    // Create new record
                    return from(addDoc(presenceRef, {
                        Seance_id: sessionRef,
                        Etudiant_id: studentRef,
                        status: status
                    })).pipe(map(() => void 0));
                } else {
                    // Update existing record
                    const docId = snap.docs[0].id;
                    return from(updateDoc(doc(this.db, 'Presence', docId), { status: status })).pipe(map(() => void 0));
                }
            })
        );
    }

    // Get Sessions by Class
    getSessionsByClass(classe: string): Observable<Session[]> {
        const q1 = query(collection(this.db, 'Seance'), where('Classe', '==', classe));
        const q2 = query(collection(this.db, 'Seance'), where('classe', '==', classe));

        return forkJoin([from(getDocs(q1)), from(getDocs(q2))]).pipe(
            map(([snap1, snap2]) => {
                const sessionsMap = new Map<string, Session>();

                snap1.docs.forEach(d => {
                    sessionsMap.set(d.id, { id: d.id, ...d.data() } as Session);
                });

                snap2.docs.forEach(d => {
                    if (!sessionsMap.has(d.id)) {
                        sessionsMap.set(d.id, { id: d.id, ...d.data() } as Session);
                    }
                });

                return Array.from(sessionsMap.values());
            })
        );
    }

    // Get All Attendance for Student
    getAttendanceForStudent(studentId: string): Observable<any[]> {
        const studentRef = doc(this.db, 'Etudiant', studentId);
        const q = query(collection(this.db, 'Presence'), where('Etudiant_id', '==', studentRef));
        return from(getDocs(q)).pipe(
            map(snapshot => snapshot.docs.map(d => ({ id: d.id, ...d.data() })))
        );
    }

    // Get Student Dashboard Data (All Class Sessions + Attendance Status)
    getStudentDashboardData(studentId: string, classe: string): Observable<any[]> {
        return forkJoin({
            sessions: this.getSessionsByClass(classe),
            attendance: this.getAttendanceForStudent(studentId)
        }).pipe(
            switchMap(({ sessions, attendance }) => {
                if (sessions.length === 0) return of([]);

                const sessionObservables = sessions.map(session => {
                    // Resolve Teacher Name
                    let teacherObs = of('Unknown');
                    if (session.prof) {
                        const profRef = typeof session.prof === 'string' ? doc(this.db, 'PROF', session.prof) : session.prof;
                        teacherObs = from(getDoc(profRef)).pipe(
                            map(d => d.exists() ? (d.data() as any)['nom'] : 'Unknown')
                        );
                    }

                    return teacherObs.pipe(
                        map(teacherName => {
                            const att = attendance.find(a => {
                                const seanceRef = a['Seance_id'];
                                if (seanceRef && typeof seanceRef === 'object' && seanceRef.id) {
                                    return seanceRef.id === session.id;
                                } else if (typeof seanceRef === 'string') {
                                    return seanceRef === session.id;
                                }
                                return false;
                            });
                            return {
                                ...session,
                                teacherName,
                                attendanceStatus: att ? att['status'] : 'absent'
                            };
                        })
                    );
                });

                return forkJoin(sessionObservables);
            })
        );
    }
}
