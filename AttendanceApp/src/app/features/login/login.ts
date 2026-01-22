import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { DataService } from '../../core/services/data.service';
import { CommonModule } from '@angular/common';
import { timeout, catchError, finalize } from 'rxjs/operators';
import { throwError } from 'rxjs';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, CommonModule],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class Login {
  cin: string = '';
  name: string = '';
  errorMessage: string = '';
  isLoading: boolean = false;

  constructor(private router: Router, private dataService: DataService) { }

  login() {
    if (!this.cin || !this.name) {
      this.errorMessage = 'Please enter both CIN and Name.';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    const cin = this.cin.trim();
    const name = this.name.trim();

    console.log('Starting login process for:', cin);
    this.dataService.login(cin, name).pipe(
      timeout(5000), // Reduced to 5 seconds
      catchError(err => {
        console.error('CatchError caught:', err);
        if (err.name === 'TimeoutError') {
          return throwError(() => new Error('Connection timed out. Please check your network.'));
        }
        return throwError(() => err);
      }),
      finalize(() => {
        console.log('Login observable finalized');
        this.isLoading = false;
      })
    ).subscribe({
      next: (result) => {
        console.log('Login success:', result);
        if (result) {
          this.dataService.setCurrentUser(result.userData);
          if (result.userType === 'teacher') {
            this.router.navigate(['/teacher-dashboard']);
          } else {
            this.router.navigate(['/student-dashboard']);
          }
        } else {
          this.errorMessage = 'Invalid credentials. Please check your CIN and Name.';
        }
      },
      error: (err) => {
        console.error('Login subscription error:', err);
        this.errorMessage = err.message || 'An error occurred during login.';
      }
    });
  }
}
