import 'dart:convert';

import '../../api/api_client.dart';
import 'bottling_models.dart';
import 'brew_models.dart';
import 'cold_department_models.dart';

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
    this.wmsStatus = '',
    this.canCancel = false,
    this.canEdit = false,
    this.wmsDispatchAt,
    this.number = '',
    this.sourceWarehouse = '',
    this.destinationWarehouse = '',
    this.organization = '',
    this.comment = '',
    this.desiredReceiptDate,
    this.lines = const [],
  });

  final String id;
  final ProductionRequestType type;
  final String title;
  final String subtitle;
  final String status;
  final String wmsStatus;
  final bool canCancel;
  final bool canEdit;
  final DateTime? wmsDispatchAt;
  final String number;
  final String sourceWarehouse;
  final String destinationWarehouse;
  final String organization;
  final String comment;
  final DateTime? desiredReceiptDate;
  final List<ProductionRequestLine> lines;
  final DateTime createdAt;

  factory ProductionRequest.fromJson(Map<String, dynamic> json) {
    final type = ProductionRequestType.values.firstWhere(
      (value) =>
          value.code.toLowerCase() ==
          (json['type']?.toString() ?? '').toLowerCase(),
      orElse: () => ProductionRequestType.rawMaterial,
    );
    final rawTitle = json['title']?.toString() ?? '';
    final number = (json['number']?.toString() ?? '').trim().isNotEmpty
        ? json['number']!.toString()
        : (RegExp(r'№\s*([^\s]+)').firstMatch(rawTitle)?.group(1) ?? '');
    final sourceWarehouse = json['sourceWarehouse']?.toString() ?? '';
    final destinationWarehouse = json['destinationWarehouse']?.toString() ?? '';
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return ProductionRequest(
      id: json['id']?.toString() ?? '',
      type: type,
      title: rawTitle.isNotEmpty
          ? rawTitle
          : (number.isEmpty
              ? type.title
              : 'Замовлення на переміщення №$number'),
      subtitle: json['subtitle']?.toString() ??
          ([sourceWarehouse, destinationWarehouse]
              .where((value) => value.trim().isNotEmpty)
              .join(' → ')),
      status: json['status']?.toString() ?? 'Створено',
      wmsStatus: (json['wmsStatus'] ?? json['statuswms'] ?? json['wms_status'])
              ?.toString() ??
          '',
      canCancel: json['canCancel'] == true ||
          json['canCancel']?.toString().toLowerCase() == 'true',
      canEdit: json['canEdit'] == true ||
          json['canEdit']?.toString().toLowerCase() == 'true',
      wmsDispatchAt: DateTime.tryParse(
        json['wmsDispatchAt']?.toString() ?? '',
      ),
      number: number,
      sourceWarehouse: sourceWarehouse,
      destinationWarehouse: destinationWarehouse,
      organization: json['organization']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      desiredReceiptDate: DateTime.tryParse(
        (json['desiredReceiptDate'] ??
                    json['desired_receipt_date'] ??
                    json['desiredDate'] ??
                    json['requiredDate'] ??
                    json['ЖелаемаяДатаПоступления'])
                ?.toString() ??
            '',
      ),
      lines: rawLines
          .whereType<Map>()
          .map((line) => ProductionRequestLine.fromJson(
                Map<String, dynamic>.from(line),
              ))
          .toList(),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['date'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class ProductionRequestLine {
  const ProductionRequestLine({
    required this.number,
    required this.itemName,
    required this.quantity,
    this.unitName = '',
    this.supplyActionName = '',
  });

  final int number;
  final String itemName;
  final double quantity;
  final String unitName;
  final String supplyActionName;

  factory ProductionRequestLine.fromJson(Map<String, dynamic> json) {
    return ProductionRequestLine(
      number: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      itemName: json['itemName']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      unitName: json['unitName']?.toString() ?? '',
      supplyActionName: json['supplyActionName']?.toString() ?? '',
    );
  }
}

class ProductionReference {
  const ProductionReference({
    required this.uid,
    required this.name,
    this.code = '',
    this.stock,
    this.stockUnit = '',
    this.group = '',
  });

  final String uid;
  final String name;
  final String code;
  final double? stock;
  final String stockUnit;
  final String group;

  factory ProductionReference.fromJson(Map<String, dynamic> json) {
    return ProductionReference(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      stock: _asNullableDouble(
        json['stock'] ??
            json['balance'] ??
            json['quantityOnHand'] ??
            json['available'] ??
            json['stockQuantity'] ??
            json['quantityBalance'],
      ),
      stockUnit: json['stockUnit']?.toString() ??
          json['unitName']?.toString() ??
          json['unit']?.toString() ??
          json['measure']?.toString() ??
          json['uom']?.toString() ??
          '',
      group: json['group']?.toString() ?? '',
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

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text.replaceAll(',', '.'));
}

class ProductionRequestLineDraft {
  const ProductionRequestLineDraft({
    required this.itemUid,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.group = '',
    this.characteristicUid = '',
    this.seriesUid = '',
  });

  final String itemUid;
  final String itemName;
  final String characteristicUid;
  final String seriesUid;
  final double quantity;
  final String unit;
  final String group;

  Map<String, dynamic> toJson() => {
        if (itemUid.isNotEmpty) 'itemUid': itemUid,
        'itemName': itemName,
        if (characteristicUid.isNotEmpty)
          'characteristicUid': characteristicUid,
        if (seriesUid.isNotEmpty) 'seriesUid': seriesUid,
        'quantity': quantity,
        'unit': unit,
        if (group.isNotEmpty) 'group': group,
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
      throw Exception(_responseErrorMessage(
        response.statusCode,
        response.bodyBytes,
      ));
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) return const [];
    return data
        .map((item) => ProductionRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<ProductionRequest> getRequestById(String uid) async {
    final requests = await getRequests();
    for (final request in requests) {
      if (request.id == uid) return request;
    }
    throw Exception('Замовлення не знайдено');
  }

  Future<void> cancelRequest(String uid) async {
    final response = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/production/requests/cancel',
      body: jsonEncode({'id': uid}),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseErrorMessage(
        response.statusCode,
        response.bodyBytes,
      ));
    }
  }

  Future<ProductionRequest> updateRequest({
    required String uid,
    required DateTime requiredDate,
    required String comment,
    required List<double> quantities,
  }) async {
    final response = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/production/requests/update',
      body: jsonEncode({
        'id': uid,
        'requiredDate': requiredDate.toIso8601String(),
        'comment': comment,
        'lines': [
          for (final quantity in quantities) {'quantity': quantity},
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseErrorMessage(
        response.statusCode,
        response.bodyBytes,
      ));
    }
    return ProductionRequest.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      ),
    );
  }

  Future<List<ProductionReference>> getWarehouses({
    String? orgCode,
    String? templateType,
    String? group,
    ProductionRequestType? requestType,
    String? warehouseRole,
  }) {
    final params = <String, String>{};
    void addParam(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) params[key] = trimmed;
    }

    addParam('orgCode', orgCode);
    addParam('templateType', templateType);
    addParam('group', group);
    addParam('requestType', requestType?.code);
    addParam('warehouseRole', warehouseRole);

    if (params.isEmpty) return _getReferences('/production/warehouses');
    final queryString = params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    return _getReferences('/production/warehouses?$queryString');
  }

  Future<List<ProductionReference>> getWarehousesFromRules({
    String? orgCode,
    String? templateType,
    String? group,
    ProductionRequestType? requestType,
    required String warehouseRole,
  }) async {
    final data = await _getJson('GET', '/production/rules');
    if (data is! List) return const [];
    final maps = data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    List<ProductionReference> collect({
      required bool applyType,
      required bool applyGroup,
    }) {
      final result = <String, ProductionReference>{};
      final returnToStock = requestType == ProductionRequestType.returnToStock;
      final useDestination = (warehouseRole == 'destination') != returnToStock;
      final uidKey =
          useDestination ? 'destinationWarehouseUid' : 'sourceWarehouseUid';
      final nameKey =
          useDestination ? 'destinationWarehouseName' : 'sourceWarehouseName';

      for (final map in maps) {
        if (applyType &&
            templateType != null &&
            templateType.trim().isNotEmpty &&
            map['templateType']?.toString() != templateType) {
          continue;
        }
        if (applyGroup &&
            group != null &&
            group.trim().isNotEmpty &&
            map['group']?.toString() != group) {
          continue;
        }
        final uid = map[uidKey]?.toString() ?? '';
        final name = map[nameKey]?.toString() ?? '';
        if (uid.isEmpty || name.isEmpty) continue;
        result[uid] = ProductionReference(uid: uid, name: name);
      }
      return result.values.toList();
    }

    for (final variant in const [
      (applyType: true, applyGroup: true),
      (applyType: true, applyGroup: false),
      (applyType: false, applyGroup: false),
    ]) {
      final warehouses = collect(
        applyType: variant.applyType,
        applyGroup: variant.applyGroup,
      );
      if (warehouses.isNotEmpty) return warehouses;
    }
    return const [];
  }

  Future<List<ProductionReference>> getCatalog({
    String? orgCode,
    String? templateType,
    String? group,
  }) {
    return _getReferences(_productionCatalogEndpoint(
      orgCode: orgCode,
      templateType: templateType,
      group: group,
    ));
  }

  Future<List<ProductionReference>> searchCatalog(
    String query, {
    String? orgCode,
    String? templateType,
    String? group,
  }) async {
    Future<List<ProductionReference>> load(
        String queryValue, String? groupValue) {
      return _getReferences(_productionCatalogEndpoint(
        query: queryValue,
        orgCode: orgCode,
        templateType: templateType,
        group: groupValue,
      ));
    }

    final references = await load(query, group);
    if (references.isNotEmpty) return references;

    final byWords = await _searchCatalogByWords(
      query,
      (queryValue) => load(queryValue, group),
    );
    return byWords;
  }

  Future<List<ProductionReference>> _searchCatalogByWords(
    String query,
    Future<List<ProductionReference>> Function(String query) load,
  ) async {
    final words = _catalogSearchWords(query);
    if (words.length < 2) return const [];

    final base = await load(words.first);
    if (base.isEmpty) return const [];

    return base.where((item) {
      final value = _normalizeCatalogSearch('${item.name} ${item.code}');
      return words.every(value.contains);
    }).toList();
  }

  static List<String> _catalogSearchWords(String value) {
    final normalized = _normalizeCatalogSearch(value);
    if (normalized.isEmpty) return const [];
    final words =
        normalized.split(' ').where((word) => word.isNotEmpty).toList();
    words.sort((a, b) => b.length.compareTo(a.length));
    return words;
  }

  static String _normalizeCatalogSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _productionCatalogEndpoint({
    String? query,
    String? orgCode,
    String? templateType,
    String? group,
  }) {
    final params = <String, String>{};
    void addParam(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) params[key] = trimmed;
    }

    addParam('q', query);
    addParam('orgCode', orgCode);
    addParam('templateType', templateType);
    addParam('group', group);

    if (params.isEmpty) return '/production/catalog';
    final queryString = params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    return '/production/catalog?$queryString';
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

  Future<List<BrewPassport>> getBrewPassports({String? orgUid}) async {
    final suffix = orgUid == null || orgUid.trim().isEmpty
        ? ''
        : '?orgUid=${Uri.encodeQueryComponent(orgUid.trim())}';
    final data = await _getJson('GET', '/production/brew-passports$suffix');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => BrewPassport.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BrewPassport> getBrewPassport(String uid) async {
    final data = await _getJson(
      'GET',
      '/production/brew-passports/by-id?id=${Uri.encodeQueryComponent(uid)}',
    );
    return BrewPassport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BrewOptions> getBrewOptions({required String orgUid}) async {
    final data = await _getJson(
      'GET',
      '/production/brew-options?orgUid=${Uri.encodeQueryComponent(orgUid)}',
    );
    return BrewOptions.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BrewPassport> createBrewPassport(
    CreateBrewPassportDraft draft,
  ) async {
    final data = await _getJson(
      'POST',
      '/production/brew-passports/create',
      body: draft.toJson(),
    );
    return BrewPassport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BrewPortion> updateBrewPortion(
    BrewPortionUpdate update, {
    required String action,
  }) async {
    final data = await _getJson(
      'POST',
      '/production/brew-portions/update',
      body: update.toJson(action),
    );
    return BrewPortion.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ColdDepartmentData> getColdDepartment() async {
    final data = await _getJson('GET', '/production/cold-department');
    return ColdDepartmentData.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ColdDepartmentData> addColdDepartmentAdditions({
    required String passportUid,
    required List<ColdDepartmentAdditionDraft> items,
    required String operationId,
    String comment = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/production/cold-department/add',
      body: {
        'passportUid': passportUid,
        'items': items.map((item) => item.toJson()).toList(),
        'operationId': operationId,
        'comment': comment,
      },
    );
    return ColdDepartmentData.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<
      ({
        List<ProductionRequest> requests,
        List<ProductionReference> stocks,
      })> getPackagingOverview() async {
    final data = await _getJson('GET', '/production/bottling/packaging');
    final map = Map<String, dynamic>.from(data as Map);
    final requests = (map['requests'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => ProductionRequest.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    final stocks = (map['stocks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => ProductionReference.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    return (requests: requests, stocks: stocks);
  }

  Future<BottlingData> getBottlingData() async {
    final data = await _getJson('GET', '/production/bottling');
    if (data is! Map) {
      throw const FormatException(
        '1С повернула неправильний формат /production/bottling. '
        'Перевірте обробник get_production_bottling.',
      );
    }
    return BottlingData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<BottlingData> createBottling({
    required String passportUid,
    required double inputVolume,
    required List<BottlingLineDraft> items,
    required String operationId,
    String comment = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/production/bottling/create',
      body: {
        'passportUid': passportUid,
        'inputVolume': inputVolume,
        'items': items.map((item) => item.toJson()).toList(),
        'operationId': operationId,
        'comment': comment,
      },
    );
    return BottlingData.fromJson(Map<String, dynamic>.from(data as Map));
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
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

  String _responseErrorMessage(int statusCode, List<int> bodyBytes) {
    final body = utf8.decode(bodyBytes);
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final error = data['error']?.toString().trim();
        if (error != null && error.isNotEmpty) return error;
        final message = data['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall back to the raw response body below.
    }
    return 'HTTP $statusCode: $body';
  }

  Future<void> createRequest({
    required ProductionRequestType type,
    required String orgCode,
    required String direction,
    required String sourceWarehouseUid,
    required String destinationWarehouseUid,
    required DateTime requiredDate,
    required List<ProductionRequestLineDraft> lines,
    required String comment,
  }) async {
    final response = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/production/requests/create-from-template',
      body: jsonEncode({
        'type': type.code,
        'orgCode': orgCode,
        'direction': direction,
        'sourceWarehouseUid': sourceWarehouseUid,
        'destinationWarehouseUid': destinationWarehouseUid,
        'requiredDate': requiredDate.toIso8601String(),
        'lines': lines.map((line) => line.toJson()).toList(),
        'comment': comment,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseErrorMessage(
        response.statusCode,
        response.bodyBytes,
      ));
    }
  }
}
