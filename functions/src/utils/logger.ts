import { logger } from "firebase-functions";
import { AppLogger } from "../shared/logger";

export const logInfo = (message: string, data: Record<string, unknown> = {}): void => {
  logger.info(message, AppLogger.sanitize(data));
};

export const logWarn = (message: string, data: Record<string, unknown> = {}): void => {
  logger.warn(message, AppLogger.sanitize(data));
};

export const logError = (message: string, data: Record<string, unknown> = {}): void => {
  logger.error(message, AppLogger.sanitize(data));
};
