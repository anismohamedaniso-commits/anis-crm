import 'package:anis_crm/utils/simple_file_picker.dart';

class StubSimpleFilePicker implements SimpleFilePicker {
  @override
  Future<SimplePickedFile?> pick({List<String>? allowedExtensions}) async => null;
}

SimpleFilePicker getSimpleFilePicker() => StubSimpleFilePicker();
