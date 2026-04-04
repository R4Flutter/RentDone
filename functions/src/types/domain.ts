import { DocumentReference } from "firebase-admin/firestore";

export type NotificationType = "PAYMENT_RECEIVED" | "RENT_DUE_REMINDER" | "CHEAPER_PROPERTY_ALERT";

export interface DeviceTokenDoc {
  token: string;
  platform: "android" | "ios" | "web" | "unknown";
  createdAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  lastUsedAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
}

export interface UserTokenBundle {
  tokens: string[];
  tokenRefs: Map<string, DocumentReference>;
}

export interface PushPayload {
  title: string;
  body: string;
  data: Record<string, string>;
  type: NotificationType;
}

export interface NotificationDispatchResult {
  sentCount: number;
  invalidTokens: string[];
  transientFailures: number;
}
