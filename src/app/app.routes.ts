import { Routes } from '@angular/router';
import { Login } from './features/login/login';
import { TeacherDashboard } from './features/teacher-dashboard/teacher-dashboard';
import { StudentDashboard } from './features/student-dashboard/student-dashboard';
import { LectureDetails } from './features/lecture-details/lecture-details';
import { MainLayout } from './layout/main-layout/main-layout';

export const routes: Routes = [
    {
        path: '',
        component: MainLayout,
        children: [
            { path: '', redirectTo: 'login', pathMatch: 'full' },
            { path: 'login', component: Login },
            { path: 'teacher-dashboard', component: TeacherDashboard },
            { path: 'teacher/lecture/:id', component: LectureDetails },
            { path: 'student-dashboard', component: StudentDashboard },
            { path: 'admin', loadComponent: () => import('./features/admin/admin').then(m => m.Admin) },
        ]
    }
];
