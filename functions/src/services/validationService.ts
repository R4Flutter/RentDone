import { db } from "../utils/firebase";

const safeString = (value: unknown): string => String(value ?? "").trim();

export interface PaymentValidationResult {
  ownerId: string;
  tenantId: string;
  amount: number;
  tenantName: string;
  valid: boolean;
}

export const validatePaymentForNotification = async (
  payment: FirebaseFirestore.DocumentData,
): Promise<PaymentValidationResult> => {
  const ownerId = safeString(payment.ownerId);
  const tenantId = safeString(payment.tenantId);
  const amount = Number(payment.amount ?? payment.paidAmount ?? 0);

  if (!ownerId || !tenantId || !Number.isFinite(amount) || amount <= 0) {
    return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
  }

  const [ownerDoc, tenantDoc] = await Promise.all([
    db.collection("users").doc(ownerId).get(),
    db.collection("tenants").doc(tenantId).get(),
  ]);

  if (!ownerDoc.exists || !tenantDoc.exists) {
    return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
  }

  const ownerRole = safeString(ownerDoc.get("role")).toLowerCase();
  if (ownerRole !== "owner") {
    return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
  }

  const tenantOwnerId = safeString(tenantDoc.get("ownerId"));
  if (tenantOwnerId !== ownerId) {
    return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
  }

  const tenantName = safeString(tenantDoc.get("fullName") ?? tenantDoc.get("name")) || "Tenant";

  return {
    ownerId,
    tenantId,
    amount,
    tenantName,
    valid: true,
  };
};
