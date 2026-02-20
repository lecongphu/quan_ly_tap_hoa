import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, from, tap } from 'rxjs';
import { LoginResponse, UserProfile } from '../models/user.model';
import { supabase } from './supabase.client';

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

  login(email: string, password: string): Observable<LoginResponse> {
    return from(
      (async () => {
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password
        });

        if (error || !data.session || !data.user) {
          throw error ?? new Error('Authentication failed');
        }

        const rpc = await supabase.rpc('get_my_profile_with_permissions');
        if (rpc.error || !rpc.data) {
          throw rpc.error ?? new Error('Profile not found');
        }

        const payload = rpc.data as {
          profile: UserProfile;
          permissions: Array<{ code: string; name: string; module: string }>;
        };

        const response: LoginResponse = {
          session: data.session,
          user: {
            id: data.user.id,
            email: data.user.email ?? undefined
          },
          profile: payload.profile,
          permissions: payload.permissions ?? []
        };

        this.saveSession(response.session);
        this.saveProfile(response.profile);
        return response;
      })()
    );
  }

  logout(): Observable<void> {
    return from(
      (async () => {
        await supabase.auth.signOut();
        this.clearSession();
      })()
    ).pipe(
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

  async hasActiveSession(): Promise<boolean> {
    if (this.isAuthenticated) {
      return true;
    }

    const { data, error } = await supabase.auth.getSession();
    if (error || !data.session) {
      this.clearSession();
      return false;
    }

    this.saveSession({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at ?? undefined
    });

    await this.ensureProfileLoaded();
    return true;
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

  private async ensureProfileLoaded(): Promise<void> {
    if (this.profileSubject.value) return;

    const rpc = await supabase.rpc('get_my_profile_with_permissions');
    if (rpc.error || !rpc.data) return;

    const payload = rpc.data as { profile?: UserProfile };
    if (payload.profile) {
      this.saveProfile(payload.profile);
    }
  }

  clearSession(): void {
    localStorage.removeItem(this.sessionKey);
    localStorage.removeItem(this.profileKey);
    this.profileSubject.next(null);
  }
}
