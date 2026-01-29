import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { ApiService } from './api.service';
import { LoginResponse, UserProfile } from '../models/user.model';

interface StoredSession {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly sessionKey = 'qlth.session';
  private readonly profileKey = 'qlth.profile';

  private profileSubject = new BehaviorSubject<UserProfile | null>(this.loadProfile());
  profile$ = this.profileSubject.asObservable();

  constructor(private api: ApiService) {}

  login(email: string, password: string): Observable<LoginResponse> {
    return this.api.post<LoginResponse>('/auth/login', { email, password }).pipe(
      tap((response) => {
        this.saveSession(response.session);
        this.saveProfile(response.profile);
      })
    );
  }

  logout(): Observable<void> {
    return this.api.post<void>('/auth/logout').pipe(
      tap(() => {
        this.clearSession();
      })
    );
  }

  get token(): string | null {
    const session = this.loadSession();
    if (!session) return null;
    if (this.isSessionExpired(session)) {
      this.clearSession();
      return null;
    }
    return session.access_token ?? null;
  }

  get profile(): UserProfile | null {
    return this.profileSubject.value;
  }

  get isAuthenticated(): boolean {
    return !!this.token;
  }

  private isSessionExpired(session: StoredSession): boolean {
    if (!session.expires_at) return false;
    const nowSeconds = Math.floor(Date.now() / 1000);
    return nowSeconds >= session.expires_at;
  }

  private saveSession(session: StoredSession): void {
    localStorage.setItem(this.sessionKey, JSON.stringify(session));
  }

  private loadSession(): StoredSession | null {
    const raw = localStorage.getItem(this.sessionKey);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as StoredSession;
    } catch {
      return null;
    }
  }

  private saveProfile(profile: UserProfile): void {
    localStorage.setItem(this.profileKey, JSON.stringify(profile));
    this.profileSubject.next(profile);
  }

  private loadProfile(): UserProfile | null {
    const raw = localStorage.getItem(this.profileKey);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as UserProfile;
    } catch {
      return null;
    }
  }

  clearSession(): void {
    localStorage.removeItem(this.sessionKey);
    localStorage.removeItem(this.profileKey);
    this.profileSubject.next(null);
  }
}
