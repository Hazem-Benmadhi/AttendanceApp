import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { DataService } from '../../core/services/data.service';
import { Session, Teacher } from '../../core/models/models';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Component({
  selector: 'app-teacher-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule],
  templateUrl: './teacher-dashboard.html',
  styleUrl: './teacher-dashboard.css'
})
export class TeacherDashboard implements OnInit {
  teacher: Teacher | null = null;

  subjects: { name: string, sessions: Session[] }[] = [];
  selectedSubject: { name: string, sessions: Session[] } | null = null;


  // Modal State
  showModal = false;
  showSuccessModal = false;
  newSession = { nom_seance: '', date: '', time: '', classe: '' };
  message = '';
  isSubmitting = false;
  modalType: 'session' = 'session';

  availableClasses: string[] = ['All'];
  selectedClass = 'All';
  filterDate: string = '';

  constructor(
    private dataService: DataService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit(): void {
    this.teacher = this.dataService.getCurrentUser();
    if (!this.teacher) {
      this.router.navigate(['/login']);
      return;
    }

    this.loadSessions();
  }

  loadSessions() {
    if (this.teacher) {
      console.log('Subscribing to sessions...');
      const sessions$ = this.dataService.getSessionsForTeacher(this.teacher.id);

      // We also need to get the teacher doc again to see if 'subjects' array changed? 
      // Ideally, we should listen to teacher doc too, but let's assume sessions update is main trigger for now
      // Or better: Just use the sessions for now, and rely on the fact that if we just added a subject, we'll manually reload or it will persist.
      // actually, to show "Empty" subjects, we MUST read the teacher doc's 'subjects' field.
      // But getSessions is real-time. Let's make this simple:

      sessions$.subscribe(sessions => {
        // ... (sorting)
        sessions.sort((a, b) => {
          const dateA = a.date instanceof Date ? a.date : (a.date as any).toDate();
          const dateB = b.date instanceof Date ? b.date : (b.date as any).toDate();
          return dateB.getTime() - dateA.getTime();
        });

        // Group by nom_seance
        const groups: { [key: string]: { name: string, sessions: Session[] } } = {};

        // 1. Add groups from sessions
        sessions.forEach(s => {
          // Normalize key: lowercase and trim for grouping
          const key = s.nom_seance ? s.nom_seance.trim().toLowerCase() : 'untitled';
          const displayName = s.nom_seance ? s.nom_seance.trim() : 'Untitled';

          if (!groups[key]) {
            groups[key] = { name: displayName, sessions: [] };
          }
          groups[key].sessions.push(s);
        });

        // 2. Add explicit subjects from Teacher profile (if any) that might be empty
        // We'll read from this.teacher.subjects if it exists (need to refresh teacher?)
        // For now, let's assume we refresh teacher on Init or we assume the user adds it.
        // Let's rely on stored teacher object for now, or fetch it.
        if (this.teacher && (this.teacher as any).subjects) {
          (this.teacher as any).subjects.forEach((subjName: string) => {
            const key = subjName.trim().toLowerCase();
            if (!groups[key]) {
              groups[key] = { name: subjName, sessions: [] };
            }
          });
        }

        this.subjects = Object.values(groups);
        console.log('Subjects processed:', this.subjects.length);

        // Select first subject by default if none selected or if previously selected one is gone?
        // Better: try to keep the same name selected if possible
        if (this.selectedSubject) {
          const found = this.subjects.find(s => s.name === this.selectedSubject?.name);
          this.selectedSubject = found || this.subjects[0] || null;
        } else {
          this.selectedSubject = this.subjects[0] || null;
        }

        // Force change detection to update view immediately
        this.cdr.detectChanges();
      });
    }
  }

  selectSubject(subject: any) {
    this.selectedSubject = subject;
    // Extract unique classes from sessions
    const classes = new Set(subject.sessions.map((s: Session) => s.classe).filter((c: any) => c));
    this.availableClasses = ['All', ...Array.from(classes) as string[]].sort();
    this.selectedClass = 'All'; // Reset to All
    this.filterDate = '';
  }

  get filteredSessions() {
    if (!this.selectedSubject) return [];

    return this.selectedSubject.sessions.filter(session => {
      const matchClass = this.selectedClass === 'All' || session.classe === this.selectedClass;
      const matchDate = !this.filterDate || this.isSameDay(session.date, this.filterDate);
      return matchClass && matchDate;
    });
  }

  isSameDay(date1: any, dateString: string): boolean {
    if (!date1) return false;
    const d1 = date1.toDate ? date1.toDate() : new Date(date1);
    const d2 = new Date(dateString);
    return d1.getFullYear() === d2.getFullYear() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getDate() === d2.getDate();
  }


  // ... inside class
  // Removed newStudent and modalType usage for student
  // ...

  // Refactored openModal to remove student type
  openModal(type: 'session', subjectName?: string) {
    this.showModal = true;
    this.modalType = type;
    this.message = '';

    if (subjectName) {
      // Adding lecture to existing subject
      this.newSession = {
        nom_seance: subjectName,
        date: '',
        time: '',
        classe: ''
      };
    } else {
      // Creating new subject (blank)
      this.newSession = { nom_seance: '', date: '', time: '', classe: '' };
    }
  }

  // ... createSession ...

  // Removed addStudent method


  closeModal() {
    this.showModal = false;
  }

  createSession() {
    if (this.modalType === 'session' && !this.newSession.nom_seance) {
      this.message = 'Subject name is required';
      return;
    }

    if (this.isSubmitting) return;

    // Case 1: Creating New Subject (Just Name)
    // We detect this if we are in 'session' mode but no class/date is set? 
    // Or better, we check if we are adding to existing or creating new based on how we opened it?
    // Actually, let's look at openModal. 
    // If subjectName was PASSED, we are adding a session.
    // If NOT PASSED, we are creating a NEW SUBJECT.

    // Check if we are creating a subject (Name only required)
    const isCreatingSubject = !this.newSession.classe && !this.newSession.date; // Simple heuristic or use a flag

    if (isCreatingSubject) {
      if (!this.newSession.nom_seance) return;
      this.isSubmitting = true;
      this.dataService.addSubject(this.teacher!.id, this.newSession.nom_seance).subscribe({
        next: () => {
          this.message = 'Subject created!';
          // Manually add to local subjects to show it immediately if not using realtime for PROF
          if (this.teacher) {
            if (!(this.teacher as any).subjects) (this.teacher as any).subjects = [];
            (this.teacher as any).subjects.push(this.newSession.nom_seance);
            this.loadSessions(); // Trigger re-grouping
          }

          this.showSuccessModal = true;
          setTimeout(() => {
            this.showSuccessModal = false;
            this.closeModal();
            this.isSubmitting = false;
          }, 1500);
        },
        error: (e) => {
          console.error(e);
          this.isSubmitting = false;
        }
      });
      return;
    }

    // Case 2: Adding Session
    if (!this.newSession.date || !this.newSession.time || !this.newSession.classe) {
      this.message = 'Please fill all fields for the lecture';
      return;
    }

    const dateTime = new Date(this.newSession.date + 'T' + this.newSession.time);
    const sessionData = {
      nom_seance: this.newSession.nom_seance.trim(),
      date: dateTime,
      classe: this.newSession.classe,
      prof: this.teacher?.id
    };

    this.isSubmitting = true;
    this.dataService.addSession(sessionData).subscribe({
      next: () => {
        this.message = 'Session created successfully!';
        this.showSuccessModal = true;
        setTimeout(() => {
          this.showSuccessModal = false;
          this.closeModal();
          this.isSubmitting = false;
        }, 2000);
      },
      error: (err) => {
        console.error(err);
        this.message = 'Error creating session';
        this.isSubmitting = false;
      }
    });
  }



  formatDate(timestamp: any): string {
    if (!timestamp) return '';
    // Handle Firestore Timestamp
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
}
