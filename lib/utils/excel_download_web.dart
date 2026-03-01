// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Downloads an Excel (.xlsx) file on web using Blob + AnchorElement.
Future<bool> downloadExcelFile(List<int> bytes, String filename) async {
  try {
    final blob = html.Blob([bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
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
