import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String fullText;
  OcrResult(this.fullText);
}

class MlkitOcrService {
  final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognize(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(input);
    return OcrResult(recognized.text);
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
