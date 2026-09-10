class ColdDepartmentData {
  const ColdDepartmentData({
    required this.passports,
    required this.items,
  });

  final List<ColdDepartmentPassport> passports;
  final List<ColdDepartmentStockItem> items;

  factory ColdDepartmentData.fromJson(Map<String, dynamic> json) =>
      ColdDepartmentData(
        passports: (json['passports'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => ColdDepartmentPassport.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => ColdDepartmentStockItem.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
      );
}

class ColdDepartmentPassport {
  const ColdDepartmentPassport({
    required this.id,
    required this.batchNumber,
    required this.productName,
    required this.currentProductName,
    required this.cktName,
    required this.status,
    required this.actualVolume,
    required this.additions,
  });

  final String id;
  final String batchNumber;
  final String productName;
  final String currentProductName;
  final String cktName;
  final String status;
  final double actualVolume;
  final List<ColdDepartmentAddition> additions;

  factory ColdDepartmentPassport.fromJson(Map<String, dynamic> json) =>
      ColdDepartmentPassport(
        id: json['id']?.toString() ?? '',
        batchNumber: json['batchNumber']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        currentProductName: json['currentProductName']?.toString() ?? '',
        cktName: json['cktName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        actualVolume: _coldDouble(json['actualVolume']),
        additions: (json['additions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => ColdDepartmentAddition.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
      );
}

class ColdDepartmentAddition {
  const ColdDepartmentAddition({
    required this.itemName,
    required this.beforeName,
    required this.afterName,
    required this.quantity,
    required this.date,
    this.documentNumber = '',
    this.specificationName = '',
    this.comment = '',
  });

  final String itemName;
  final String beforeName;
  final String afterName;
  final double quantity;
  final DateTime? date;
  final String documentNumber;
  final String specificationName;
  final String comment;

  factory ColdDepartmentAddition.fromJson(Map<String, dynamic> json) =>
      ColdDepartmentAddition(
        itemName: json['itemName']?.toString() ?? '',
        beforeName: json['beforeName']?.toString() ?? '',
        afterName: json['afterName']?.toString() ?? '',
        quantity: _coldDouble(json['quantity']),
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
        documentNumber: json['documentNumber']?.toString() ?? '',
        specificationName: json['specificationName']?.toString() ?? '',
        comment: json['comment']?.toString() ?? '',
      );
}

class ColdDepartmentAdditionDraft {
  const ColdDepartmentAdditionDraft({
    required this.itemUid,
    required this.characteristicUid,
    required this.quantity,
  });

  final String itemUid;
  final String characteristicUid;
  final double quantity;

  Map<String, dynamic> toJson() => {
        'itemUid': itemUid,
        'characteristicUid': characteristicUid,
        'quantity': quantity,
      };
}

class ColdDepartmentStockItem {
  const ColdDepartmentStockItem({
    required this.uid,
    required this.name,
    required this.balance,
    this.characteristicUid = '',
    this.characteristicName = '',
    this.unitName = '',
  });

  final String uid;
  final String name;
  final double balance;
  final String characteristicUid;
  final String characteristicName;
  final String unitName;

  factory ColdDepartmentStockItem.fromJson(Map<String, dynamic> json) =>
      ColdDepartmentStockItem(
        uid: json['uid']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        balance: _coldDouble(json['balance']),
        characteristicUid: json['characteristicUid']?.toString() ?? '',
        characteristicName: json['characteristicName']?.toString() ?? '',
        unitName: json['unitName']?.toString() ?? '',
      );
}

double _coldDouble(dynamic value) =>
    double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
