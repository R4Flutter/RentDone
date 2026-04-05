import { createHmac, timingSafeEqual } from "node:crypto";

import { db, FieldValue, Timestamp } from "../utils/firebase";
import { logError, logInfo, logWarn } from "../utils/logger";

const asString = (value: unknown): string => String(value ?? "").trim();
const asInt = (value: unknown): number => {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) {return 0;}
  return Math.trunc(parsed);
};

type VerifyResult = {
  paymentId: string;
  status: string;
  paidAmount: number;
  remainingAmount: number;
  amountInPaise: number;
  currency: string;
};

export async function verifyRazorpayPayment(params: {
  paymentId: string;
  razorpayOrderId: string;
  razorpayPaymentId: string;
  razorpaySignature: string;
  actorUid: string;
}): Promise<VerifyResult> {
  const { paymentId, razorpayOrderId, razorpayPaymentId, razorpaySignature, actorUid } = params;

  const paymentRef = db.collection("payments").doc(paymentId);
  const paymentDoc = await paymentRef.get();
  if (!paymentDoc.exists) {
    throw new Error("payment-not-found");
  }

  const payment = paymentDoc.data() ?? {};
  const ownerId = asString(payment.ownerId);
  const tenantId = asString(payment.tenantId);
  const storedOrderId = asString(payment.razorpayOrderId);

  if (actorUid !== ownerId && actorUid !== tenantId) {
    throw new Error("unauthorized");
  }

  if (!storedOrderId || storedOrderId !== razorpayOrderId) {
    throw new Error("order-mismatch");
  }

  const keyId = asString(process.env.RAZORPAY_KEY);
  const keySecret = asString(process.env.RAZORPAY_SECRET);
  if (!keyId || !keySecret) {
    throw new Error("razorpay-secret-missing");
  }

  // 1) Verify signature integrity.
  const expectedSignature = createHmac("sha256", keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  const provided = Buffer.from(razorpaySignature);
  const expected = Buffer.from(expectedSignature);
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
    await logWarn("Payment verification failed - invalid signature", {
      paymentId,
      razorpayOrderId,
      razorpayPaymentId,
    });
    throw new Error("invalid-signature");
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
    logError("Razorpay fetch failed", { paymentId, body });
    throw new Error(`razorpay-fetch-failed:${body}`);
  }

  const remote = (await response.json()) as Record<string, unknown>;
  const remoteOrderId = asString(remote.order_id);
  const remoteAmount = asInt(remote.amount);
  const remoteCurrency = asString(remote.currency).toUpperCase();
  const remoteStatus = asString(remote.status).toLowerCase();

  const expectedAmount = asInt(payment.amountInPaise ?? (asInt(payment.amount) * 100));
  const expectedCurrency = asString(payment.currency || "INR").toUpperCase();

  if (remoteOrderId !== razorpayOrderId) {
    throw new Error("razorpay-order-validation-failed");
  }
  if (remoteAmount !== expectedAmount) {
    throw new Error("razorpay-amount-validation-failed");
  }
  if (remoteCurrency !== expectedCurrency) {
    throw new Error("razorpay-currency-validation-failed");
  }
  if (remoteStatus !== "captured") {
    throw new Error(`payment-not-captured:${remoteStatus}`);
  }

  // 3) Write payment result from backend only. Store only a hash of signature.
  const signatureHash = createHmac("sha256", keySecret)
    .update(String(razorpaySignature || ""))
    .digest("hex");

  const paidAt = Timestamp.now();
  const paidDate = paidAt.toDate();

  const receiptNumber = `RCP-${paidDate.getFullYear()}${String(paidDate.getMonth() + 1).padStart(
    2,
    "0",
  )}-${paymentId.slice(-6).toUpperCase()}`;

  await paymentRef.set(
    {
      status: "paid",
      method: "razorpay",
      remoteStatus,
      paidAmount: Math.trunc(expectedAmount / 100),
      remainingAmount: 0,
      transactionId: razorpayPaymentId,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignatureHash: signatureHash,
      verifiedBy: actorUid,
      verifiedAt: FieldValue.serverTimestamp(),
      date: paidAt,
      paymentDate: paidAt,
      paidAt,
      completedAt: paidAt,
      month: paidDate.getMonth() + 1,
      year: paidDate.getFullYear(),
      receiptNumber,
      updatedAt: paidAt,
      amountInPaise: expectedAmount,
      totalPayableInPaise: expectedAmount,
      currency: expectedCurrency,
    },
    { merge: true },
  );

  await logInfo("PAYMENT_VERIFY_SUCCESS", {
    paymentId,
    tenantId: payment.tenantId,
    ownerId: payment.ownerId,
    amount: expectedAmount,
    method: "razorpay",
  });

  return {
    paymentId,
    status: "paid",
    paidAmount: Math.trunc(expectedAmount / 100),
    remainingAmount: 0,
    amountInPaise: expectedAmount,
    currency: expectedCurrency,
  };
}

export default {
  verifyRazorpayPayment,
};
