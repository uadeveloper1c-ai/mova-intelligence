class ParsedInvoice {
  final String vendorName;
  final String vendorCode; // ЄДРПОУ
  final double? amount;
  final String purpose;

  ParsedInvoice({
    required this.vendorName,
    required this.vendorCode,
    required this.amount,
    required this.purpose,
  });
}

class OcrParser {
  static ParsedInvoice parse(String text) {
    final t = text.replaceAll('\r', '\n');

    // подготовка строк
    final rawLines = t.split('\n');
    final lines = rawLines.map((e) => e.trim()).toList();
    final nonEmptyLines = lines.where((e) => e.isNotEmpty).toList();

    // -------- 1) ЄДРПОУ / ИНН --------
    String vendorCode = '';
    final codeRegex =
    RegExp(r'(ЄДРПОУ|ЕДРПОУ|ДРФО|ИНН|ІПН|ІПН\/ЄДРПОУ)[^\d]{0,30}(\d{8,12})');
    final codeMatch = codeRegex.firstMatch(t);
    if (codeMatch != null) vendorCode = codeMatch.group(2) ?? '';

    // -------- 2) Сума (максимально похожая на итоговую) --------
    double? amount;
    final amountRegex = RegExp(r'(\d[\d\s]{0,12}[.,]\d{2})');
    final matches = amountRegex.allMatches(t).toList();
    if (matches.isNotEmpty) {
      // эвристика: берём "самый длинный" (часто итог)
      matches.sort((a, b) =>
          (b.group(1)?.length ?? 0).compareTo(a.group(1)?.length ?? 0));
      final raw = matches.first.group(1)!;
      final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
      amount = double.tryParse(normalized);
    }

    // -------- утилиты --------
    String _cleanupLabelValue(String s) {
      // удаляем "Постачальник:", "Призначення:" и т.п.
      return s
          .replaceAll(RegExp(r'^[\s:—-]+'), '')
          .replaceAll(RegExp(r'[\s]+'), ' ')
          .trim();
    }

    String _takeAfterLabel(String line, RegExp label) {
      final m = label.firstMatch(line);
      if (m == null) return '';
      final after = line.substring(m.end);
      return _cleanupLabelValue(after);
    }

    bool _looksLikeCompanyName(String lineUpper) {
      return lineUpper.contains('ТОВ') ||
          lineUpper.contains('ФОП') ||
          lineUpper.contains('FOP') ||
          lineUpper.contains('LLC') ||
          lineUpper.contains('LTD') ||
          lineUpper.contains('ПП') ||
          lineUpper.contains('ПРИВАТНЕ ПІДПРИЄМСТВО');
    }

    // -------- 3) Поставщик (сначала по метке, потом fallback) --------
    String vendorName = '';

    // 3.1 Поиск по метке "Постачальник/Поставщик/Продавець/Виконавець"
    final vendorLabelRegex = RegExp(
      r'\b(ПОСТАЧАЛЬНИК|ПОСТАВЩИК|ПРОДАВЕЦЬ|ПРОДАВЕЦ|ВИКОНАВЕЦЬ|ИСПОЛНИТЕЛЬ|КОНТРАГЕНТ)\b\s*[:\-—]?\s*',
      caseSensitive: false,
    );

    for (final line in nonEmptyLines) {
      final v = _takeAfterLabel(line, vendorLabelRegex);
      if (v.isNotEmpty && v.length >= 3) {
        vendorName = v;
        break;
      }
    }

    // 3.2 Если метки нет — fallback: первая строка с ТОВ/ФОП/LLC и т.д.
    if (vendorName.isEmpty) {
      for (final line in nonEmptyLines.take(30)) {
        final upper = line.toUpperCase();
        if (_looksLikeCompanyName(upper)) {
          vendorName = line;
          break;
        }
      }
    }

    // 3.3 Ещё один fallback: если нашли ЄДРПОУ, пробуем взять строку рядом
    if (vendorName.isEmpty && vendorCode.isNotEmpty) {
      for (int i = 0; i < nonEmptyLines.length; i++) {
        if (nonEmptyLines[i].contains(vendorCode)) {
          // часто название в той же строке ДО кода
          final before = nonEmptyLines[i].split(vendorCode).first.trim();
          if (before.length >= 3) {
            vendorName = before;
          } else if (i > 0) {
            // или в предыдущей строке
            vendorName = nonEmptyLines[i - 1];
          }
          break;
        }
      }
    }

    // -------- 4) Назначение платежа --------
    String purpose = '';

    // 4.1 Поиск по меткам (и берем значение на той же строке)
    final purposeLabelRegex = RegExp(
      r'\b(ПРИЗНАЧЕННЯ(\s+ПЛАТЕЖУ)?|НАЗНАЧЕНИЕ(\s+ПЛАТЕЖА)?|ПРИЗНАЧ\.)\b\s*[:\-—]?\s*',
      caseSensitive: false,
    );

    for (int i = 0; i < nonEmptyLines.length; i++) {
      final line = nonEmptyLines[i];

      final inline = _takeAfterLabel(line, purposeLabelRegex);
      if (inline.isNotEmpty && inline.length >= 5) {
        purpose = inline;
        break;
      }

      // 4.2 Если строка — только "Призначення:" (без текста), берём следующую 1-2 строки
      if (purposeLabelRegex.hasMatch(line) && inline.isEmpty) {
        final next1 = (i + 1 < nonEmptyLines.length) ? nonEmptyLines[i + 1] : '';
        final next2 = (i + 2 < nonEmptyLines.length) ? nonEmptyLines[i + 2] : '';
        final candidate = [next1, next2]
            .where((s) => s.isNotEmpty)
            .take(2)
            .join(' ');
        if (candidate.trim().length >= 5) {
          purpose = candidate.trim();
          break;
        }
      }
    }

    // 4.3 Fallback: ищем "Оплата за ..." / "Плата за ..." / "Payment for ..."
    if (purpose.isEmpty) {
      final payForRegex = RegExp(
        r'\b(ОПЛАТА\s+ЗА|ПЛАТА\s+ЗА|PAYMENT\s+FOR)\b[^\n]{0,200}',
        caseSensitive: false,
      );
      final pm = payForRegex.firstMatch(t);
      if (pm != null) {
        purpose = pm.group(0)?.trim() ?? '';
      }
    }

    // финальная косметика
    purpose = purpose.replaceAll(RegExp(r'\s+'), ' ').trim();
    vendorName = vendorName.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedInvoice(
      vendorName: vendorName,
      vendorCode: vendorCode,
      amount: amount,
      purpose: purpose,
    );
  }
}
