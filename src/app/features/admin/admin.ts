import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DataService } from '../../core/services/data.service';

@Component({
    selector: 'app-admin',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './admin.html',
    styleUrl: './admin.css',
})
export class Admin implements OnInit {
    activeTab: 'student' | 'teacher' | 'session' = 'student';

    // Student Form
    student = { cin: '', nom: '', classe: '', image: '' };

    // Teacher Form
    teacher = { cin: '', nom: '', matiere: '' };

    // Session Form
    session = { nom_seance: '', date: '', time: '', classe: '', prof: '' };

    teachers: any[] = [];
    message: string = '';

    constructor(private dataService: DataService) { }

    ngOnInit(): void {
        this.loadTeachers();
    }

    loadTeachers() {
        this.dataService.getAllTeachers().subscribe(teachers => {
            this.teachers = teachers;
        });
    }

    addStudent() {
        if (!this.student.cin || !this.student.nom) return;

        // Ensure image is an empty string if not set (though initialized as such)
        if (!this.student.image) {
            this.student.image = '';
        }

        this.dataService.addStudent(this.student).subscribe(() => {
            this.message = 'Student added successfully!';
            this.student = { cin: '', nom: '', classe: '', image: '' };
            setTimeout(() => this.message = '', 3000);
        });
    }

    addTeacher() {
        if (!this.teacher.cin || !this.teacher.nom) return;
        this.dataService.addTeacher(this.teacher).subscribe(() => {
            this.message = 'Teacher added successfully!';
            this.teacher = { cin: '', nom: '', matiere: '' };
            this.loadTeachers(); // Reload for session dropdown
            setTimeout(() => this.message = '', 3000);
        });
    }

    addSession() {
        if (!this.session.nom_seance || !this.session.date || !this.session.prof) return;

        // Combine date and time
        const dateTime = new Date(this.session.date + 'T' + this.session.time);

        const sessionData = {
            nom_seance: this.session.nom_seance,
            date: dateTime,
            classe: this.session.classe,
            prof: this.session.prof
        };

        this.dataService.addSession(sessionData).subscribe(() => {
            this.message = 'Session added successfully!';
            this.session = { nom_seance: '', date: '', time: '', classe: '', prof: '' };
            setTimeout(() => this.message = '', 3000);
        });
    }
}
