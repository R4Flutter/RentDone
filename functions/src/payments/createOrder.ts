import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { db, FieldValue } from "../utils/firebase";
import { AppLogger } from "../shared/logger";
import { loadPaymentFeeConfig, calculateFeeBreakdownInPaise } from "./paymentUtils";

export interface RazorpayOrderRequest {
  paymentId: string;
}

export interface RazorpayOrderResponse {
  orderId: string;
  keyId: string;
  amount: number;
  currency: string;
}

/**
 * Creates a Razorpay order for an existing payment record.
 * Validates ownership and applies convenience fees.
 */
export const createRazorpayOrder = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { paymentId } = request.data as RazorpayOrderRequest;
    if (!paymentId) {
      throw new HttpsError("invalid-argument", "paymentId is required");
    }

    AppLogger.info("Initiating Razorpay order creation", { uid, paymentId });

    try {
      const paymentRef = db.collection("payments").doc(paymentId);
      const paymentDoc = await paymentRef.get();

      if (!paymentDoc.exists) {
        throw new HttpsError("not-found", "Payment record not found");
      }

      const paymentData = paymentDoc.data();
      if (paymentData?.tenantId !== uid) {
        AppLogger.warn("Unauthorized order creation attempt", { uid, paymentId });
        throw new HttpsError("permission-denied", "You are not authorized to pay this record");
      }

      if (paymentData?.status === "paid") {
        throw new HttpsError("failed-precondition", "Payment is already completed");
      }

      // 1. Idempotency Check: Return existing order if already created
      if (paymentData?.razorpayOrderId) {
        AppLogger.info("Returning existing Razorpay order", { paymentId, orderId: paymentData.razorpayOrderId });
        return {
          orderId: paymentData.razorpayOrderId,
          keyId: paymentData.razorpayKeyId || functions.config().razorpay.key_id,
          amount: paymentData.totalPayablePaise || paymentData.amount,
          currency: "INR",
        } as RazorpayOrderResponse;
      }

      const baseAmount = Number(paymentData?.baseAmount || paymentData?.amount);
      const config = await loadPaymentFeeConfig("razorpay");
      const breakdown = calculateFeeBreakdownInPaise({
        rentAmountInRupees: baseAmount,
        config,
      });

      // 2. Secure Secrets: Fetch Razorpay credentials from Firebase config
      const razorConfig = functions.config().razorpay;
      const keyId = razorConfig?.key_id || "";
      const keySecret = razorConfig?.key_secret || "";

      if (!keyId || !keySecret) {
        AppLogger.error("Razorpay credentials missing in functions config");
        throw new HttpsError("internal", "Payment gateway misconfigured");
      }

      const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
      const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: breakdown.totalPayableInPaise,
          currency: "INR",
          receipt: paymentId,
          notes: {
            tenantId: uid,
            paymentId,
            convenienceFee: breakdown.convenienceFeeInPaise,
          },
        }),
      });

      if (!orderRes.ok) {
        const errorText = await orderRes.text();
        AppLogger.error("Razorpay API failure", { status: orderRes.status, errorText });
        throw new HttpsError("internal", "Gateway order creation failed");
      }

      const order = await orderRes.json();

      // Atomically link order ID to payment record
      await paymentRef.update({
        razorpayOrderId: order.id,
        razorpayKeyId: keyId,
        convenienceFeePaise: breakdown.convenienceFeeInPaise,
        totalPayablePaise: breakdown.totalPayableInPaise,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        orderId: order.id,
        keyId,
        amount: breakdown.totalPayableInPaise,
        currency: "INR",
      } as RazorpayOrderResponse;

    } catch (error) {
      if (error instanceof HttpsError) throw error;
      AppLogger.error("Unexpected error in createRazorpayOrder", error, { paymentId });
      throw new HttpsError("internal", "Internal processing error");
    }
  }
);
