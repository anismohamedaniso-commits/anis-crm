import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:anis_crm/utils/simple_file_picker.dart';

class WebSimpleFilePicker implements SimpleFilePicker {
  @override
  Future<SimplePickedFile?> pick({List<String>? allowedExtensions}) async {
    final completer = Completer<SimplePickedFile?>();
    try {
      final input = html.FileUploadInputElement();
      input.accept = allowedExtensions == null || allowedExtensions.isEmpty ? '' : allowedExtensions.map((e) => e.startsWith('.') ? e : '.${e.toLowerCase()}').join(',');
      input.click();
      input.onChange.listen((event) async {
        final files = input.files;
        if (files == null || files.isEmpty) {
          completer.complete(null);
          return;
        }
        final file = files.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) {
          final bytes = Uint8List.fromList((reader.result as List).cast<int>());
          completer.complete(SimplePickedFile(file.name, bytes));
        });
        reader.onError.listen((e) => completer.completeError(e!));
      });
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }
}

SimpleFilePicker getSimpleFilePicker() => WebSimpleFilePicker();
