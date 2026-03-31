class TenantTrustScore {
  static const int minScore = 0;
  static const int maxScore = 100;
  static const int defaultScore = 50;

  static int clamp(int score) {
    if (score < minScore) return minScore;
    if (score > maxScore) return maxScore;
    return score;
  }

  static TenantTrustBadge badgeFor(int score) {
    final normalizedScore = clamp(score);
    if (normalizedScore >= 90) {
      return TenantTrustBadge.trustworthyPro;
    }
    if (normalizedScore >= 70) {
      return TenantTrustBadge.reliableTenant;
    }
    if (normalizedScore >= 50) {
      return TenantTrustBadge.averageTenant;
    }
    if (normalizedScore >= 20) {
      return TenantTrustBadge.riskyTenant;
    }
    return TenantTrustBadge.untrustworthy;
  }

  static int paymentDelta({
    required DateTime paymentDate,
    required DateTime dueDate,
    required String status,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus == 'missed') {
      return -25;
    }

    final lateDays = paymentDate
        .difference(DateTime(dueDate.year, dueDate.month, dueDate.day))
        .inDays;

    if (lateDays < 0) {
      return 7;
    }
    if (lateDays == 0) {
      return 5;
    }
    if (lateDays <= 3) {
      return -5;
    }
    if (lateDays <= 10) {
      return -10;
    }
    return -15;
  }

  static int consecutiveBonus({
    required int consecutiveOnTimeMonths,
    required bool perfectRecord,
  }) {
    if (perfectRecord &&
        consecutiveOnTimeMonths > 0 &&
        consecutiveOnTimeMonths % 12 == 0) {
      return 20;
    }
    if (consecutiveOnTimeMonths > 0 && consecutiveOnTimeMonths % 6 == 0) {
      return 10;
    }
    return 0;
  }

  static int penaltyForIncident(TenantTrustIncident incident) {
    switch (incident) {
      case TenantTrustIncident.propertyDamageComplaint:
        return -10;
      case TenantTrustIncident.ownerDisputeReported:
        return -15;
      case TenantTrustIncident.eviction:
        return -40;
    }
  }

  static int rewardForRecoveryMonths(int onTimeMonths) {
    if (onTimeMonths >= 12) return 20;
    if (onTimeMonths >= 6) return 10;
    if (onTimeMonths >= 3) return 5;
    return 0;
  }
}

enum TenantTrustIncident {
  propertyDamageComplaint,
  ownerDisputeReported,
  eviction,
}

enum TenantTrustBadge {
  trustworthyPro,
  reliableTenant,
  averageTenant,
  riskyTenant,
  untrustworthy,
}

extension TenantTrustBadgeMeta on TenantTrustBadge {
  String get label {
    switch (this) {
      case TenantTrustBadge.trustworthyPro:
        return 'Trustworthy Pro';
      case TenantTrustBadge.reliableTenant:
        return 'Reliable Tenant';
      case TenantTrustBadge.averageTenant:
        return 'Average Tenant';
      case TenantTrustBadge.riskyTenant:
        return 'Risky Tenant';
      case TenantTrustBadge.untrustworthy:
        return 'Untrustworthy';
    }
  }
}
