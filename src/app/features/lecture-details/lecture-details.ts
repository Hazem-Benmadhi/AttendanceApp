import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { FilterPresentPipe } from '../../shared/pipes/filter-present.pipe';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { DataService } from '../../core/services/data.service';
import { CaptureService } from '../../core/services/capture.service';
import { Session, Student } from '../../core/models/models';
import { Observable, forkJoin, of } from 'rxjs';
import { switchMap, map, timeout, tap, catchError, take } from 'rxjs/operators';

interface StudentAttendance {
  student: Student;
  status: 'present' | 'absent';
  presenceId?: string;
}

@Component({
  selector: 'app-lecture-details',
  standalone: true,
  imports: [CommonModule, RouterModule, FilterPresentPipe],
  templateUrl: './lecture-details.html',
  styleUrl: './lecture-details.css'
})
export class LectureDetails implements OnInit, OnDestroy {
  sessionId: string | null = null;
  session: Session | undefined;
  students: StudentAttendance[] = [];
  loading = false;
  errorMsg = '';
  statusMsg = 'Idle';
  
  // Mobile Capture Props
  showQrModal = false;
  qrCodeUrl = '';
  lastCapturedImage: string | null = null;
  private ws: WebSocket | null = null;

  constructor(
    private route: ActivatedRoute,
    private dataService: DataService,
    private captureService: CaptureService,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit(): void {
    console.log('LectureDetails initialized');
    this.route.paramMap.subscribe(params => {
      this.sessionId = params.get('id');
      console.log('Route params changed. Session ID:', this.sessionId);
      if (this.sessionId) {
        this.loadData(this.sessionId);
      } else {
        this.errorMsg = 'No session ID provided';
      }
    });
  }

  refresh() {
    console.log('Manual refresh clicked');
    this.errorMsg = '';
    if (this.sessionId) {
      this.loadData(this.sessionId);
    }
  }

  openMobileCapture() {
    if (!this.session) return;
    this.showQrModal = true;
    this.statusMsg = 'Generating QR Session...';
    
    // Sanitize session object for API
    const sessionPayload: any = {
      ...this.session,
      // Ensure date is a string
      date: this.session.date instanceof Date ? this.session.date.toISOString() : (this.session.date || '').toString(),
      // Ensure prof is a string (use ID or string representation)
      prof: this.session.prof && typeof this.session.prof === 'object' ? 
            (this.session.prof.id || this.session.prof.path || 'Unknown Prof') : 
            (this.session.prof || '')
    };

    console.log('Sending session to capture:', sessionPayload);

    this.captureService.startCaptureSession(sessionPayload).subscribe({
      next: (res) => {
        console.log('Capture session started, token:', res.token);
        const mobileUrl = `${window.location.origin}/mobile-capture/${res.token}`;
        console.log('Mobile URL:', mobileUrl);
        this.qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(mobileUrl)}`;
        this.statusMsg = 'Waiting for mobile connection...';
        this.cdr.detectChanges();
        
        // Connect WS
        this.ws = this.captureService.connectWebSocket(res.token);
        
        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.statusMsg = 'Connected. Scan QR code with your phone.';
            this.cdr.detectChanges();
        };
        
        this.ws.onmessage = (event) => {
            console.log('WebSocket message received:', event.data);
            const data = JSON.parse(event.data);
            if (data.type === 'image_received') {
                this.handleImageReceived(data.image);
            }
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.errorMsg = 'WebSocket connection failed';
            this.cdr.detectChanges();
        };
        
        this.ws.onclose = (event) => {
            console.log('WebSocket closed:', event.code, event.reason);
        };
      },
      error: (err) => {
        this.errorMsg = 'Failed to start capture session. Is backend running?';
        console.error(err);
        this.cdr.detectChanges(); 
      }
    });
  }

  handleImageReceived(base64Image: string) {
      this.lastCapturedImage = base64Image;
      this.statusMsg = 'Image received from mobile!';
      this.cdr.detectChanges();
  }
  
  closeQrModal() {
      this.showQrModal = false;
      this.qrCodeUrl = '';
      if (this.ws) {
          this.ws.close();
          this.ws = null;
      }
      this.lastCapturedImage = null;
  }
  
  ngOnDestroy() {
      if (this.ws) this.ws.close();
  }

  loadData(sessionId: string) {
    console.log('loadData called for:', sessionId);
    this.loading = true;
    this.errorMsg = '';
    this.statusMsg = 'Fetching Session...';

    this.dataService.getSession(sessionId).pipe(
      take(1),
      timeout(3000),
      tap(s => {
        console.log('getSession emitted:', s);
        this.statusMsg = 'Session Fetched. Fetching Students...';
      }),
      switchMap(session => {
        if (!session) {
          console.error('Session not found');
          throw new Error('Session document not found in Firestore');
        }

        if (session.date) {
          if (typeof (session.date as any).toDate === 'function') {
            session.date = (session.date as any).toDate();
          } else if ((session.date as any).seconds) {
            session.date = new Date((session.date as any).seconds * 1000);
          }
        }
        this.session = session;
        console.log('Session data:', session);

        if (!session.classe) {
          console.warn('Session has no class defined. Cannot fetch students.');
          return forkJoin({
            allStudents: of([]),
            attendance: this.dataService.getAttendanceForSession(sessionId)
          });
        }

        return forkJoin({
          allStudents: this.dataService.getStudentsByClass(session.classe).pipe(
            tap(s => {
              this.statusMsg = `Fetched ${s.length} Students. Fetching Attendance...`;
              console.log('Students fetched:', s);
            })
          ),
          attendance: this.dataService.getAttendanceForSession(sessionId).pipe(
            tap(a => {
              this.statusMsg = `Fetched ${a.length} Attendance Records. Merging...`;
              console.log('Attendance records fetched:', a);
            })
          )
        }).pipe(
          timeout(10000),
          catchError(err => {
            console.error('Error in forkJoin:', err);
            throw err;
          })
        );
      })
    ).subscribe({
      next: (result) => {
        console.log('Subscribe next block called with result:', result);
        if (result) {
          const { allStudents, attendance } = result;

          this.students = allStudents.map(student => {
            const record = attendance.find(r => r.student.id === student.id);
            return {
              student: student,
              status: record ? record.status : 'absent',
              presenceId: record ? record.presenceId : undefined
            };
          });
          console.log('Final students list:', this.students);
          this.statusMsg = 'Data Loaded Successfully';
        }
        this.loading = false;
        this.cdr.detectChanges();  // Add this line
      },
      error: (err) => {
        console.error('Error loading session data:', err);
        this.loading = false;
        this.statusMsg = 'Error Occurred';
        this.errorMsg = err.message || 'Failed to load data';
        this.cdr.detectChanges();  // Add this line
      }
    });
  }

  updateAttendance(item: StudentAttendance, status: 'present' | 'absent') {
    if (!this.sessionId || item.status === status) return;

    const oldStatus = item.status;
    item.status = status;

    this.dataService.setAttendance(this.sessionId, item.student.id, status).subscribe({
      error: () => {
        item.status = oldStatus;
        alert('Failed to update attendance');
        this.cdr.detectChanges();  // Add this line
      }
    });
  }
}