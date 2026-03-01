import 'package:anis_crm/utils/simple_file_picker.dart';
import 'package:file_picker/file_picker.dart';

class IoSimpleFilePicker implements SimpleFilePicker {
  @override
  Future<SimplePickedFile?> pick({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: allowedExtensions);
    if (result == null) return null;
    final f = result.files.single;
    final bytes = f.bytes; // For mobile/desktop, bytes may be null if "withData" was false
    if (bytes == null) {
      // Best effort: return null rather than throwing; callers can handle gracefully.
      return null;
    }
    return SimplePickedFile(f.name, bytes);
  }
}

SimpleFilePicker getSimpleFilePicker() => IoSimpleFilePicker();
