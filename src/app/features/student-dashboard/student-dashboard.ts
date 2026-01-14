import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { DataService } from '../../core/services/data.service';
import { Student } from '../../core/models/models';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Component({
  selector: 'app-student-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './student-dashboard.html',
  styleUrl: './student-dashboard.css'
})
export class StudentDashboard implements OnInit {
  student: Student | null = null;
  sessions$: Observable<any[]> | undefined;

  // Stats
  totalSessions = 0;
  presentCount = 0;
  absentCount = 0;

  constructor(private dataService: DataService, private router: Router) { }

  ngOnInit(): void {
    this.student = this.dataService.getCurrentUser();
    if (!this.student) {
      this.router.navigate(['/login']);
      return;
    }

    this.sessions$ = this.dataService.getStudentDashboardData(this.student.id, this.student.classe || '').pipe(
      map(sessions => {
        // Sort by date descending
        const sorted = sessions.sort((a, b) => {
          const dateA = a.date instanceof Date ? a.date : (a.date as any).toDate();
          const dateB = b.date instanceof Date ? b.date : (b.date as any).toDate();
          return dateB.getTime() - dateA.getTime();
        });

        // Calculate Stats
        this.totalSessions = sorted.length;
        this.presentCount = sorted.filter(s => s.attendanceStatus === 'present').length;
        this.absentCount = sorted.filter(s => s.attendanceStatus === 'absent').length;

        return sorted;
      })
    );
  }

  formatDate(timestamp: any): string {
    if (!timestamp) return '';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
}
