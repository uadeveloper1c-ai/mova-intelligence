import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../invoices/domain/invoice.dart';

class RecognizePage extends StatefulWidget {
  const RecognizePage({super.key});

  @override
  State<RecognizePage> createState() => _RecognizePageState();
}

class _RecognizePageState extends State<RecognizePage> {
  final _numberCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // yyyy-MM-dd
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  File? _imageFile;
  bool _isProcessing = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _dateCtrl.dispose();
    _supplierCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _imageFile = File(x.path));
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(source: ImageSource.camera);
    if (x != null) setState(() => _imageFile = File(x.path));
  }

  Future<String> _extractTextFromImage(File file) async {
    final input = InputImage.fromFile(file);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      recognizer.close();
    }
  }

  // ---------- ПАРСИНГ ----------

  static const _uaMonths = {
    'січня': '01',
    'лютого': '02',
    'березня': '03',
    'квітня': '04',
    'травня': '05',
    'червня': '06',
    'липня': '07',
    'серпня': '08',
    'вересня': '09',
    'жовтня': '10',
    'листопада': '11',
    'грудня': '12',
  };

  static const _ruMonths = {
    'января': '01',
    'февраля': '02',
    'марта': '03',
    'апреля': '04',
    'мая': '05',
    'июня': '06',
    'июля': '07',
    'августа': '08',
    'сентября': '09',
    'октября': '10',
    'ноября': '11',
    'декабря': '12',
  };

  String? _parseHeadingDate(String text) {
    // Пример: "Видаткова накладна № 836 від 17 жовтня 2025 р."
    final re = RegExp(
      r'видаткова\s+накладна.*?(?:№|N)?\s*([^\s,]*)?.*?від\s+(\d{1,2})\s+([А-Яа-яІіЇїЄє]+)\s+(\d{4})',
      caseSensitive: false,
      dotAll: true,
    );
    final m = re.firstMatch(text);
    if (m == null) return null;

    final dd = m.group(2)!;
    final mmWord = m.group(3)!.toLowerCase();
    final yyyy = m.group(4)!;

    String? mm = _uaMonths[mmWord] ?? _ruMonths[mmWord];
    if (mm == null) return null;

    final day = dd.padLeft(2, '0');
    return '$yyyy-$mm-$day';
  }

  String? _parseHeadingNumber(String text) {
    // из той же строки заголовка достаём №
    final re = RegExp(
      r'видаткова\s+накладна\s*(?:№|N)?\s*([A-Za-zА-Яа-я0-9\-\/]+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    return m?.group(1)?.trim();
  }

  Invoice _parseAndFill(String rawText) {
    // 1) нормализация
    final text = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .trim();

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lowerLines = lines.map((l) => l.toLowerCase()).toList();

    // -------- НОМЕР (пробуем сначала из заголовка) --------
    String? number = _parseHeadingNumber(text);

    // fallback: любые упоминания №...
    if (number == null) {
      final reAny = RegExp(r'(?:№|N)\s*([A-Za-zА-Яа-я0-9\-\/]{1,})');
      final m = reAny.firstMatch(text);
      number = m?.group(1)?.trim();
    }
    if (number != null) _numberCtrl.text = number;

    // -------- ДАТА (приоритет — из заголовка) --------
    String? dateStr = _parseHeadingDate(text);

    if (dateStr == null) {
      // fallback: любые даты dd.mm.yyyy / yyyy-mm-dd / dd/mm/yy
      final dateRe = RegExp(
        r'(\d{4}[-\.\/]\d{1,2}[-\.\/]\d{1,2}|\d{1,2}[-\.\/]\d{1,2}[-\.\/]\d{2,4})',
      );
      final m = dateRe.firstMatch(text);
      if (m != null) {
        var d = m
            .group(1)!
            .replaceAll(' ', '')
            .replaceAll('\\', '-')
            .replaceAll('.', '-')
            .replaceAll('/', '-');
        final parts = d.split('-');
        if (parts[0].length == 4) {
          dateStr =
          '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
        } else {
          final y = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
          dateStr =
          '$y-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }
    }
    if (dateStr != null) _dateCtrl.text = dateStr;

    // -------- СУММА --------
    String? amountStr;
    final amountPatterns = <RegExp>[
      RegExp(
        r'(всього|разом|до\s*сплати|всего|итог[о]?|к\s*оплате|total)\D{0,25}(\d+[ \d]*[,.\s]\d{2})',
        caseSensitive: false,
      ),
    ];
    for (final re in amountPatterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        amountStr = m.group(2);
        break;
      }
    }
    if (amountStr == null) {
      // берём самое большое денежное число
      final moneyRe = RegExp(r'(\d[\d ]{0,12}[,.\s]\d{2})');
      final all = moneyRe.allMatches(text).map((m) => m.group(1)!).toList();
      double best = -1;
      String? bestRaw;
      for (final raw in all) {
        final v =
        double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.'));
        if (v != null && v > best) {
          best = v;
          bestRaw = raw;
        }
      }
      amountStr = bestRaw;
    }
    if (amountStr != null) {
      _amountCtrl.text = amountStr
          .replaceAll('\u00A0', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .replaceAll('грн', '')
          .replaceAll('uah', '')
          .trim();
    }

    // -------- ПОСТАВЩИК --------
    String? supplier;

    // 1) явные метки
    final supplierPatterns = <RegExp>[
      RegExp(r'(постачальник|поставщик)[:\s\-]+(.{3,100})',
          caseSensitive: false),
    ];
    for (final re in supplierPatterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        supplier = m.group(2)?.trim();
        break;
      }
    }

    // 2) ФОП / ФОП Імʼя / Фізична особа-підприємець / ТОВ / ПП / LLC
    if (supplier == null) {
      for (final line in lines.take(12)) {
        if (RegExp(
          r'^(фоп|фізична особа[- ]підприємець|фізична особа підприємець|тов|пп|ооо|llc|ltd)\b',
          caseSensitive: false,
        ).hasMatch(line)) {
          supplier = line.trim();
          break;
        }
      }
    }

    // 3) если всё ещё нет — возьмём ближайшую строку после слова "Постачальник"/"Поставщик"
    if (supplier == null) {
      for (var i = 0; i < lowerLines.length - 1; i++) {
        final l = lowerLines[i];
        if (l.contains('постачальник') || l.contains('поставщик')) {
          supplier = lines[i + 1];
          break;
        }
      }
    }

    if (supplier != null) _supplierCtrl.text = supplier;

    // -------- НАЗНАЧЕНИЕ --------
    String? purpose;
    // явная метка
    final purposePatterns = <RegExp>[
      RegExp(r'(призначення платежу|назначение платежа|purpose)[:\s\-]+(.{5,160})',
          caseSensitive: false),
    ];
    for (final re in purposePatterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        purpose = m.group(2)?.trim();
        break;
      }
    }
    // эвристика
    if (purpose == null && number != null) {
      purpose = 'Оплата згідно видаткової накладної № $number';
    }
    purpose ??= 'Оплата за товар';
    _purposeCtrl.text = purpose;

    // --- собрать Invoice и вернуть ---
    final date = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

    return Invoice(
      number: _numberCtrl.text.trim(),
      date: date,
      supplier: _supplierCtrl.text.trim(),
      amount: amount,
      purpose: _purposeCtrl.text.trim(),
    );
  }

  // ---------- ДЕЙСТВИЕ "РАСПОЗНАТЬ И ВЕРНУТЬ" ----------

  Future<void> _recognizeAndReturn() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите фото или сделайте снимок')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final text = await _extractTextFromImage(_imageFile!);
      final invoice = _parseAndFill(text);

      if (!mounted) return;
      // Возвращаемся на экран "новой заявки" с готовыми данными
      Navigator.pop(context, invoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка распознавания: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Розпізнавання накладної'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Превью изображения
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    height: 200,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.contain, width: double.infinity)
                        : const Text('Фото не выбрано'),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Галерея'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Камера'),
                    ),
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _recognizeAndReturn,
                      icon: _isProcessing
                          ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.text_snippet_outlined),
                      label: Text(_isProcessing ? 'Обробка...' : 'Розпізнати й заповнити'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Показ авто-заполненных полей (для визуальной проверки перед возвратом, если нужно)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _numberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Номер',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Дата (yyyy-MM-dd)',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplierCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Постачальник / Поставщик',
                          prefixIcon: Icon(Icons.store_mall_directory_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Сума',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purposeCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Призначення / Назначение',
                          prefixIcon: Icon(Icons.text_fields_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
