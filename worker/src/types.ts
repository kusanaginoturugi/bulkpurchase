export interface Env {
  DB: D1Database;
  BROWSER: BrowserRun;
  AUTHENTIK_ISSUER: string;
  AUTHENTIK_CLIENT_ID: string;
  AUTHENTIK_CLIENT_SECRET: string;
  AUTHENTIK_REQUIRED_GROUP: string;
  AUTHENTIK_ADMIN_USERNAMES: string;
  SESSION_SECRET: string;
  TENDO_UPLOAD_URL: string;
  TENDO_DESTINATION: string;
  TENDO_SENDER_NAME: string;
  TENDO_FELLOWSHIP_NAME: string;
  TENDO_NOTIFICATION_EMAIL: string;
  RESEND_API_KEY?: string;
  RESEND_FROM?: string;
}

export interface SessionUser {
  id: number;
  name: string;
  email: string;
  fellowshipId: number;
  fellowshipCode: string;
  fellowshipName: string;
  role: "user" | "admin";
  csrfToken: string;
}

export interface Fellowship {
  id: number;
  code: string;
  name: string;
}

export interface Item {
  id: number;
  code: string;
  name: string;
  unit: string;
  special_handling_type: string;
}
