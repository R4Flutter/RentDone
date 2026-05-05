import * as logger from "firebase-functions/logger";

/**
 * Environment-aware structured logging utility.
 * Ensures no sensitive data is leaked and logs are formatted for Google Cloud Logging.
 */
export class AppLogger {
  static debug(message: string, data?: any) {
    logger.debug(message, this.sanitize(data));
  }

  static info(message: string, data?: any) {
    logger.info(message, this.sanitize(data));
  }

  static warn(message: string, data?: any) {
    logger.warn(message, this.sanitize(data));
  }

  static error(message: string, error?: any, context?: any) {
    logger.error(message, {
      ...this.sanitize(context),
      error: error instanceof Error ? {
        message: error.message,
        stack: error.stack,
      } : error,
    });
  }

  /**
   * Remove sensitive fields like tokens, secrets, or full payment payloads from logs.
   * Uses a safe recursive approach to avoid JSON.parse(JSON.stringify) risks.
   */
  public static sanitize(data: any, seen = new WeakSet()): any {
    if (data === null || data === undefined) return undefined;
    if (typeof data !== "object") return data;
    if (data instanceof Date) return data.toISOString();

    // Prevent circular reference crashes
    if (seen.has(data)) return "[Circular]";
    seen.add(data);

    const sensitiveKeys = ["token", "fcmtoken", "secret", "password", "key_secret", "signature"];

    if (Array.isArray(data)) {
      return data.map(item => this.sanitize(item, seen));
    }

    const sanitized: any = {};
    for (const key in data) {
      if (Object.prototype.hasOwnProperty.call(data, key)) {
        const lowerKey = key.toLowerCase();
        if (sensitiveKeys.some(s => lowerKey.includes(s))) {
          sanitized[key] = "[REDACTED]";
        } else {
          sanitized[key] = this.sanitize(data[key], seen);
        }
      }
    }
    return sanitized;
  }
}
