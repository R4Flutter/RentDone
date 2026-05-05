import { FieldValue, Timestamp } from "../utils/firebase";

export type UserRole = "owner" | "tenant" | "admin";

type FirestoreDate = FieldValue | Timestamp | Date;

export interface User {
  uid: string;
  email: string;
  emailLowercase: string;
  role: UserRole;
  name?: string;
  phoneNumber?: string;
  fcmToken?: string;
  createdAt: FirestoreDate;
  updatedAt: FirestoreDate;
}

export interface Property {
  id: string;
  ownerId: string;
  name: string;
  address: string;
  rooms: Room[];
  createdAt: FirestoreDate;
  updatedAt: FirestoreDate;
}

export interface Room {
  id: string;
  roomNumber: string;
  isOccupied: boolean;
  tenantId?: string;
}

export interface Tenant {
  id: string; // This is the doc ID in 'tenants'
  authUid?: string; // Links to 'users' collection UID
  ownerId: string;
  propertyId: string;
  roomId: string;
  email: string;
  emailLowercase: string;
  phone: string;
  phoneHash: string;
  name: string;
  status: "active" | "inactive" | "pending_assignment";
  trustScore: number;
  rentAmount: number;
  rentDueDay: number;
  createdAt: FirestoreDate;
  updatedAt: FirestoreDate;
}

export interface Payment {
  id: string;
  tenantId: string;
  ownerId: string;
  propertyId: string;
  amount: number;
  baseAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: "pending" | "partial" | "paid" | "failed";
  method: "manual" | "razorpay" | "cash" | "online";
  date: FirestoreDate;
  createdAt: FirestoreDate;
  updatedAt: FirestoreDate;
  transactionId?: string;
  razorpayOrderId?: string;
}

export interface NotificationMessage {
  id: string;
  ownerId?: string;
  tenantId?: string;
  tenantUserId?: string;
  title: string;
  body: string;
  type: string;
  read: boolean;
  severity: "info" | "warning" | "error";
  createdAt: FirestoreDate;
}
