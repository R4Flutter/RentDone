import { logger } from "firebase-functions";

export const logInfo = (message: string, data: Record<string, unknown> = {}): void => {
  logger.info(message, data);
};

export const logWarn = (message: string, data: Record<string, unknown> = {}): void => {
  logger.warn(message, data);
};

export const logError = (message: string, data: Record<string, unknown> = {}): void => {
  logger.error(message, data);
};
