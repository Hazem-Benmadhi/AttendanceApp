import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Session } from '../models/models';
import { AppConfigService } from './app-config.service';

@Injectable({
  providedIn: 'root'
})
export class CaptureService {
  constructor(private http: HttpClient, private appConfig: AppConfigService) { }

  private get apiUrl(): string {
    return this.appConfig.apiBaseUrl;
  }

  get apiBaseUrl(): string {
    return this.apiUrl;
  }

  private get wsUrl(): string {
    return this.appConfig.websocketBaseUrl;
  }

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

  endCaptureSession(token: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/capture/session/${token}`);
  }
}
