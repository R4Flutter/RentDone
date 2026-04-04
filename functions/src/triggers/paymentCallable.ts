import { onCall, HttpsError } from "firebase-functions/v2/https";
import { createHmac, timingSafeEqual } from "node:crypto";

import { db, FieldValue, Timestamp } from "../utils/firebase";
import { logError, logInfo, logWarn } from "../utils/logger";

const REGION = "asia-south1";
const MIN_PAYMENT_AMOUNT = 1;
const MAX_PAYMENT_AMOUNT = 5_000_000;

type PaymentMethod = "manual" | "razorpay";
type PaymentStatus = "pending" | "partial" | "paid" | "failed";

const asString = (value: unknown): string => String(value ?? "").trim();
const asInt = (value: unknown): number => {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) return 0;
  return Math.trunc(parsed);
};

const normalizeMethod = (value: unknown): PaymentMethod | null => {
  const method = asString(value).toLowerCase();
  if (method === "manual" || method === "razorpay") return method;
  return null;
};

const assertAmountOrThrow = (amount: number): void => {
  if (!Number.isInteger(amount) || amount < MIN_PAYMENT_AMOUNT || amount > MAX_PAYMENT_AMOUNT) {
    throw new HttpsError("invalid-argument", "invalid-amount");
  }
};

const logPaymentEvent = async (
  eventType: string,
  payload: Record<string, unknown>,
): Promise<void> => {
  try {
    await db.collection("_paymentEvents").add({
      eventType,
      ...payload,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logWarn("Payment event logging failed", {
      eventType,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const assertAccessAndOwnership = async (
  uid: string,
  tenantId: string,
  propertyId: string,
): Promise<{ ownerId: string }> => {
  const [tenantDoc, propertyDoc] = await Promise.all([
    db.collection("tenants").doc(tenantId).get(),
    db.collection("properties").doc(propertyId).get(),
  ]);

  if (!tenantDoc.exists) {
    throw new HttpsError("not-found", "invalid-tenant");
  }
  if (!propertyDoc.exists) {
    throw new HttpsError("not-found", "invalid-property");
  }

  const tenantData = tenantDoc.data() ?? {};
  const propertyData = propertyDoc.data() ?? {};

  const ownerId = asString(tenantData.ownerId);
  const tenantPropertyId = asString(tenantData.propertyId);
  const propertyOwnerId = asString(propertyData.ownerId);

  if (!ownerId || tenantPropertyId !== propertyId || propertyOwnerId !== ownerId) {
    throw new HttpsError("failed-precondition", "invalid-owner");
  }

  const isOwnerActor = uid === ownerId;
  const isTenantActor = uid === tenantId;
  if (!isOwnerActor && !isTenantActor) {
    throw new HttpsError("permission-denied", "unauthorized");
  }

  return { ownerId };
};

export const createPayment = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    const tenantId = asString(request.data?.tenantId);
    const propertyId = asString(request.data?.propertyId);
    const idempotencyKey = asString(request.data?.idempotencyKey);
    const method = normalizeMethod(request.data?.method);
    const amount = asInt(request.data?.amount);

    if (!tenantId || !propertyId || !idempotencyKey || !method) {
      throw new HttpsError("invalid-argument", "invalid-request");
    }

    assertAmountOrThrow(amount);

    await logPaymentEvent("PAYMENT_CREATE_ATTEMPT", {
      tenantId,
      propertyId,
      actorUid: uid,
      amount,
      method,
      idempotencyKey,
    });

    try {
      const { ownerId } = await assertAccessAndOwnership(uid, tenantId, propertyId);

      const existingByIdempotency = await db
        .collection("payments")
        .where("idempotencyKey", "==", idempotencyKey)
        .limit(1)
        .get();

      if (!existingByIdempotency.empty) {
        const existing = existingByIdempotency.docs[0];
        const existingData = existing.data();
        return {
          paymentId: existing.id,
          status: asString(existingData.status).toLowerCase() || "pending",
          idempotent: true,
        };
      }

      const duplicateCutoff = Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 1000));
      const duplicates = await db
        .collection("payments")
        .where("tenantId", "==", tenantId)
        .where("baseAmount", "==", amount)
        .where("createdAt", ">=", duplicateCutoff)
        .limit(1)
        .get();

      if (!duplicates.empty) {
        await logPaymentEvent("PAYMENT_CREATE_FAILED", {
          tenantId,
          ownerId,
          amount,
          method,
          errorReason: "duplicate-payment",
        });
        throw new HttpsError("already-exists", "duplicate-payment");
      }

      const paymentRef = db.collection("payments").doc();
      const paidAmount = method === "manual" ? amount : 0;
      const remainingAmount = amount - paidAmount;
      const status: PaymentStatus = method === "manual" ? "paid" : "pending";

      await db.runTransaction(async (tx) => {
        tx.set(paymentRef, {
          id: paymentRef.id,
          tenantId,
          ownerId,
          propertyId,
          amount,
          baseAmount: amount,
          paidAmount,
          remainingAmount,
          status,
          method,
          currency: "INR",
          idempotencyKey,
          installments:
            method === "manual"
              ? [
                  {
                    amount,
                    date: FieldValue.serverTimestamp(),
                    method: "manual",
                    notes: "manual payment",
                  },
                ]
              : [],
          date: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      const createdDoc = await paymentRef.get();
      const created = createdDoc.data();
      if (!createdDoc.exists || !created) {
        throw new HttpsError("internal", "internal-error");
      }

      const baseAmount = asInt(created.baseAmount);
      const paid = asInt(created.paidAmount);
      const remaining = asInt(created.remainingAmount);
      if (baseAmount <= 0 || paid + remaining !== baseAmount) {
        throw new HttpsError("internal", "integrity-check-failed");
      }

      await logPaymentEvent("PAYMENT_CREATE_SUCCESS", {
        paymentId: paymentRef.id,
        tenantId,
        ownerId,
        amount,
        method,
      });

      return { paymentId: paymentRef.id, status, idempotent: false };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logError("createPayment failed", {
        actorUid: uid,
        tenantId,
        propertyId,
        amount,
        method,
        error: error instanceof Error ? error.message : String(error),
      });

      await logPaymentEvent("PAYMENT_CREATE_FAILED", {
        tenantId,
        propertyId,
        amount,
        method,
        errorReason: error instanceof Error ? error.message : String(error),
      });

      throw new HttpsError("internal", "internal-error");
    }
  },
);

export const updatePaymentStatus = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    const paymentId = asString(request.data?.paymentId);
    const requestedStatus = asString(request.data?.newStatus).toLowerCase();
    const installmentAmount = asInt(request.data?.installmentAmount);
    const installmentMethod = asString(request.data?.installmentMethod || "manual").toLowerCase();
    const installmentNotes = asString(request.data?.installmentNotes);

    if (!paymentId || !["paid", "partial", "unpaid"].includes(requestedStatus)) {
      throw new HttpsError("invalid-argument", "invalid-status");
    }

    const paymentRef = db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
      throw new HttpsError("not-found", "payment-not-found");
    }

    const data = paymentDoc.data() ?? {};
    const ownerId = asString(data.ownerId);
    if (uid !== ownerId) {
      throw new HttpsError("permission-denied", "unauthorized");
    }

    const baseAmount = asInt(data.baseAmount ?? data.amount);
    let paidAmount = asInt(data.paidAmount);
    const installmentsRaw = Array.isArray(data.installments) ? data.installments : [];
    const installments = [...installmentsRaw];

    if (requestedStatus === "partial") {
      if (installmentAmount <= 0) {
        throw new HttpsError("invalid-argument", "invalid-amount");
      }

      const remainingBefore = Math.max(0, baseAmount - paidAmount);
      if (installmentAmount > remainingBefore) {
        throw new HttpsError("failed-precondition", "invalid-installment");
      }

      paidAmount += installmentAmount;
      installments.push({
        amount: installmentAmount,
        date: FieldValue.serverTimestamp(),
        method: installmentMethod || "manual",
        notes: installmentNotes || null,
      });
    } else if (requestedStatus === "paid") {
      paidAmount = baseAmount;
      installments.push({
        amount: Math.max(0, baseAmount - asInt(data.paidAmount)),
        date: FieldValue.serverTimestamp(),
        method: installmentMethod || "manual",
        notes: installmentNotes || "status updated to paid",
      });
    } else {
      paidAmount = 0;
      installments.length = 0;
    }

    const safePaid = Math.max(0, Math.min(baseAmount, paidAmount));
    const remainingAmount = Math.max(0, baseAmount - safePaid);
    const resolvedStatus: PaymentStatus = remainingAmount === 0 ? "paid" : safePaid > 0 ? "partial" : "pending";

    await paymentRef.update({
      paidAmount: safePaid,
      remainingAmount,
      status: resolvedStatus,
      installments,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      paymentId,
      status: resolvedStatus,
      paidAmount: safePaid,
      remainingAmount,
    };
  },
);

export const verifyPayment = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    const paymentId = asString(request.data?.paymentId);
    const legacyPayload = (request.data?.payload ?? {}) as Record<string, unknown>;

    const razorpayPaymentId = asString(
      request.data?.razorpayPaymentId ?? legacyPayload.paymentId,
    );
    const razorpaySignature = asString(
      request.data?.razorpaySignature ?? legacyPayload.signature,
    );
    const razorpayOrderId = asString(
      request.data?.razorpayOrderId ?? legacyPayload.orderId,
    );

    if (!paymentId || !razorpayPaymentId || !razorpaySignature || !razorpayOrderId) {
      throw new HttpsError("invalid-argument", "invalid-verification-payload");
    }

    const paymentRef = db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
      throw new HttpsError("not-found", "payment-not-found");
    }

    const paymentData = paymentDoc.data() ?? {};
    const ownerId = asString(paymentData.ownerId);
    const tenantId = asString(paymentData.tenantId);
    const baseAmount = asInt(paymentData.baseAmount ?? paymentData.amount);
    const existingStatus = asString(paymentData.status).toLowerCase();
    const existingTransactionId = asString(paymentData.transactionId);

    if (uid !== ownerId && uid !== tenantId) {
      throw new HttpsError("permission-denied", "unauthorized");
    }

    if (existingStatus === "paid" && existingTransactionId === razorpayPaymentId) {
      return {
        paymentId,
        status: "paid",
        paidAmount: baseAmount,
        remainingAmount: 0,
      };
    }

    const razorpaySecret = asString(process.env.RAZORPAY_KEY_SECRET || process.env.RAZORPAY_SECRET);
    if (!razorpaySecret) {
      throw new HttpsError("failed-precondition", "razorpay-secret-missing");
    }

    const expectedSignature = createHmac("sha256", razorpaySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    const provided = Buffer.from(razorpaySignature);
    const expected = Buffer.from(expectedSignature);

    if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
      await logPaymentEvent("PAYMENT_VERIFY_FAILED", {
        paymentId,
        tenantId,
        ownerId,
        errorReason: "invalid-signature",
      });
      throw new HttpsError("permission-denied", "invalid-signature");
    }

    const paidAt = Timestamp.now();
    const paidDate = paidAt.toDate();
    const receiptNumber = `RCP-${paidDate.getFullYear()}${String(
      paidDate.getMonth() + 1,
    ).padStart(2, "0")}-${paymentId.slice(-6).toUpperCase()}`;

    await paymentRef.update({
      status: "paid",
      method: "razorpay",
      paidAmount: baseAmount,
      remainingAmount: 0,
      transactionId: razorpayPaymentId,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
      date: paidAt,
      paymentDate: paidAt,
      paidAt,
      completedAt: paidAt,
      month: paidDate.getMonth() + 1,
      year: paidDate.getFullYear(),
      receiptNumber,
      updatedAt: paidAt,
    });

    await logPaymentEvent("PAYMENT_VERIFY_SUCCESS", {
      paymentId,
      tenantId,
      ownerId,
      amount: baseAmount,
      method: "razorpay",
    });

    logInfo("Payment verified", {
      paymentId,
      tenantId,
      ownerId,
      actorUid: uid,
    });

    return {
      paymentId,
      status: "paid",
      paidAmount: baseAmount,
      remainingAmount: 0,
    };
  },
);
