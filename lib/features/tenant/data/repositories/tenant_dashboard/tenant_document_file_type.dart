String resolveTenantDocumentFileType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'pdf';
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp')) {
    return 'image';
  }
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi')) {
    return 'video';
  }
  return 'other';
}
