import 'package:hive/hive.dart';
import '../../invoices/domain/invoice.dart';

// твоя модель (можно оставить прежнюю в domain/; продублирую тут для наглядности)

// РУЧНОЙ TypeAdapter без генераторов
class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override
  final int typeId = 1; // уникальный ID типа в приложении

  @override
  Invoice read(BinaryReader reader) {
    final fieldsCount = reader.readByte();
    String number = '';
    DateTime date = DateTime.now();
    String supplier = '';
    double amount = 0;
    String purpose = '';

    for (int i = 0; i < fieldsCount; i++) {
      final key = reader.readByte();
      switch (key) {
        case 0:
          number = reader.readString();
          break;
        case 1:
          date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 2:
          supplier = reader.readString();
          break;
        case 3:
          amount = reader.readDouble();
          break;
        case 4:
          purpose = reader.readString();
          break;
      }
    }
    return Invoice(
      number: number,
      date: date,
      supplier: supplier,
      amount: amount,
      purpose: purpose,
    );
  }

  @override
  void write(BinaryWriter writer, Invoice obj) {
    writer
      ..writeByte(5)       // сколько полей пишем
      ..writeByte(0)..writeString(obj.number)
      ..writeByte(1)..writeInt(obj.date.millisecondsSinceEpoch)
      ..writeByte(2)..writeString(obj.supplier)
      ..writeByte(3)..writeDouble(obj.amount)
      ..writeByte(4)..writeString(obj.purpose);
  }
}
