const asString = (value: unknown): string => String(value ?? "").trim();

export const normalizeCityKey = (value: unknown): string =>
  asString(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

export const hasValidCityKey = (value: unknown): boolean =>
  normalizeCityKey(value).length > 0;