// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Cross-platform CSV download: web implementation using Blob + AnchorElement.
Future<bool> downloadCsvFile(String csvContent, String filename) async {
  try {
    final blob = html.Blob([csvContent], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}
