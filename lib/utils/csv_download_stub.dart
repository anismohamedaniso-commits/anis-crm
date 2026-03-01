/// Cross-platform CSV download: stub for non-web platforms.
Future<bool> downloadCsvFile(String csvContent, String filename) async {
  // Not supported on non-web platforms via direct download
  return false;
}
