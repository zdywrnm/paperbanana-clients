"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildReferenceImage = buildReferenceImage;
exports.normalizeReferenceFileMimeType = normalizeReferenceFileMimeType;
exports.mimeTypeFromPath = mimeTypeFromPath;
exports.filenameFromPath = filenameFromPath;
exports.sanitizeLocalFilename = sanitizeLocalFilename;
exports.formatBytes = formatBytes;
const constants_1 = require("./constants");
const media_1 = require("./media");
function buildReferenceImage(input) {
    const canPreview = input.mimeType !== 'image/svg+xml';
    return {
        ...input,
        sizeText: formatBytes(input.size),
        canPreview,
        formatText: canPreview ? '图片' : 'SVG',
    };
}
function normalizeReferenceFileMimeType(mimeType, filename = '') {
    const normalized = String(mimeType || '').toLowerCase().split(';', 1)[0].trim();
    if (normalized === 'image/jpg')
        return 'image/jpeg';
    if (constants_1.REFERENCE_IMAGE_LIMITS.mimeTypes.includes(normalized))
        return normalized;
    return mimeTypeFromPath(filename);
}
function mimeTypeFromPath(path) {
    const lower = path.split('?')[0].toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
        return 'image/jpeg';
    if (lower.endsWith('.webp'))
        return 'image/webp';
    if (lower.endsWith('.png'))
        return 'image/png';
    if (lower.endsWith('.svg'))
        return 'image/svg+xml';
    return 'image/jpeg';
}
function filenameFromPath(path, index, mimeType) {
    const cleanPath = path.split('?')[0];
    const rawName = cleanPath.split('/').pop() || '';
    if (rawName.includes('.'))
        return rawName;
    return `reference-${index}.${(0, media_1.imageExtension)(mimeType)}`;
}
function sanitizeLocalFilename(rawName, path, index, mimeType) {
    const nameParts = rawName.split(/[\\/]/);
    const cleanName = (nameParts[nameParts.length - 1] || '').trim();
    if (cleanName) {
        return cleanName.includes('.') ? cleanName : `${cleanName}.${(0, media_1.imageExtension)(mimeType)}`;
    }
    return filenameFromPath(path, index, mimeType);
}
function formatBytes(size) {
    if (size >= 1024 * 1024)
        return `${(size / 1024 / 1024).toFixed(1)}MB`;
    if (size >= 1024)
        return `${Math.max(1, Math.round(size / 1024))}KB`;
    return `${size}B`;
}
