import { Component, OnInit } from '@angular/core';
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
  sessions$: Observable<Session[]> | undefined;

  // Modal State
  showModal = false;
  showSuccessModal = false;
  newSession = { nom_seance: '', date: '', time: '', classe: '' };
  message = '';

  constructor(private dataService: DataService, private router: Router) { }

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
      this.sessions$ = this.dataService.getSessionsForTeacher(this.teacher.id).pipe(
        map(sessions => sessions.sort((a, b) => {
          // Sort by date descending
          const dateA = a.date instanceof Date ? a.date : (a.date as any).toDate();
          const dateB = b.date instanceof Date ? b.date : (b.date as any).toDate();
          return dateB.getTime() - dateA.getTime();
        }))
      );
    }
  }

  openModal() {
    this.showModal = true;
    this.message = '';
    this.newSession = { nom_seance: '', date: '', time: '', classe: '' };
  }

  closeModal() {
    this.showModal = false;
  }

  createSession() {
    if (!this.newSession.nom_seance || !this.newSession.date || !this.newSession.time || !this.newSession.classe) {
      this.message = 'Please fill all fields';
      return;
    }

    const dateTime = new Date(this.newSession.date + 'T' + this.newSession.time);
    const sessionData = {
      nom_seance: this.newSession.nom_seance,
      date: dateTime,
      classe: this.newSession.classe,
      prof: this.teacher?.id // ID is enough, DataService handles conversion if needed, but wait...
      // DataService.addSession expects 'prof' to be ID string or Ref. 
      // Let's check addSession implementation. It converts string to Ref.
    };

    this.dataService.addSession(sessionData).subscribe(() => {
      this.message = 'Session created successfully!';
      this.showSuccessModal = true;
      setTimeout(() => {
        this.showSuccessModal = false;
        this.closeModal();
        this.loadSessions();
      }, 2000);
    });
  }

  formatDate(timestamp: any): string {
    if (!timestamp) return '';
    // Handle Firestore Timestamp
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
}
