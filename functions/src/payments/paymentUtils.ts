import { db } from "../utils/firebase";
import { AppLogger } from "../shared/logger";
import * as functions from "firebase-functions/v2";

export interface PaymentFeeConfig {
  gateway: string;
  gatewayPercent: number;
  gatewayCostPercent: number;
  gstPercent: number;
}

export interface FeeBreakdown {
  rentAmountInPaise: number;
  convenienceFeeInPaise: number;
  totalPayableInPaise: number;
  estimatedGatewayCostInPaise: number;
  netProfitInPaise: number;
  gatewayPercent: number;
  gatewayCostPercent: number;
  gstPercent: number;
}

/**
 * Loads payment fee configuration from Firestore with hardcoded production overrides.
 */
export async function loadPaymentFeeConfig(gateway = "razorpay"): Promise<PaymentFeeConfig> {
  const safeGateway = gateway.trim().toLowerCase();

  // Production policy lock: Razorpay convenience fee is fixed at 2%
  // with 18% GST on gateway fee (effective 2.36% on base rent).
  if (safeGateway === "razorpay") {
    return {
      gateway: safeGateway,
      gatewayPercent: 2,
      gatewayCostPercent: 2,
      gstPercent: 18,
    };
  }

  try {
    const cfgDoc = await db.collection("system_config").doc("payment_fee").get();
    if (cfgDoc.exists) {
      const data = cfgDoc.data();
      return {
        gateway: safeGateway,
        gatewayPercent: Number(data?.gatewayPercent || 2),
        gatewayCostPercent: Number(data?.gatewayCostPercent || 2),
        gstPercent: Number(data?.gstPercent || 18),
      };
    }
  } catch (error) {
    AppLogger.warn("Falling back to default payment fee config", { gateway: safeGateway, error });
  }

  return {
    gateway: safeGateway,
    gatewayPercent: 2,
    gatewayCostPercent: 2,
    gstPercent: 18,
  };
}

/**
 * Calculates the exact fee breakdown for a rent payment.
 */
export function calculateFeeBreakdownInPaise(params: {
  rentAmountInRupees: number;
  config: PaymentFeeConfig;
}): FeeBreakdown {
  const rentAmount = Math.trunc(params.rentAmountInRupees);
  if (!Number.isFinite(rentAmount) || rentAmount <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Rent amount must be a positive integer in rupees"
    );
  }

  const rentAmountInPaise = rentAmount * 100;
  const { gatewayPercent, gatewayCostPercent, gstPercent } = params.config;

  const gstBps = Math.round(gstPercent * 100);
  const gatewayBps = Math.round(gatewayPercent * 100);
  const gatewayCostBps = Math.round(gatewayCostPercent * 100);

  // FeeSTAGE calculation: Round upward to protect platform margins
  const feeNumerator = rentAmountInPaise * gatewayBps * (10000 + gstBps);
  const convenienceFeeInPaise = Math.max(1, Math.ceil(feeNumerator / (10000 * 10000)));

  const costNumerator = rentAmountInPaise * gatewayCostBps * (10000 + gstBps);
  const estimatedGatewayCostInPaise = Math.max(0, Math.ceil(costNumerator / (10000 * 10000)));

  const totalPayableInPaise = rentAmountInPaise + convenienceFeeInPaise;
  const netProfitInPaise = convenienceFeeInPaise - estimatedGatewayCostInPaise;

  return {
    rentAmountInPaise,
    convenienceFeeInPaise,
    totalPayableInPaise,
    estimatedGatewayCostInPaise,
    netProfitInPaise,
    gatewayPercent,
    gatewayCostPercent,
    gstPercent,
  };
}
