"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hasValidCityKey = exports.normalizeCityKey = void 0;
const asString = (value) => String(value ?? "").trim();
const normalizeCityKey = (value) => asString(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
exports.normalizeCityKey = normalizeCityKey;
const hasValidCityKey = (value) => (0, exports.normalizeCityKey)(value).length > 0;
exports.hasValidCityKey = hasValidCityKey;
//# sourceMappingURL=cityKey.js.map