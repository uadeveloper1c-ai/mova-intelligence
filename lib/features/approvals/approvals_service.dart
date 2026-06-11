import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import 'domain/payment_request.dart';

class ProjectSplitRow {
  final String orgCode;
  final double amount;

  const ProjectSplitRow({
    required this.orgCode,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'orgCode': orgCode,
        'amount': amount,
      };
}

class SalaryStatementOption {
  final String uid;
  final String name;
  final String subdivisionUid;
  final String subdivisionName;
  final double amount;

  const SalaryStatementOption({
    required this.uid,
    required this.name,
    this.subdivisionUid = '',
    this.subdivisionName = '',
    this.amount = 0,
  });

  factory SalaryStatementOption.fromJson(Map<String, dynamic> json) {
    return SalaryStatementOption(
      uid: _firstJsonString(json, const [
        'uid',
        'id',
        'Ссылка',
        'ВедомостьСсылка',
      ]),
      name: _firstJsonString(json, const [
        'name',
        'Наименование',
        'ВедомостьНазвание',
      ]),
      subdivisionUid: _firstJsonString(json, const [
        'subdivisionUid',
        'subdivision_uid',
        'ПодразделениеСсылка',
        'ВедомостьПодразделениеСсылка',
      ]),
      subdivisionName: _firstJsonString(json, const [
        'subdivisionName',
        'subdivision_name',
        'ПодразделениеНаименование',
        'ВедомостьПодразделениеНазвание',
      ]),
      amount: _parseJsonDouble(
        json['amount'] ?? json['Сумма'] ?? json['ВедомостьСумма'],
      ),
    );
  }
}

class CashboxOption {
  final String uid;
  final String name;

  const CashboxOption({
    required this.uid,
    required this.name,
  });

  factory CashboxOption.fromJson(Map<String, dynamic> json) {
    return CashboxOption(
      uid: _firstJsonString(json, const [
        'uid',
        'id',
        'Ссылка',
        'КассаСсылка',
      ]),
      name: _firstJsonString(json, const [
        'name',
        'Наименование',
        'КассаНаименование',
      ]),
    );
  }
}

class TaxOption {
  final String uid;
  final String name;

  const TaxOption({
    required this.uid,
    required this.name,
  });

  factory TaxOption.fromJson(Map<String, dynamic> json) {
    return TaxOption(
      uid: _firstJsonString(json, const [
        'uid',
        'id',
        'Ссылка',
        'Код',
      ]),
      name: _firstJsonString(json, const [
        'name',
        'Наименование',
      ]),
    );
  }
}

class ContractorLookupOption {
  final String uid;
  final String name;
  final String fullName;
  final String edrpou;

  const ContractorLookupOption({
    required this.uid,
    required this.name,
    required this.fullName,
    required this.edrpou,
  });

  factory ContractorLookupOption.fromJson(Map<String, dynamic> json) {
    return ContractorLookupOption(
      uid: _firstJsonString(json, const ['uid', 'id', 'Ссылка']),
      name: _firstJsonString(json, const ['name', 'Наименование']),
      fullName: _firstJsonString(json, const [
        'fullName',
        'НаименованиеПолное',
      ]),
      edrpou: _firstJsonString(json, const [
        'edrpou',
        'КодПоЕДРПОУ',
        'code',
      ]),
    );
  }
}

String _firstJsonString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;

    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }

  return '';
}

double _parseJsonDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.').trim()) ?? 0;
}

class ApprovalsService {
  final ApiClient _apiClient;
  List<PaymentRequest>? _incomingCache;
  DateTime? _incomingCacheAt;
  Future<List<PaymentRequest>>? _incomingInFlight;
  String? _incomingCacheKey;
  String? _incomingInFlightKey;

  ApprovalsService(this._apiClient);

  void invalidateIncomingCache() {
    _incomingCache = null;
    _incomingCacheAt = null;
    _incomingCacheKey = null;
  }

  String _dateParam(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _withPeriod(String endpoint, DateTime? dateFrom, DateTime? dateTo) {
    final params = <String, String>{};
    if (dateFrom != null) params['dateFrom'] = _dateParam(dateFrom);
    if (dateTo != null) params['dateTo'] = _dateParam(dateTo);
    if (params.isEmpty) return endpoint;
    return Uri(path: endpoint, queryParameters: params).toString();
  }

  dynamic _decodeJsonResponse(http.Response r) {
    final body = utf8.decode(r.bodyBytes);
    return jsonDecode(body);
  }

  Future<dynamic> _getJson(String endpoint) async {
    final r = await _apiClient.sendAuthorizedRequest('GET', endpoint);

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    }
    return _decodeJsonResponse(r);
  }

  Future<dynamic> _postJson(String endpoint, Map<String, dynamic> body) async {
    final r = await _apiClient.sendAuthorizedRequest(
      'POST',
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    }
    return _decodeJsonResponse(r);
  }

  Future<List<PaymentRequest>> getMyRequests({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final data =
        await _getJson(_withPeriod('/approvals/my-requests', dateFrom, dateTo));
    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }
    return data
        .map(
            (e) => PaymentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PaymentRequest>> getIncomingRequests({
    bool forceRefresh = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final cacheKey = _withPeriod('/approvals/incoming', dateFrom, dateTo);
    final cacheAt = _incomingCacheAt;
    if (!forceRefresh &&
        _incomingCache != null &&
        _incomingCacheKey == cacheKey &&
        cacheAt != null &&
        DateTime.now().difference(cacheAt) < const Duration(seconds: 30)) {
      return _incomingCache!;
    }

    if (!forceRefresh &&
        _incomingInFlight != null &&
        _incomingInFlightKey == cacheKey) {
      return _incomingInFlight!;
    }

    final future = _loadIncomingRequests(cacheKey);
    _incomingInFlight = future;
    _incomingInFlightKey = cacheKey;
    try {
      return await future;
    } finally {
      if (identical(_incomingInFlight, future)) {
        _incomingInFlight = null;
        _incomingInFlightKey = null;
      }
    }
  }

  Future<List<PaymentRequest>> _loadIncomingRequests(String endpoint) async {
    final data = await _getJson(endpoint);
    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }
    final result = data
        .map(
            (e) => PaymentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _incomingCache = result;
    _incomingCacheAt = DateTime.now();
    _incomingCacheKey = endpoint;
    return result;
  }

  Future<List<PaymentRequest>> getDepartmentRequests({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final data = await _getJson(
        _withPeriod('/approvals/department-requests', dateFrom, dateTo),
      );
      if (data is! List) {
        throw Exception('Очікувався список заявок підрозділу, отримав: $data');
      }
      return data
          .map((e) =>
              PaymentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      final text = e.toString();
      if (text.contains('HTTP 404')) {
        return const [];
      }
      rethrow;
    }
  }

  Future<PaymentRequest> getRequestById(String id) async {
    final data = await _getJson('/approvals/by-id?id=$id');
    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<String?> getContractorByEdrpou(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;

    final data = await _getJson('/contractor/by-edrpou?code=$clean');

    if (data is! Map) return null;

    final found = data['found'] == true;
    if (!found) return null;

    final name = data['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;

    return name;
  }

  Future<List<ContractorLookupOption>> getContractorsByName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return const [];

    final encoded = Uri.encodeQueryComponent(clean);
    dynamic data;
    Object? lastError;

    for (final endpoint in [
      '/contractor/by-name?name=$encoded',
      '/contractor/by_name?name=$encoded',
      '/contractor_by_name?name=$encoded',
    ]) {
      try {
        data = await _getJson(endpoint);
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    if (data is! Map) return const [];

    final items = data['items'];
    if (items is List) {
      return items
          .map((e) => ContractorLookupOption.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
    }

    final found = data['found'] == true;
    final singleName = data['name']?.toString().trim() ?? '';
    if (!found || singleName.isEmpty) return const [];

    return [
      ContractorLookupOption(
        uid: data['uid']?.toString().trim() ?? '',
        name: singleName,
        fullName: data['fullName']?.toString().trim() ?? singleName,
        edrpou: data['edrpou']?.toString().trim() ?? '',
      ),
    ];
  }

  Future<PaymentRequest> createFromInvoice({
    required String invoiceId,
    required double amount,
    String currency = 'UAH',
    required String purpose,
    required String supplierName,
  }) async {
    final data = await _postJson('/approvals/create-from-invoice', {
      'invoiceId': invoiceId,
      'amount': amount,
      'currency': currency,
      'purpose': purpose,
      'supplierName': supplierName,
    });

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    invalidateIncomingCache();
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentRequest> createManualRequest({
    required String orgCode,
    PaymentOperationType operationType = PaymentOperationType.supplierPayment,
    String? subdivisionUid,
    String? statementUid,
    String? cashboxUid,
    String? taxUid,
    required String vendorName,
    required String vendorCode,
    required double amount,
    String currency = 'UAH',
    required String purpose,
    required bool urgent,
    DateTime? desiredDate,
    String? requesterUid,
    String? requesterName,
    String? paymentForm,
    String? companyContacts,
    String? deliveryMethod,
    bool otherExpenses = false,
    List<ProjectSplitRow>? projectRows,
    PaymentRequestStatus? status,
  }) async {
    final normalizedPaymentForm = _normalizePaymentFormForCreate(paymentForm);
    final data = await _postJson(
      '/approvals/create-manual',
      {
        'orgCode': orgCode,
        'operationType': paymentOperationTypeToBackend(operationType),
        if (subdivisionUid != null && subdivisionUid.trim().isNotEmpty)
          'subdivision_uid': subdivisionUid.trim(),
        if (statementUid != null && statementUid.trim().isNotEmpty)
          'statementUid': statementUid.trim(),
        if (cashboxUid != null && cashboxUid.trim().isNotEmpty)
          'cashboxUid': cashboxUid.trim(),
        if (taxUid != null && taxUid.trim().isNotEmpty) 'taxUid': taxUid.trim(),
        'vendorName': vendorName,
        'vendorCode': vendorCode,
        'amount': amount,
        'currency': currency,
        'purpose': purpose,
        'urgent': urgent,
        if (desiredDate != null) 'desiredDate': desiredDate.toIso8601String(),
        if (requesterUid != null && requesterUid.isNotEmpty)
          'requester_uid': requesterUid,
        if (requesterName != null && requesterName.isNotEmpty)
          'requester_name': requesterName,
        if (normalizedPaymentForm != null)
          'payment_form': normalizedPaymentForm,
        if (companyContacts != null && companyContacts.trim().isNotEmpty)
          'companyContacts': companyContacts.trim(),
        if (deliveryMethod != null && deliveryMethod.trim().isNotEmpty)
          'deliveryMethod': deliveryMethod.trim(),
        'otherExpenses': otherExpenses,
        'projectRows': (projectRows ?? []).map((e) => e.toJson()).toList(),
        if (status != null) 'status': paymentStatusToBackend(status),
      },
    );

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    invalidateIncomingCache();
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentRequest> updateRequest({
    required String requestId,
    required String orgCode,
    PaymentOperationType operationType = PaymentOperationType.supplierPayment,
    String? subdivisionUid,
    String? statementUid,
    String? cashboxUid,
    String? taxUid,
    required String vendorName,
    required String vendorCode,
    required double amount,
    String currency = 'UAH',
    required String purpose,
    required bool urgent,
    DateTime? desiredDate,
    String? paymentForm,
    String? companyContacts,
    String? deliveryMethod,
    bool otherExpenses = false,
    List<ProjectSplitRow>? projectRows,
  }) async {
    final normalizedPaymentForm = _normalizePaymentFormForUpdate(paymentForm);
    final data = await _postJson(
      '/approvals/update-manual',
      {
        'id': requestId,
        'orgCode': orgCode,
        'operationType': paymentOperationTypeToBackend(operationType),
        if (subdivisionUid != null && subdivisionUid.trim().isNotEmpty)
          'subdivision_uid': subdivisionUid.trim(),
        'statementUid': statementUid?.trim() ?? '',
        'cashboxUid': cashboxUid?.trim() ?? '',
        'taxUid': taxUid?.trim() ?? '',
        'vendorName': vendorName,
        'vendorCode': vendorCode,
        'amount': amount,
        'currency': currency,
        'purpose': purpose,
        'urgent': urgent,
        if (desiredDate != null) 'desiredDate': desiredDate.toIso8601String(),
        if (normalizedPaymentForm != null)
          'payment_form': normalizedPaymentForm,
        if (companyContacts != null && companyContacts.trim().isNotEmpty)
          'companyContacts': companyContacts.trim(),
        if (deliveryMethod != null && deliveryMethod.trim().isNotEmpty)
          'deliveryMethod': deliveryMethod.trim(),
        'otherExpenses': otherExpenses,
        'projectRows': (projectRows ?? []).map((e) => e.toJson()).toList(),
      },
    );

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    invalidateIncomingCache();
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentRequest> changeStatus({
    required String requestId,
    required PaymentRequestStatus newStatus,
    String? comment,
  }) async {
    final data = await _postJson('/approvals/change-status', {
      'id': requestId,
      'status': paymentStatusToBackend(newStatus),
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    invalidateIncomingCache();
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<SalaryStatementOption>> getSalaryStatements({
    required String orgCode,
  }) async {
    final encodedOrgCode = Uri.encodeQueryComponent(orgCode);
    final data = await _getJson('/salary/statements?orgCode=$encodedOrgCode');
    if (data is! List) {
      throw Exception('Очікувався список відомостей, отримав: $data');
    }
    return data
        .map((e) => SalaryStatementOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<CashboxOption>> getCashboxes({
    required String orgCode,
  }) async {
    final encodedOrgCode = Uri.encodeQueryComponent(orgCode);
    final data = await _getJson('/cashboxes?orgCode=$encodedOrgCode');
    if (data is! List) {
      throw Exception('Очікувався список кас, отримав: $data');
    }
    return data
        .map((e) => CashboxOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TaxOption>> getTaxes() async {
    final data = await _getJson('/taxes');
    if (data is! List) {
      throw Exception('Очікувався список податків, отримав: $data');
    }
    return data
        .map((e) => TaxOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PaymentRequest> approveRequest(String requestId, {String? comment}) {
    return changeStatus(
      requestId: requestId,
      newStatus: PaymentRequestStatus.approved,
      comment: comment,
    );
  }

  Future<PaymentRequest> rejectRequest(String requestId, {String? comment}) {
    return changeStatus(
      requestId: requestId,
      newStatus: PaymentRequestStatus.rejected,
      comment: comment,
    );
  }

  Future<void> uploadAttachment({
    required String requestId,
    required File file,
    String? fileName,
  }) async {
    final bytes = await file.readAsBytes();
    await uploadAttachmentBytes(
      requestId: requestId,
      bytes: bytes,
      fileName: fileName ?? file.uri.pathSegments.last,
    );
  }

  Future<void> uploadAttachmentBytes({
    required String requestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final base64Data = base64Encode(bytes);

    final r = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/approvals/attachment/upload?id=$requestId',
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_name': fileName,
        'data_base64': base64Data,
      }),
    );

    final responseBody = utf8.decode(r.bodyBytes);

    if (r.statusCode != 200) {
      throw Exception(responseBody);
    }
  }

  Future<({Uint8List bytes, String contentType, String fileName})>
      downloadAttachment({
    required String fileUid,
  }) async {
    final encodedFileUid = Uri.encodeQueryComponent(fileUid);
    final r = await _apiClient.sendAuthorizedRequest(
      'GET',
      '/approvals/attachment/download?file_uid=$encodedFileUid',
    );

    if (r.statusCode != 200) {
      final responseBody = utf8.decode(r.bodyBytes);
      if (r.statusCode == 403) {
        throw Exception('Немає доступу до вкладення');
      }
      throw Exception(
        'Download failed HTTP ${r.statusCode}: $responseBody',
      );
    }

    final bytes = r.bodyBytes;

    final ct = (r.headers['content-type'] ?? 'application/octet-stream')
        .split(';')
        .first
        .trim();

    String fileName = 'attachment.bin';
    final cd = r.headers['content-disposition'];
    if (cd != null) {
      final m = RegExp(r'filename="([^"]+)"').firstMatch(cd);
      if (m != null && m.groupCount >= 1) {
        fileName = m.group(1)!;
      }
    }

    return (bytes: bytes, contentType: ct, fileName: fileName);
  }

  String? _normalizePaymentFormForCreate(String? paymentForm) {
    final value = paymentForm?.trim();
    if (value == null || value.isEmpty) return null;

    switch (value.toLowerCase()) {
      case 'form2':
      case 'cash':
        return 'cash';
      case 'form1':
      case 'cashless':
        return 'cashless';
      default:
        return value;
    }
  }

  String? _normalizePaymentFormForUpdate(String? paymentForm) {
    final value = paymentForm?.trim();
    if (value == null || value.isEmpty) return null;

    switch (value.toLowerCase()) {
      case 'cash':
      case 'form2':
        return 'Form2';
      case 'cashless':
      case 'form1':
        return 'Form1';
      default:
        return value;
    }
  }
}
