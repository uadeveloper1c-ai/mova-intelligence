class BottlingData {
  const BottlingData({required this.passports});

  final List<BottlingPassport> passports;

  factory BottlingData.fromJson(Map<String, dynamic> json) => BottlingData(
        passports: (json['passports'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => BottlingPassport.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
      );
}

class BottlingPassport {
  const BottlingPassport({
    required this.id,
    required this.batchNumber,
    required this.productName,
    required this.cktName,
    required this.status,
    required this.initialVolume,
    required this.bottledVolume,
    required this.remainingVolume,
    required this.series,
    required this.specifications,
    required this.operations,
  });

  final String id;
  final String batchNumber;
  final String productName;
  final String cktName;
  final String status;
  final double initialVolume;
  final double bottledVolume;
  final double remainingVolume;
  final List<BottlingSeries> series;
  final List<BottlingSpecification> specifications;
  final List<BottlingOperation> operations;

  factory BottlingPassport.fromJson(Map<String, dynamic> json) =>
      BottlingPassport(
        id: json['id']?.toString() ?? '',
        batchNumber: json['batchNumber']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        cktName: json['cktName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        initialVolume: _bottlingDouble(json['initialVolume']),
        bottledVolume: _bottlingDouble(json['bottledVolume']),
        remainingVolume: _bottlingDouble(json['remainingVolume']),
        series:
            _bottlingRows(json['series']).map(BottlingSeries.fromJson).toList(),
        specifications: _bottlingRows(json['specifications'])
            .map(BottlingSpecification.fromJson)
            .toList(),
        operations: _bottlingRows(json['operations'])
            .map(BottlingOperation.fromJson)
            .toList(),
      );
}

class BottlingSeries {
  const BottlingSeries({
    required this.uid,
    required this.name,
    required this.remainingVolume,
  });

  final String uid;
  final String name;
  final double remainingVolume;

  factory BottlingSeries.fromJson(Map<String, dynamic> json) => BottlingSeries(
        uid: json['uid']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        remainingVolume: _bottlingDouble(json['remainingVolume']),
      );
}

class BottlingSpecification {
  const BottlingSpecification({
    required this.uid,
    required this.name,
    required this.outputUid,
    required this.outputName,
    required this.characteristicUid,
    required this.characteristicName,
    required this.unitUid,
    required this.unitName,
    required this.volumePerUnit,
  });

  final String uid;
  final String name;
  final String outputUid;
  final String outputName;
  final String characteristicUid;
  final String characteristicName;
  final String unitUid;
  final String unitName;
  final double volumePerUnit;

  String get displayName => outputName.isEmpty ? name : '$outputName — $name';

  factory BottlingSpecification.fromJson(Map<String, dynamic> json) =>
      BottlingSpecification(
        uid: json['uid']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        outputUid: json['outputUid']?.toString() ?? '',
        outputName: json['outputName']?.toString() ?? '',
        characteristicUid: json['characteristicUid']?.toString() ?? '',
        characteristicName: json['characteristicName']?.toString() ?? '',
        unitUid: json['unitUid']?.toString() ?? '',
        unitName: json['unitName']?.toString() ?? '',
        volumePerUnit: _bottlingDouble(json['volumePerUnit']),
      );
}

class BottlingOperation {
  const BottlingOperation({
    required this.id,
    required this.date,
    required this.inputVolume,
    required this.documentNumber,
    required this.comment,
    required this.items,
  });

  final String id;
  final DateTime? date;
  final double inputVolume;
  final String documentNumber;
  final String comment;
  final List<BottlingOutput> items;

  factory BottlingOperation.fromJson(Map<String, dynamic> json) =>
      BottlingOperation(
        id: json['id']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
        inputVolume: _bottlingDouble(json['inputVolume']),
        documentNumber: json['documentNumber']?.toString() ?? '',
        comment: json['comment']?.toString() ?? '',
        items:
            _bottlingRows(json['items']).map(BottlingOutput.fromJson).toList(),
      );
}

class BottlingOutput {
  const BottlingOutput({
    required this.purpose,
    required this.itemName,
    required this.quantity,
    required this.unitName,
    required this.volumeLiters,
  });

  final String purpose;
  final String itemName;
  final double quantity;
  final String unitName;
  final double volumeLiters;

  factory BottlingOutput.fromJson(Map<String, dynamic> json) => BottlingOutput(
        purpose: json['purpose']?.toString() ?? '',
        itemName: json['itemName']?.toString() ?? '',
        quantity: _bottlingDouble(json['quantity']),
        unitName: json['unitName']?.toString() ?? '',
        volumeLiters: _bottlingDouble(json['volumeLiters']),
      );
}

class BottlingLineDraft {
  const BottlingLineDraft({
    required this.purpose,
    required this.specificationUid,
    required this.outputUid,
    required this.quantity,
  });

  final String purpose;
  final String specificationUid;
  final String outputUid;
  final double quantity;

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'specificationUid': specificationUid,
        'outputUid': outputUid,
        'quantity': quantity,
      };
}

List<Map<String, dynamic>> _bottlingRows(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

double _bottlingDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
