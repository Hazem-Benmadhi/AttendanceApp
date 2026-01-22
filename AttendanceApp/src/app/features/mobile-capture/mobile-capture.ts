import { Component, OnInit, ViewChild, ElementRef, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { CaptureService } from '../../core/services/capture.service';
import { AppConfigService } from '../../core/services/app-config.service';
import { take, timeout, tap, catchError } from 'rxjs/operators';
import { of } from 'rxjs';

@Component({
  selector: 'app-mobile-capture',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './mobile-capture.html',
  styleUrl: './mobile-capture.css'
})
export class MobileCapture implements OnInit, OnDestroy {
  @ViewChild('videoElement') videoElement!: ElementRef<HTMLVideoElement>;
  @ViewChild('canvasElement') canvasElement!: ElementRef<HTMLCanvasElement>;
  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;

  token: string | null = null;
  isValidSession = false;
  loading = true;
  errorMessage = '';
  stream: MediaStream | null = null;
  capturedImage: string | null = null;
  uploading = false;
  success = false;
  cameraStarted = false;
  debugInfo = '';
  isCameraError = false;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    public captureService: CaptureService, // public for debug access
    private appConfig: AppConfigService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit() {
    this.route.paramMap.subscribe(params => {
      this.token = params.get('token');
      this.retry();
    });
  }

  retry() {
    const apiParam = this.route.snapshot.queryParamMap.get('api');
    if (apiParam) {
      this.appConfig.setApiBaseUrl(apiParam);
    }

    this.loading = true;
    this.errorMessage = '';
    // Show what API we are trying to hit
    // Access the private getter via 'any' cast for debug display only
    const apiUrl = (this.captureService as any).apiUrl;
    this.debugInfo = `API: ${apiUrl}`;
    if (!window.isSecureContext) {
      this.debugInfo += ' | insecure context';
    }

    if (this.token) {
        this.validateToken(this.token);
    } else {
        this.loading = false;
        this.errorMessage = 'No session token provided.';
    }
  }

  validateToken(token: string) {
    console.log('Validating token:', token);
    const apiUrl = `${(this.captureService as any).apiUrl}/capture/validate/${token}`;
    console.log('API URL:', apiUrl);
    
    this.captureService.validateToken(token).pipe(
        tap(response => console.log('Raw response from validateToken:', response)),
        take(1),
        timeout(5000),
        catchError(err => {
          console.error('Error in validateToken observable:', err);
          throw err;
        })
    ).subscribe({
      next: (response) => {
        console.log('Token validated successfully - next() called');
        console.log('Response:', response);
        this.isValidSession = true;
        this.loading = false;
        this.cdr.detectChanges();
        console.log('Starting camera... isValidSession=', this.isValidSession, 'loading=', this.loading);
        setTimeout(() => {
          this.startCamera();
        }, 100);
      },
      error: (err) => {
        console.error('Token validation failed - error() called:', err);
        this.loading = false;
        this.errorMessage = `Connection Failed. ${err.message || ''}`;
        
        if (err.name === 'TimeoutError') {
             this.errorMessage += ' (Timeout). Backend unreachable.';
        }
        this.cdr.detectChanges();
      },
      complete: () => {
        console.log('Token validation observable completed');
      }
    });
  }

  async startCamera() {
    console.log('startCamera called');
    this.isCameraError = false;
    
    // Check for secure context or localhost
    console.log('Checking mediaDevices API...');
    console.log('navigator.mediaDevices:', navigator.mediaDevices);
    console.log('isSecureContext:', window.isSecureContext);
    
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn('Camera API not available');
        this.errorMessage = 'Camera API blocked (HTTP). Use the button below.';
        this.debugInfo += ` | Secure: ${window.isSecureContext}`;
        this.isCameraError = true;
        this.loading = false;
        return;
    }

    try {
      console.log('Requesting camera access...');
      this.stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' } 
      });
      console.log('Camera access granted, stream:', this.stream);
      
      if (this.videoElement) {
        console.log('Video element found, setting srcObject');
        const videoEl = this.videoElement.nativeElement;
        videoEl.srcObject = this.stream;
        try {
          console.log('Attempting to play video...');
          await videoEl.play();
          console.log('Video playing successfully');
          this.cameraStarted = true;
          this.debugInfo += ' | Camera stream started';
        } catch (playErr: any) {
          console.error('Video play error:', playErr);
          this.isCameraError = true;
          this.errorMessage = 'Camera stream blocked. Tap the button below to open native camera.';
          this.debugInfo += ` | play() error: ${playErr?.message || playErr}`;
        }
      } else {
        console.warn('Video element not found');
      }
    } catch (err: any) {
      console.error('getUserMedia error:', err);
      this.isCameraError = true;
      this.loading = false;
      this.errorMessage = 'Could not access camera.';
      if (err.name === 'NotAllowedError') {
          this.errorMessage += ' Permission denied.';
      } else if (err.name === 'NotFoundError') {
          this.errorMessage += ' No camera found.';
      } else {
          this.errorMessage += ` ${err.name}: ${err.message}`;
      }
      console.error(err);
    }
  }

  onFileSelected(event: any) {
      const file = event.target.files[0];
      if (file) {
          const reader = new FileReader();
          reader.onload = (e: any) => {
              this.capturedImage = e.target.result;
              this.errorMessage = '';
              this.isCameraError = false;
          };
          reader.readAsDataURL(file);
      }
  }

    openNativeCapture() {
      if (this.fileInput) {
        this.fileInput.nativeElement.click();
      }
    }

  capturePhoto() {
    if (!this.videoElement || !this.canvasElement) return;

    const video = this.videoElement.nativeElement;
    const canvas = this.canvasElement.nativeElement;
    
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.drawImage(video, 0, 0);
      this.capturedImage = canvas.toDataURL('image/jpeg', 0.8);
      this.stopCamera();
    }
  }

  retake() {
    this.capturedImage = null;
    this.startCamera();
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
      this.cameraStarted = false;
    }
  }

  uploadPhoto() {
    if (!this.capturedImage || !this.token) return;

    this.uploading = true;
    this.captureService.uploadImage(this.token, this.capturedImage).subscribe({
      next: () => {
        this.uploading = false;
        this.success = true;
      },
      error: (err) => {
        this.uploading = false;
        this.errorMessage = 'Failed to upload image. Please try again.';
        console.error(err);
      }
    });
  }

  ngOnDestroy() {
    this.stopCamera();
  }
}
