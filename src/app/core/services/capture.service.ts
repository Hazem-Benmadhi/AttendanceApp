import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Session } from '../models/models';

@Injectable({
  providedIn: 'root'
})
export class CaptureService {
  // Dynamically determine the API URL based on the current window location
  // This allows the app to work when accessed via IP address on mobile devices
  private get baseUrl(): string {
    return window.location.hostname;
  }
  
  private get apiUrl(): string {
    return `http://${this.baseUrl}:8000`;
  }

  private get wsUrl(): string {
    return `ws://${this.baseUrl}:8000`;
  }

  constructor(private http: HttpClient) { }

  startCaptureSession(session: Session): Observable<{ token: string, expires_in: number }> {
    return this.http.post<{ token: string, expires_in: number }>(`${this.apiUrl}/capture/start`, { session });
  }

  validateToken(token: string): Observable<{ valid: boolean }> {
    return this.http.get<{ valid: boolean }>(`${this.apiUrl}/capture/validate/${token}`);
  }

  uploadImage(token: string, image: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/capture/upload/${token}`, { image });
  }

  connectWebSocket(token: string): WebSocket {
    return new WebSocket(`${this.wsUrl}/ws/capture/${token}`);
  }
}
