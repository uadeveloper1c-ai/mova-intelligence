import 'dart:io';
import 'invoice.dart';

abstract class IOcrService {
  Future<Invoice> recognize(File file);
}
