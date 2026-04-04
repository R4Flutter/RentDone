"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTenantCheaperPropertyAlerts = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_1 = require("../utils/firebase");
const rateLimitService_1 = require("../services/rateLimitService");
const notificationService_1 = require("../services/notificationService");
const tokenService_1 = require("../services/tokenService");
const cityKey_1 = require("../utils/cityKey");
const logger_1 = require("../utils/logger");
const REGION = "asia-south1";
const MAX_TENANTS_PER_RUN = 220;
const MAX_CITY_PROPERTIES = 80;
const MIN_SAVINGS_RUPEES = 100;
const asString = (value) => String(value ?? "").trim();
const asInt = (value) => {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.trunc(parsed);
};
const inr = (value) => new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
const getDateBucket = () => {
    const now = new Date();
    const slot = Math.floor(now.getHours() / 6); // 4 slots/day
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    const d = String(now.getDate()).padStart(2, "0");
    return `${y}${m}${d}_slot${slot}`;
};
const estimatePropertyRent = (data) => {
    const direct = asInt(data.rentAmount ??
        data.monthlyRent ??
        data.startingRent ??
        data.pricePerMonth ??
        data.price);
    if (direct > 0) {
        return direct;
    }
    const roomsRaw = Array.isArray(data.rooms) ? data.rooms : [];
    let best = Number.MAX_SAFE_INTEGER;
    for (const room of roomsRaw) {
        if (!room || typeof room !== "object")
            continue;
        const map = room;
        const occupied = map.isOccupied === true;
        if (occupied)
            continue;
        const roomRent = asInt(map.rentAmount ?? map.monthlyRent ?? map.pricePerMonth ?? map.price);
        if (roomRent > 0 && roomRent < best) {
            best = roomRent;
        }
    }
    return best === Number.MAX_SAFE_INTEGER ? 0 : best;
};
const getVacantRooms = (data) => {
    const directVacant = asInt(data.vacantRooms);
    if (directVacant > 0)
        return directVacant;
    const totalRooms = asInt(data.totalRooms);
    const roomsRaw = Array.isArray(data.rooms) ? data.rooms : [];
    if (roomsRaw.length > 0) {
        let occupied = 0;
        for (const room of roomsRaw) {
            if (!room || typeof room !== "object")
                continue;
            const map = room;
            if (map.isOccupied === true)
                occupied += 1;
        }
        return Math.max(0, roomsRaw.length - occupied);
    }
    if (totalRooms <= 0)
        return 0;
    return totalRooms;
};
const findCheaperCandidate = async (cityKey, tenantRent) => {
    const snapshot = await firebase_1.db
        .collection("properties")
        .where("isPublished", "==", true)
        .where("cityKey", "==", cityKey)
        .limit(MAX_CITY_PROPERTIES)
        .get();
    let best = null;
    for (const doc of snapshot.docs) {
        const data = doc.data();
        const vacantRooms = getVacantRooms(data);
        if (vacantRooms <= 0)
            continue;
        const rent = estimatePropertyRent(data);
        if (rent <= 0)
            continue;
        if (rent >= tenantRent)
            continue;
        const savings = tenantRent - rent;
        if (savings < MIN_SAVINGS_RUPEES)
            continue;
        if (!best || rent < best.rent) {
            best = { rent, propertyId: doc.id };
        }
    }
    return best;
};
const isNotificationsEnabled = async (userId) => {
    const userDoc = await firebase_1.db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
        return true;
    }
    const raw = userDoc.get("notificationsEnabled");
    return typeof raw === "boolean" ? raw : true;
};
exports.sendTenantCheaperPropertyAlerts = (0, scheduler_1.onSchedule)({
    schedule: "0 */6 * * *",
    timeZone: "Asia/Kolkata",
    region: REGION,
    retryCount: 1,
    maxRetrySeconds: 180,
}, async () => {
    const dateBucket = getDateBucket();
    try {
        const tenantsSnapshot = await firebase_1.db
            .collection("tenants")
            .where("isActive", "==", true)
            .limit(MAX_TENANTS_PER_RUN)
            .get();
        let processed = 0;
        let sentCount = 0;
        for (const tenantDoc of tenantsSnapshot.docs) {
            let eventId = null;
            let eventReserved = false;
            try {
                const tenant = tenantDoc.data();
                const tenantId = tenantDoc.id;
                const tenantUserId = asString(tenant.authUid) || tenantId;
                const tenantRent = asInt(tenant.rentAmount ?? tenant.monthlyRent);
                if (!tenantUserId || tenantRent <= 0)
                    continue;
                const cityRaw = tenant.city ?? tenant.currentCity ?? tenant.propertyCity ?? "";
                const cityKey = (0, cityKey_1.normalizeCityKey)(tenant.cityKey ?? cityRaw);
                if (!cityKey)
                    continue;
                const city = asString(tenant.city ?? tenant.currentCity ?? tenant.propertyCity ?? cityKey);
                // 1) Validate candidate_property_found
                const candidate = await findCheaperCandidate(cityKey, tenantRent);
                if (!candidate)
                    continue;
                // 2) Validate notifications_enabled
                const notificationsEnabled = await isNotificationsEnabled(tenantUserId);
                if (!notificationsEnabled)
                    continue;
                // 3) Validate has_valid_token
                const tokenBundle = await (0, tokenService_1.getUserDeviceTokens)(tenantUserId);
                if (tokenBundle.tokens.length === 0)
                    continue;
                // 4) Reserve event only after all non-mutating validations pass
                eventId = `cheaper_property_${tenantId}_${dateBucket}`;
                const reserved = await (0, notificationService_1.reserveNotificationEvent)(eventId, {
                    type: "CHEAPER_PROPERTY_ALERT",
                    lifecycleState: "reserved",
                    tenantId,
                    tenantUserId,
                    city,
                    cityKey,
                    currentRent: tenantRent,
                    lowerRent: candidate.rent,
                    propertyId: candidate.propertyId,
                    validatedAt: firebase_1.FieldValue.serverTimestamp(),
                });
                if (!reserved)
                    continue;
                eventReserved = true;
                // 5) Enforce and consume rate-limit only after reservation success
                const withinRateLimit = await (0, rateLimitService_1.checkAndIncrementRateLimit)(tenantUserId, "CHEAPER_PROPERTY_ALERT");
                if (!withinRateLimit) {
                    await (0, notificationService_1.updateNotificationEventStatus)(eventId, "failed", {
                        lifecycleState: "failed",
                        failureReason: "rate_limit_blocked",
                    });
                    continue;
                }
                const actionRoute = `/tenant/city?city=${encodeURIComponent(city)}`;
                const payload = {
                    type: "CHEAPER_PROPERTY_ALERT",
                    title: "Cheaper Property Nearby",
                    body: `You pay Rs ${inr(tenantRent)}. Similar options from Rs ${inr(candidate.rent)} are available in ${city}.`,
                    data: {
                        type: "CHEAPER_PROPERTY_ALERT",
                        targetRole: "tenant",
                        tenantId,
                        city,
                        cityKey,
                        action: "view_map",
                        actionLabel: "View Map",
                        actionRoute,
                        propertyId: candidate.propertyId,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                };
                // 6) Send notification only for reserved events
                const dispatch = await (0, notificationService_1.sendMulticastWithRetry)(tokenBundle.tokens, payload);
                await (0, tokenService_1.cleanupInvalidTokens)(tokenBundle.tokenRefs, dispatch.invalidTokens);
                // 7) Mark event completed
                const wasSent = dispatch.sentCount > 0;
                await (0, notificationService_1.updateNotificationEventStatus)(eventId, wasSent ? "sent" : "failed", {
                    lifecycleState: wasSent ? "sent" : "failed",
                    sentCount: dispatch.sentCount,
                    invalidTokenCount: dispatch.invalidTokens.length,
                    transientFailures: dispatch.transientFailures,
                });
                await Promise.all([
                    firebase_1.db.collection("messages").doc(eventId).set({
                        type: "CHEAPER_PROPERTY_ALERT",
                        title: payload.title,
                        body: payload.body,
                        tenantId,
                        read: false,
                        severity: wasSent ? "info" : "warning",
                        city,
                        cityKey,
                        propertyId: candidate.propertyId,
                        actionRoute,
                        deliveryStatus: wasSent ? "sent" : "failed",
                        createdAt: firebase_1.FieldValue.serverTimestamp(),
                    }),
                    (0, notificationService_1.trackNotificationAnalytics)({
                        userId: tenantUserId,
                        type: "CHEAPER_PROPERTY_ALERT",
                        eventId,
                        sentCount: dispatch.sentCount,
                        invalidTokenCount: dispatch.invalidTokens.length,
                    }),
                ]);
                processed += 1;
                sentCount += dispatch.sentCount;
            }
            catch (tenantError) {
                (0, logger_1.logError)("sendTenantCheaperPropertyAlerts tenant iteration failed", {
                    tenantId: tenantDoc.id,
                    error: tenantError instanceof Error
                        ? tenantError.message
                        : String(tenantError),
                });
                if (eventReserved && eventId) {
                    await (0, notificationService_1.updateNotificationEventStatus)(eventId, "failed", {
                        lifecycleState: "failed",
                        failureReason: "tenant_iteration_error",
                        errorMessage: tenantError instanceof Error
                            ? tenantError.message
                            : String(tenantError),
                    });
                }
            }
        }
        (0, logger_1.logInfo)("sendTenantCheaperPropertyAlerts completed", {
            dateBucket,
            processed,
            sentCount,
        });
    }
    catch (error) {
        (0, logger_1.logError)("sendTenantCheaperPropertyAlerts failed", {
            dateBucket,
            error: error instanceof Error ? error.message : String(error),
        });
    }
});
//# sourceMappingURL=tenantCheaperPropertyAlertScheduler.js.map