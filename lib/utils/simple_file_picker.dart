import 'dart:typed_data';

import 'package:anis_crm/utils/simple_file_picker_stub.dart'
    if (dart.library.html) 'package:anis_crm/utils/simple_file_picker_web.dart'
    if (dart.library.io) 'package:anis_crm/utils/simple_file_picker_io.dart' as impl;

/// Picked file result with name and bytes.
class SimplePickedFile {
  final String name;
  final Uint8List bytes;
  const SimplePickedFile(this.name, this.bytes);
}

/// Cross-platform simple file picker abstraction.
abstract class SimpleFilePicker {
  Future<SimplePickedFile?> pick({List<String>? allowedExtensions});
}

/// Platform-specific factory implemented in conditional files.
SimpleFilePicker getSimpleFilePicker() => impl.getSimpleFilePicker();
