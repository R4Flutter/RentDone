import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const db = getFirestore();
export const messaging = getMessaging();
export { FieldValue, Timestamp };
