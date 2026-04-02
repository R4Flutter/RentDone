import { onCall, HttpsError } from "firebase-functions/v2/https";
import { createHmac, timingSafeEqual } from "node:crypto";

import { db, FieldValue } from "../utils/firebase";

const REGION = "asia-south1";

const asString = (value: unknown): string => String(value ?? "").trim();
const asInt = (value: unknown): number => {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) return 0;
  return Math.trunc(parsed);
};

/**
 * Reference implementation for secure Razorpay verification.
 * Flow: client checkout -> callable verify -> backend validation -> backend write.
 */
export const verifyPaymentSecureExample = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    const paymentId = asString(request.data?.paymentId);
    const razorpayOrderId = asString(request.data?.razorpayOrderId);
    const razorpayPaymentId = asString(request.data?.razorpayPaymentId);
    const razorpaySignature = asString(request.data?.razorpaySignature);

    if (!paymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new HttpsError("invalid-argument", "invalid-verification-payload");
    }

    const paymentRef = db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
      throw new HttpsError("not-found", "payment-not-found");
    }

    const payment = paymentDoc.data() ?? {};
    const ownerId = asString(payment.ownerId);
    const tenantId = asString(payment.tenantId);

    // Restrict verify caller to the payment participants only.
    if (callerUid !== ownerId && callerUid !== tenantId) {
      throw new HttpsError("permission-denied", "unauthorized");
    }

    const storedOrderId = asString(payment.razorpayOrderId);
    if (!storedOrderId || storedOrderId !== razorpayOrderId) {
      throw new HttpsError("failed-precondition", "order-mismatch");
    }

    const keyId = asString(process.env.RAZORPAY_KEY_ID);
    const keySecret = asString(process.env.RAZORPAY_KEY_SECRET || process.env.RAZORPAY_SECRET);
    if (!keyId || !keySecret) {
      throw new HttpsError("failed-precondition", "razorpay-secret-missing");
    }

    // 1) Verify signature integrity.
    const expectedSignature = createHmac("sha256", keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    const provided = Buffer.from(razorpaySignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
      throw new HttpsError("permission-denied", "invalid-signature");
    }

    // 2) Fetch payment from Razorpay and validate order/amount/currency/status.
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    const response = await fetch(
      `https://api.razorpay.com/v1/payments/${encodeURIComponent(razorpayPaymentId)}`,
      {
        method: "GET",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/json",
        },
      },
    );

    if (!response.ok) {
      const body = await response.text();
      throw new HttpsError("internal", `razorpay-fetch-failed:${body}`);
    }

    const remote = (await response.json()) as Record<string, unknown>;
    const remoteOrderId = asString(remote.order_id);
    const remoteAmount = asInt(remote.amount);
    const remoteCurrency = asString(remote.currency).toUpperCase();
    const remoteStatus = asString(remote.status).toLowerCase();

    const expectedAmount = asInt(payment.amountInPaise ?? (asInt(payment.amount) * 100));
    const expectedCurrency = asString(payment.currency || "INR").toUpperCase();

    if (remoteOrderId !== razorpayOrderId) {
      throw new HttpsError("failed-precondition", "razorpay-order-validation-failed");
    }
    if (remoteAmount !== expectedAmount) {
      throw new HttpsError("failed-precondition", "razorpay-amount-validation-failed");
    }
    if (remoteCurrency !== expectedCurrency) {
      throw new HttpsError("failed-precondition", "razorpay-currency-validation-failed");
    }
    if (remoteStatus !== "captured") {
      throw new HttpsError("failed-precondition", `payment-not-captured:${remoteStatus}`);
    }

    // 3) Write payment result from backend only.
    await paymentRef.set(
      {
        status: "paid",
        method: "razorpay",
        paidAmount: Math.trunc(expectedAmount / 100),
        remainingAmount: 0,
        transactionId: razorpayPaymentId,
        razorpayOrderId,
        razorpaySignature,
        verifiedBy: callerUid,
        verifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      ok: true,
      paymentId,
      status: "paid",
      amountInPaise: expectedAmount,
      currency: expectedCurrency,
    };
  },
);
