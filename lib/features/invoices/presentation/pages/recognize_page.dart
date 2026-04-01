import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mlkit_ocr_service.dart';
import '../../domain/ocr_parser.dart';
import 'ocr_preview_page.dart'; //

class RecognizePage extends StatefulWidget {
  const RecognizePage({super.key});

  @override
  State<RecognizePage> createState() => _RecognizePageState();
}

class _RecognizePageState extends State<RecognizePage> {
  final _picker = ImagePicker();
  final _ocr = MlkitOcrService();

  bool _busy = false;
  String? _error;

  Future<void> _pickAndRecognize(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;

      final file = File(xfile.path);
      final result = await _ocr.recognize(file);

      final parsed = OcrParser.parse(result.fullText);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OcrPreviewPage(
            fullText: result.fullText,
            vendorName: parsed.vendorName,
            vendorCode: parsed.vendorCode,
            amount: parsed.amount,
            purpose: parsed.purpose,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Не вдалося розпізнати документ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Розпізнавання документа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _busy ? null : () => _pickAndRecognize(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Зняти фото'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickAndRecognize(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Вибрати з галереї'),
            ),
          ],
        ),
      ),
    );
  }
}
