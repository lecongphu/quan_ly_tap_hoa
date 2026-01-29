export interface UserProfile {
  id: string;
  full_name: string;
  role_id?: string | null;
  role_name?: string | null;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface LoginSession {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
}

export interface LoginResponse {
  session: LoginSession;
  user: {
    id: string;
    email?: string;
  };
  profile: UserProfile;
  permissions?: Array<{ code: string; name: string; module: string }>;
}