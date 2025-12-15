import 'dart:async';
import 'dart:io';
import '../domain/i_ocr_service.dart';
import '../domain/invoice.dart';

class MockOcrService implements IOcrService {
  @override
  Future<Invoice> recognize(File file) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final name = file.path.split(Platform.pathSeparator).last;
    return Invoice(
      number: name.hashCode.abs().toString().substring(0, 6),
      date: DateTime.now(),
      supplier: 'ТОВ Ромашка',
      amount: 15200.00,
      purpose: 'Оплата за пиво (demo)',
    );
  }
}
