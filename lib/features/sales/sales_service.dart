import 'dart:convert';

import '../../api/api_client.dart';

class SalesReference {
  const SalesReference({
    required this.uid,
    required this.name,
    this.code = '',
    this.kind = '',
    this.kindLabel = '',
    this.priority = 0,
    this.priceTypeUid = '',
    this.priceTypeName = '',
    this.warehouseUid = '',
    this.warehouseName = '',
    this.organizationUid = '',
    this.organizationName = '',
    this.stock,
    this.boxQuantity,
  });

  final String uid;
  final String name;
  final String code;
  final String kind;
  final String kindLabel;
  final int priority;
  final String priceTypeUid;
  final String priceTypeName;
  final String warehouseUid;
  final String warehouseName;
  final String organizationUid;
  final String organizationName;
  final double? stock;
  final double? boxQuantity;

  factory SalesReference.fromJson(Map<String, dynamic> json) {
    return SalesReference(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      priceTypeUid: json['priceTypeUid']?.toString() ?? '',
      priceTypeName: json['priceTypeName']?.toString() ?? '',
      warehouseUid: json['warehouseUid']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      organizationUid: json['organizationUid']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      stock: json.containsKey('stock') ? _asDouble(json['stock']) : null,
      boxQuantity: json.containsKey('boxQuantity')
          ? _asDouble(json['boxQuantity'])
          : null,
    );
  }
}

class SalesPriceInfo {
  const SalesPriceInfo({
    required this.price,
    required this.stock,
  });

  final double price;
  final double stock;

  factory SalesPriceInfo.fromJson(Map<String, dynamic> json) {
    return SalesPriceInfo(
      price: _asDouble(json['price']),
      stock: _asDouble(json['stock']),
    );
  }
}

class SalesDebtRow {
  const SalesDebtRow({
    required this.contract,
    required this.debt,
    required this.prepayment,
    required this.balance,
  });

  final String contract;
  final double debt;
  final double prepayment;
  final double balance;

  factory SalesDebtRow.fromJson(Map<String, dynamic> json) {
    return SalesDebtRow(
      contract: json['contract']?.toString() ?? '',
      debt: _asDouble(json['debt']),
      prepayment: _asDouble(json['prepayment']),
      balance: _asDouble(json['balance']),
    );
  }
}

class SalesItemAnalyticsRow {
  const SalesItemAnalyticsRow({
    required this.itemUid,
    required this.itemName,
    required this.unitName,
    required this.quantity,
    required this.previousQuantity,
    required this.deltaQuantity,
    required this.deltaPercent,
    required this.amount,
    required this.previousAmount,
    required this.orders,
    required this.previousOrders,
  });

  final String itemUid;
  final String itemName;
  final String unitName;
  final double quantity;
  final double previousQuantity;
  final double deltaQuantity;
  final double deltaPercent;
  final double amount;
  final double previousAmount;
  final int orders;
  final int previousOrders;

  factory SalesItemAnalyticsRow.fromJson(Map<String, dynamic> json) {
    return SalesItemAnalyticsRow(
      itemUid: json['itemUid']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      previousQuantity: _asDouble(json['previousQuantity']),
      deltaQuantity: _asDouble(json['deltaQuantity']),
      deltaPercent: _asDouble(json['deltaPercent']),
      amount: _asDouble(json['amount']),
      previousAmount: _asDouble(json['previousAmount']),
      orders: int.tryParse(json['orders']?.toString() ?? '') ?? 0,
      previousOrders:
          int.tryParse(json['previousOrders']?.toString() ?? '') ?? 0,
    );
  }
}

class SalesTelegramParseResult {
  const SalesTelegramParseResult({
    required this.rows,
    required this.unrecognized,
    required this.recognizedCount,
    required this.unrecognizedCount,
    required this.canCreateOrder,
    required this.sourceText,
  });

  final List<SalesTelegramParsedRow> rows;
  final List<SalesTelegramParsedRow> unrecognized;
  final int recognizedCount;
  final int unrecognizedCount;
  final bool canCreateOrder;
  final String sourceText;

  factory SalesTelegramParseResult.fromJson(Map<String, dynamic> json) {
    List<SalesTelegramParsedRow> parseRows(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => SalesTelegramParsedRow.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    }

    return SalesTelegramParseResult(
      rows: parseRows(json['rows']),
      unrecognized: parseRows(json['unrecognized']),
      recognizedCount:
          int.tryParse(json['recognizedCount']?.toString() ?? '') ?? 0,
      unrecognizedCount:
          int.tryParse(json['unrecognizedCount']?.toString() ?? '') ?? 0,
      canCreateOrder: json['canCreateOrder'] == true,
      sourceText: json['sourceText']?.toString() ?? '',
    );
  }
}

class SalesTelegramParsedRow {
  const SalesTelegramParsedRow({
    required this.sourceLine,
    required this.alias,
    required this.quantity,
    required this.unitText,
    required this.confidence,
    required this.source,
    required this.status,
    required this.itemUid,
    required this.itemName,
    required this.learned,
    required this.suggestions,
  });

  final String sourceLine;
  final String alias;
  final double quantity;
  final String unitText;
  final int confidence;
  final String source;
  final String status;
  final String itemUid;
  final String itemName;
  final bool learned;
  final List<SalesReference> suggestions;

  factory SalesTelegramParsedRow.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'];
    return SalesTelegramParsedRow(
      sourceLine: json['sourceLine']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      unitText: json['unitText']?.toString() ?? '',
      confidence: int.tryParse(json['confidence']?.toString() ?? '') ?? 0,
      source: json['source']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      itemUid: json['itemUid']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      learned: json['learned'] == true,
      suggestions: rawSuggestions is List
          ? rawSuggestions
              .map((item) => SalesReference.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class SalesCustomerOrder {
  const SalesCustomerOrder({
    required this.id,
    required this.number,
    required this.date,
    required this.shipmentDate,
    required this.partnerName,
    required this.contractorName,
    required this.agreementName,
    required this.contractName,
    required this.organizationName,
    required this.organizationUid,
    required this.orgCode,
    required this.warehouseName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.comment,
  });

  final String id;
  final String number;
  final DateTime? date;
  final DateTime? shipmentDate;
  final String partnerName;
  final String contractorName;
  final String agreementName;
  final String contractName;
  final String organizationName;
  final String organizationUid;
  final String orgCode;
  final String warehouseName;
  final double amount;
  final String currency;
  final String status;
  final String comment;

  factory SalesCustomerOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '');

    return SalesCustomerOrder(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      date: parseDate(json['date']),
      shipmentDate: parseDate(json['shipmentDate']),
      partnerName: json['partnerName']?.toString() ?? '',
      contractorName: json['contractorName']?.toString() ?? '',
      agreementName: json['agreementName']?.toString() ?? '',
      contractName: json['contractName']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      organizationUid: json['organizationUid']?.toString() ?? '',
      orgCode: json['orgCode']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'UAH',
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class SalesCustomerOrderLine {
  const SalesCustomerOrderLine({
    required this.number,
    required this.itemName,
    required this.characteristicName,
    required this.quantity,
    required this.unitName,
    required this.supplyActionName,
    required this.priceTypeName,
    required this.price,
    required this.amount,
  });

  final int number;
  final String itemName;
  final String characteristicName;
  final double quantity;
  final String unitName;
  final String supplyActionName;
  final String priceTypeName;
  final double price;
  final double amount;

  factory SalesCustomerOrderLine.fromJson(Map<String, dynamic> json) {
    return SalesCustomerOrderLine(
      number: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      itemName: json['itemName']?.toString() ?? '',
      characteristicName: json['characteristicName']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      unitName: json['unitName']?.toString() ?? '',
      supplyActionName: json['supplyActionName']?.toString() ?? '',
      priceTypeName: json['priceTypeName']?.toString() ?? '',
      price: _asDouble(json['price']),
      amount: _asDouble(json['amount']),
    );
  }
}

class SalesCustomerOrderDetails {
  const SalesCustomerOrderDetails({
    required this.header,
    required this.lines,
  });

  final SalesCustomerOrder header;
  final List<SalesCustomerOrderLine> lines;

  factory SalesCustomerOrderDetails.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return SalesCustomerOrderDetails(
      header: SalesCustomerOrder.fromJson(json),
      lines: rawLines is List
          ? rawLines
              .map((item) => SalesCustomerOrderLine.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class CustomerOrderLineDraft {
  const CustomerOrderLineDraft({
    required this.itemUid,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.priceTypeUid,
    required this.manualPrice,
    required this.supplyAction,
  });

  final String itemUid;
  final String itemName;
  final double quantity;
  final double price;
  final String priceTypeUid;
  final bool manualPrice;
  final String supplyAction;

  Map<String, dynamic> toJson() => {
        'itemUid': itemUid,
        'itemName': itemName,
        'quantity': quantity,
        'price': price,
        'priceTypeUid': priceTypeUid,
        'manualPrice': manualPrice,
        'supplyAction': supplyAction,
      };
}

class SalesService {
  SalesService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SalesReference>> searchPartners(String query) {
    return _getReferences(
      '/sales/partners?q=${Uri.encodeQueryComponent(query.trim())}',
    );
  }

  Future<List<SalesReference>> getAgreements(String partnerUid) {
    return _getReferences(
      '/sales/agreements?partnerUid=${Uri.encodeQueryComponent(partnerUid)}',
    );
  }

  Future<List<SalesReference>> getContracts({
    required String partnerUid,
    required String contractorUid,
  }) {
    final params = Uri(queryParameters: {
      'partnerUid': partnerUid,
      if (contractorUid.isNotEmpty) 'contractorUid': contractorUid,
    }).query;
    return _getReferences('/sales/contracts?$params');
  }

  Future<List<SalesReference>> searchCatalog(
    String query, {
    String warehouseUid = '',
  }) {
    final params = Uri(queryParameters: {
      'q': query.trim(),
      if (warehouseUid.isNotEmpty) 'warehouseUid': warehouseUid,
    }).query;
    return _getReferences('/sales/catalog?$params');
  }

  Future<List<SalesReference>> getPriceTypes() {
    return _getReferences('/sales/price-types');
  }

  Future<SalesPriceInfo> getPrice({
    required String itemUid,
    required String priceTypeUid,
    String warehouseUid = '',
  }) async {
    if (itemUid.isEmpty) {
      return const SalesPriceInfo(price: 0, stock: 0);
    }
    final params = Uri(queryParameters: {
      'itemUid': itemUid,
      if (priceTypeUid.isNotEmpty) 'priceTypeUid': priceTypeUid,
      if (warehouseUid.isNotEmpty) 'warehouseUid': warehouseUid,
    }).query;
    final data = await _getJson('GET', '/sales/price?$params');
    if (data is Map) {
      return SalesPriceInfo.fromJson(Map<String, dynamic>.from(data));
    }
    return const SalesPriceInfo(price: 0, stock: 0);
  }

  Future<List<SalesDebtRow>> getReceivables({
    required String partnerUid,
    required String contractorUid,
  }) async {
    final params = Uri(queryParameters: {
      'partnerUid': partnerUid,
      if (contractorUid.isNotEmpty) 'contractorUid': contractorUid,
    }).query;
    final data = await _getJson('GET', '/sales/receivables?$params');
    if (data is! List) return const [];
    return data
        .map((item) => SalesDebtRow.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<List<SalesItemAnalyticsRow>> getItemsAnalytics({
    required DateTime dateFrom,
    required DateTime dateTo,
    String partner = '',
    String orgUid = '',
    int limit = 200,
  }) async {
    final params = Uri(queryParameters: {
      'dateFrom': _dateParam(dateFrom),
      'dateTo': _dateParam(dateTo),
      if (partner.trim().isNotEmpty) 'partner': partner.trim(),
      if (orgUid.trim().isNotEmpty) 'orgUid': orgUid.trim(),
      'limit': limit.toString(),
    }).query;
    final data = await _getJson('GET', '/sales/items-analytics?$params');
    if (data is! List) return const [];
    return data
        .map((item) => SalesItemAnalyticsRow.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<SalesTelegramParseResult> parseTelegramOrderText({
    required String text,
    String orgUid = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/sales/telegram/parse-order-text',
      body: {
        'text': text,
        if (orgUid.trim().isNotEmpty) 'orgUid': orgUid.trim(),
      },
    );
    if (data is Map) {
      return SalesTelegramParseResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return const SalesTelegramParseResult(
      rows: [],
      unrecognized: [],
      recognizedCount: 0,
      unrecognizedCount: 0,
      canCreateOrder: false,
      sourceText: '',
    );
  }

  Future<List<SalesCustomerOrder>> getCustomerOrders({
    required DateTime dateFrom,
    required DateTime dateTo,
    String partner = '',
    String orgUid = '',
    int? limit,
  }) async {
    final params = Uri(queryParameters: {
      'dateFrom': _dateParam(dateFrom),
      'dateTo': _dateParam(dateTo),
      if (partner.trim().isNotEmpty) 'partner': partner.trim(),
      if (orgUid.trim().isNotEmpty) 'orgUid': orgUid.trim(),
      if (limit != null) 'limit': limit.toString(),
    }).query;
    final data = await _getJson('GET', '/sales/customer-orders?$params');
    if (data is! List) return const [];
    return data
        .map((item) => SalesCustomerOrder.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<SalesCustomerOrderDetails?> getCustomerOrderById(String id) async {
    final params = Uri(queryParameters: {'id': id}).query;
    final data = await _getJson('GET', '/sales/customer-orders/by-id?$params');
    if (data is Map) {
      return SalesCustomerOrderDetails.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return null;
  }

  Future<String> createCustomerOrder({
    required String partnerUid,
    required String agreementUid,
    required String contractUid,
    required DateTime shipmentDate,
    required List<CustomerOrderLineDraft> lines,
    String comment = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/sales/customer-orders/create',
      body: {
        'partnerUid': partnerUid,
        if (agreementUid.isNotEmpty) 'agreementUid': agreementUid,
        if (contractUid.isNotEmpty) 'contractUid': contractUid,
        'shipmentDate': shipmentDate.toIso8601String(),
        'comment': comment,
        'lines': lines.map((line) => line.toJson()).toList(),
      },
    );
    if (data is Map) {
      return data['number']?.toString() ??
          data['order_number']?.toString() ??
          '';
    }
    return '';
  }

  Future<String> sendCustomerOrderToWms(String uid) async {
    final data = await _getJson(
      'POST',
      '/sales/customer-orders/send-to-wms',
      body: {'uid': uid},
    );
    if (data is Map) {
      return data['message']?.toString() ?? '';
    }
    return '';
  }

  Future<String> updateCustomerOrderSupply(String uid) async {
    final data = await _getJson(
      'POST',
      '/sales/customer-orders/update-supply',
      body: {'uid': uid},
    );
    if (data is Map) {
      return data['message']?.toString() ?? '';
    }
    return '';
  }

  Future<List<SalesReference>> _getReferences(String endpoint) async {
    final data = await _getJson('GET', endpoint);
    if (data is! List) return const [];
    return data
        .map((item) => SalesReference.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
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
    if (response.statusCode == 404 || response.statusCode == 501) {
      return method == 'GET' ? const [] : const {};
    }
    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}

String _dateParam(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
