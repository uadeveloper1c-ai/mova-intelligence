import 'dart:convert';

import '../../api/api_client.dart';

enum ProductionRequestType {
  rawMaterial,
  bottling,
  finishedGoods,
  returnToStock
}

extension ProductionRequestTypeUi on ProductionRequestType {
  String get code => switch (this) {
        ProductionRequestType.rawMaterial => 'RawMaterial',
        ProductionRequestType.bottling => 'Bottling',
        ProductionRequestType.finishedGoods => 'FinishedGoods',
        ProductionRequestType.returnToStock => 'ReturnToStock',
      };

  String get title => switch (this) {
        ProductionRequestType.rawMaterial => 'Сировина',
        ProductionRequestType.bottling => 'Розлив',
        ProductionRequestType.finishedGoods => 'Готова продукція',
        ProductionRequestType.returnToStock => 'Повернення',
      };
}

class ProductionRequest {
  const ProductionRequest({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
    this.subtitle = '',
  });

  final String id;
  final ProductionRequestType type;
  final String title;
  final String subtitle;
  final String status;
  final DateTime createdAt;

  factory ProductionRequest.fromJson(Map<String, dynamic> json) {
    final type = ProductionRequestType.values.firstWhere(
      (value) =>
          value.code.toLowerCase() ==
          (json['type']?.toString() ?? '').toLowerCase(),
      orElse: () => ProductionRequestType.rawMaterial,
    );
    return ProductionRequest(
      id: json['id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? type.title,
      subtitle: json['subtitle']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Створено',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ProductionReference {
  const ProductionReference({
    required this.uid,
    required this.name,
    this.code = '',
  });

  final String uid;
  final String name;
  final String code;

  factory ProductionReference.fromJson(Map<String, dynamic> json) {
    return ProductionReference(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class ProductionTemplateLine {
  const ProductionTemplateLine({
    required this.group,
    required this.itemUid,
    required this.itemName,
    required this.quantity,
    this.packageUid = '',
    this.packageName = '',
    this.required = true,
    this.comment = '',
  });

  final String group;
  final String itemUid;
  final String itemName;
  final String packageUid;
  final String packageName;
  final double quantity;
  final bool required;
  final String comment;

  factory ProductionTemplateLine.fromJson(Map<String, dynamic> json) {
    return ProductionTemplateLine(
      group: json['group']?.toString() ?? '',
      itemUid: json['itemUid']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      packageUid: json['packageUid']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      required: json['required'] != false,
      comment: json['comment']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'group': group,
        'itemUid': itemUid,
        if (packageUid.isNotEmpty) 'packageUid': packageUid,
        'quantity': quantity,
        'required': required,
        'comment': comment,
      };
}

class ProductionTemplate {
  const ProductionTemplate({
    required this.uid,
    required this.name,
    required this.organizationUid,
    required this.organizationCode,
    required this.organizationName,
    required this.templateType,
    required this.drinkType,
    required this.baseVolume,
    required this.active,
    required this.lines,
    this.productUid = '',
    this.productName = '',
    this.comment = '',
  });

  final String uid;
  final String name;
  final String organizationUid;
  final String organizationCode;
  final String organizationName;
  final String templateType;
  final String drinkType;
  final String productUid;
  final String productName;
  final double baseVolume;
  final bool active;
  final String comment;
  final List<ProductionTemplateLine> lines;

  factory ProductionTemplate.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return ProductionTemplate(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      organizationUid: json['organizationUid']?.toString() ?? '',
      organizationCode: json['organizationCode']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      templateType: json['templateType']?.toString() ?? '',
      drinkType: json['drinkType']?.toString() ?? '',
      productUid: json['productUid']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      baseVolume: _asDouble(json['baseVolume']),
      active: json['active'] != false,
      comment: json['comment']?.toString() ?? '',
      lines: rawLines
          .map((line) => ProductionTemplateLine.fromJson(
                Map<String, dynamic>.from(line as Map),
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (uid.isNotEmpty) 'uid': uid,
        'name': name,
        if (organizationUid.isNotEmpty) 'organizationUid': organizationUid,
        if (organizationCode.isNotEmpty) 'organizationCode': organizationCode,
        'templateType': templateType,
        'drinkType': drinkType,
        if (productUid.isNotEmpty) 'productUid': productUid,
        'baseVolume': baseVolume,
        'active': active,
        'comment': comment,
        'lines': lines.map((line) => line.toJson()).toList(),
      };
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

class ProductionRequestLineDraft {
  const ProductionRequestLineDraft({
    required this.itemUid,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.characteristicUid = '',
    this.seriesUid = '',
    this.purpose = '',
  });

  final String itemUid;
  final String itemName;
  final String characteristicUid;
  final String seriesUid;
  final double quantity;
  final String unit;
  final String purpose;

  Map<String, dynamic> toJson() => {
        if (itemUid.isNotEmpty) 'itemUid': itemUid,
        'itemName': itemName,
        if (characteristicUid.isNotEmpty)
          'characteristicUid': characteristicUid,
        if (seriesUid.isNotEmpty) 'seriesUid': seriesUid,
        'quantity': quantity,
        'unit': unit,
        if (purpose.isNotEmpty) 'purpose': purpose,
      };
}

class ProductionService {
  ProductionService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ProductionRequest>> getRequests() async {
    final response = await _apiClient.sendAuthorizedRequest(
      'GET',
      '/production/requests',
    );
    if (response.statusCode == 404 || response.statusCode == 501) {
      return const [];
    }
    if (response.statusCode != 200) {
      throw Exception(
          'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) return const [];
    return data
        .map((item) => ProductionRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<List<ProductionReference>> getWarehouses() {
    return _getReferences('/production/warehouses');
  }

  Future<List<ProductionReference>> getCatalog() {
    return _getReferences('/production/catalog');
  }

  Future<List<ProductionReference>> searchCatalog(String query) {
    final value = Uri.encodeQueryComponent(query.trim());
    return _getReferences('/production/catalog?q=$value');
  }

  Future<List<ProductionTemplate>> getTemplates({String? orgCode}) async {
    final suffix = orgCode == null || orgCode.trim().isEmpty
        ? ''
        : '?orgCode=${Uri.encodeQueryComponent(orgCode.trim())}';
    final data = await _getJson('GET', '/production/templates$suffix');
    if (data is! List) return const [];
    return data
        .map((item) => ProductionTemplate.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<ProductionTemplate> getTemplate(String uid) async {
    final data = await _getJson(
      'GET',
      '/production/templates/by-id?id=${Uri.encodeQueryComponent(uid)}',
    );
    return ProductionTemplate.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ProductionTemplate> createTemplate(ProductionTemplate template) {
    return _saveTemplate('/production/templates/create', template.toJson());
  }

  Future<ProductionTemplate> updateTemplate(ProductionTemplate template) {
    return _saveTemplate('/production/templates/update', template.toJson());
  }

  Future<ProductionTemplate> copyTemplate(String uid, String name) {
    return _saveTemplate('/production/templates/copy', {
      'templateUid': uid,
      'name': name,
    });
  }

  Future<ProductionTemplate> archiveTemplate(String uid) {
    return _saveTemplate('/production/templates/archive', {'uid': uid});
  }

  Future<List<ProductionRequest>> createFromTemplate({
    required String templateUid,
    required double volume,
    required DateTime requiredDate,
    String subdivisionUid = '',
    String comment = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/production/requests/create-from-template',
      body: {
        'templateUid': templateUid,
        if (subdivisionUid.isNotEmpty) 'subdivisionUid': subdivisionUid,
        'volume': volume,
        'requiredDate': requiredDate.toIso8601String(),
        'comment': comment,
      },
    );
    final orders = (data as Map)['orders'] as List<dynamic>? ?? const [];
    return orders.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return ProductionRequest.fromJson({
        'id': map['id'],
        'title': 'Замовлення №${map['number'] ?? ''}',
        'subtitle':
            '${map['sourceWarehouse'] ?? ''} → ${map['destinationWarehouse'] ?? ''}',
        'status': map['status'],
        'createdAt': map['date'],
        'type': 'RawMaterial',
      });
    }).toList();
  }

  Future<ProductionTemplate> _saveTemplate(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final data = await _getJson('POST', endpoint, body: body);
    return ProductionTemplate.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<dynamic> _getJson(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _apiClient.sendAuthorizedRequest(
      method,
      endpoint,
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<ProductionReference>> _getReferences(String endpoint) async {
    final response = await _apiClient.sendAuthorizedRequest('GET', endpoint);
    if (response.statusCode == 404 || response.statusCode == 501) {
      return const [];
    }
    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) return const [];
    return data
        .map((item) => ProductionReference.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .where((item) => item.uid.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  Future<void> createRequest({
    required ProductionRequestType type,
    required String direction,
    required String sourceWarehouseUid,
    required String destinationWarehouseUid,
    required DateTime requiredDate,
    required List<ProductionRequestLineDraft> lines,
    required String comment,
  }) async {
    final response = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/production/requests/create',
      body: jsonEncode({
        'type': type.code,
        'direction': direction,
        'sourceWarehouseUid': sourceWarehouseUid,
        'destinationWarehouseUid': destinationWarehouseUid,
        'requiredDate': requiredDate.toIso8601String(),
        'lines': lines.map((line) => line.toJson()).toList(),
        'comment': comment,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }
  }
}
