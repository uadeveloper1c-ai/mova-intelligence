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
