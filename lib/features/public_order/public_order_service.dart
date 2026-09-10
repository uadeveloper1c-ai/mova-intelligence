import 'dart:convert';

import '../../api/api_client.dart';

class PublicOrderForm {
  const PublicOrderForm({
    required this.token,
    required this.partnerName,
    required this.contractorName,
    required this.organizationName,
    required this.agreementName,
    required this.warehouseName,
    required this.priceTypeName,
    required this.managerName,
    required this.managerPhone,
    required this.paymentOptions,
    required this.comment,
  });

  final String token;
  final String partnerName;
  final String contractorName;
  final String organizationName;
  final String agreementName;
  final String warehouseName;
  final String priceTypeName;
  final String managerName;
  final String managerPhone;
  final List<PublicOrderPaymentOption> paymentOptions;
  final String comment;

  factory PublicOrderForm.fromJson(Map<String, dynamic> json) {
    return PublicOrderForm(
      token: json['token']?.toString() ?? '',
      partnerName: json['partnerName']?.toString() ?? '',
      contractorName: json['contractorName']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      agreementName: json['agreementName']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      priceTypeName: json['priceTypeName']?.toString() ?? '',
      managerName: json['managerName']?.toString() ?? '',
      managerPhone: json['managerPhone']?.toString() ?? '',
      paymentOptions: (json['paymentOptions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PublicOrderPaymentOption.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class PublicOrderPaymentOption {
  const PublicOrderPaymentOption({
    required this.code,
    required this.title,
    required this.contractUid,
    required this.contractName,
    required this.requiresLicense,
  });

  final String code;
  final String title;
  final String contractUid;
  final String contractName;
  final bool requiresLicense;

  bool get isCash => code == 'cash';

  factory PublicOrderPaymentOption.fromJson(Map<String, dynamic> json) {
    return PublicOrderPaymentOption(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      contractUid: json['contractUid']?.toString() ?? '',
      contractName: json['contractName']?.toString() ?? '',
      requiresLicense: json['requiresLicense'] == true,
    );
  }
}

class PublicOrderItem {
  const PublicOrderItem({
    required this.uid,
    required this.name,
    required this.code,
    required this.price,
    required this.stock,
    required this.boxQuantity,
    required this.imageUrl,
  });

  final String uid;
  final String name;
  final String code;
  final double price;
  final double stock;
  final double boxQuantity;
  final String imageUrl;

  factory PublicOrderItem.fromJson(
    Map<String, dynamic> json, {
    String Function(String)? resolveUrl,
  }) {
    final rawImageUrl = json['imageUrl']?.toString() ?? '';
    return PublicOrderItem(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      price: _asDouble(json['price']),
      stock: _asDouble(json['stock']),
      boxQuantity: _asDouble(json['boxQuantity']),
      imageUrl: rawImageUrl.isEmpty
          ? ''
          : (resolveUrl == null ? rawImageUrl : resolveUrl(rawImageUrl)),
    );
  }
}

class PublicOrderLine {
  const PublicOrderLine({
    required this.item,
    required this.quantity,
  });

  final PublicOrderItem item;
  final double quantity;

  double get amount => quantity * item.price;

  Map<String, dynamic> toJson() => {
        'itemUid': item.uid,
        'quantity': quantity,
      };
}

class PublicOrderSubmitResult {
  const PublicOrderSubmitResult({
    required this.number,
    required this.uid,
    required this.invoiceUrl,
    required this.paymentUrl,
    required this.paymentAvailable,
    required this.paymentPurpose,
    required this.licenseWarning,
  });

  final String number;
  final String uid;
  final String invoiceUrl;
  final String paymentUrl;
  final bool paymentAvailable;
  final String paymentPurpose;
  final String licenseWarning;

  factory PublicOrderSubmitResult.fromJson(
    Map<String, dynamic> json, {
    String Function(String)? resolveUrl,
  }) {
    String resolved(String key) {
      final value = json[key]?.toString() ?? '';
      return value.isEmpty || resolveUrl == null ? value : resolveUrl(value);
    }

    return PublicOrderSubmitResult(
      number: json['number']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      invoiceUrl: resolved('invoiceUrl'),
      paymentUrl: resolved('paymentUrl'),
      paymentAvailable: json['paymentAvailable'] == true,
      paymentPurpose: json['paymentPurpose']?.toString() ?? '',
      licenseWarning: json['licenseWarning']?.toString() ?? '',
    );
  }
}

class PublicOrderHistoryOrder {
  const PublicOrderHistoryOrder({
    required this.id,
    required this.number,
    required this.date,
    required this.shipmentDate,
    required this.amount,
    required this.currency,
    required this.status,
    required this.linesCount,
    required this.comment,
  });

  final String id;
  final String number;
  final DateTime? date;
  final DateTime? shipmentDate;
  final double amount;
  final String currency;
  final String status;
  final int linesCount;
  final String comment;

  factory PublicOrderHistoryOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '');

    return PublicOrderHistoryOrder(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      date: parseDate(json['date']),
      shipmentDate: parseDate(json['shipmentDate']),
      amount: _asDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'UAH',
      status: json['status']?.toString() ?? '',
      linesCount: int.tryParse(json['linesCount']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class PublicOrderService {
  const PublicOrderService(this._apiClient);

  final ApiClient _apiClient;

  Future<PublicOrderForm> getForm(String token) async {
    final data = await _getJson(
      'GET',
      '/public/order/form?token=${Uri.encodeQueryComponent(token)}',
    );
    return PublicOrderForm.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<PublicOrderItem>> searchCatalog({
    required String token,
    required String query,
  }) async {
    final params = Uri(queryParameters: {
      'token': token,
      'q': query.trim(),
    }).query;
    final data = await _getJson('GET', '/public/order/catalog?$params');
    if (data is! List) return const [];
    return data
        .map((item) => PublicOrderItem.fromJson(
              Map<String, dynamic>.from(item as Map),
              resolveUrl: _apiClient.resolveUrl,
            ))
        .toList();
  }

  Future<PublicOrderSubmitResult> submit({
    required String token,
    required List<PublicOrderLine> lines,
    required String paymentForm,
    String cashMethod = '',
    String comment = '',
  }) async {
    final data = await _getJson(
      'POST',
      '/public/order/submit',
      body: {
        'token': token,
        'paymentForm': paymentForm,
        'cashMethod': cashMethod,
        'comment': comment.trim(),
        'lines': lines.map((line) => line.toJson()).toList(),
      },
    );
    return PublicOrderSubmitResult.fromJson(
      Map<String, dynamic>.from(data as Map),
      resolveUrl: _apiClient.resolveUrl,
    );
  }

  Future<List<PublicOrderHistoryOrder>> getHistory(String token) async {
    final data = await _getJson(
      'GET',
      '/public/order/history?token=${Uri.encodeQueryComponent(token)}',
    );
    if (data is! List) return const [];
    return data
        .map((item) => PublicOrderHistoryOrder.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<dynamic> _getJson(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _apiClient.sendPublicRequest(
      method,
      endpoint,
      body: body == null ? null : jsonEncode(body),
    );
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: $text');
    }
    return jsonDecode(text);
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
