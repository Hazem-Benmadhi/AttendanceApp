import { Injectable } from '@angular/core';

interface RawAppConfig {
  apiBaseUrl?: string;
}

@Injectable({ providedIn: 'root' })
export class AppConfigService {
  private readonly defaultBaseUrl = 'http://192.168.1.16:8001';
  private apiBaseUrlValue = this.defaultBaseUrl;
  private loaded = false;

  async load(): Promise<void> {
    if (this.loaded) {
      return;
    }

    try {
      const response = await fetch('assets/app-config.json', { cache: 'no-cache' });
      if (!response.ok) {
        throw new Error(`Failed to load config: ${response.status}`);
      }

      const data = (await response.json()) as RawAppConfig;
      if (data.apiBaseUrl && typeof data.apiBaseUrl === 'string' && data.apiBaseUrl.trim().length > 0) {
        this.apiBaseUrlValue = data.apiBaseUrl.trim();
      }
    } catch (error) {
      console.warn('AppConfigService: Falling back to default base URL.', error);
      this.apiBaseUrlValue = this.defaultBaseUrl;
    } finally {
      this.loaded = true;
    }
  }

  get apiBaseUrl(): string {
    return this.apiBaseUrlValue;
  }

  get websocketBaseUrl(): string {
    const httpUrl = this.apiBaseUrlValue;
    if (httpUrl.startsWith('https://')) {
      return `wss://${httpUrl.slice('https://'.length)}`;
    }
    if (httpUrl.startsWith('http://')) {
      return `ws://${httpUrl.slice('http://'.length)}`;
    }
    return httpUrl.replace(/^http(s)?:/, 'ws$1:');
  }

  setApiBaseUrl(url: string | null | undefined): void {
    if (!url) {
      return;
    }
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.apiBaseUrlValue = trimmed;
  }
}
