// lib/features/approvals/approvals_service.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import 'domain/payment_request.dart';

class ApprovalsService {
  final ApiClient _apiClient;

  ApprovalsService(this._apiClient);

  // ============ приватні утиліти ============

  Future<dynamic> _getJson(String endpoint) async {
    final http.Response r =
    await _apiClient.sendAuthorizedRequest('GET', endpoint);

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }

    // на всякий случай через bodyBytes, если будут не-UTF8 приколы
    final body = utf8.decode(r.bodyBytes);
    return jsonDecode(body);
  }

  Future<dynamic> _postJson(String endpoint, Map<String, dynamic> body) async {
    final http.Response r = await _apiClient.sendAuthorizedRequest(
      'POST',
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }

    final responseBody = utf8.decode(r.bodyBytes);
    return jsonDecode(responseBody);
  }

  // ============ публічне API для UI ============

  /// Мої заявки (історія запитів поточного користувача)
  Future<List<PaymentRequest>> getMyRequests() async {
    final data = await _getJson('/approvals/my-requests');

    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(PaymentRequest.fromJson)
        .toList();
  }

  /// Вхідні заявки на погодження (для користувача, який погоджує)
  Future<List<PaymentRequest>> getIncomingRequests() async {
    final data = await _getJson('/approvals/incoming');

    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }

    return data
        .cast<Map<String, dynamic>>()
        .map(PaymentRequest.fromJson)
        .toList();
  }

  /// Деталі однієї заявки по її ID
  ///
  /// Використовується при відкритті заявки з push-нотифікації.
  Future<PaymentRequest> getRequestById(String id) async {
    // TODO: якщо на бекенді інший endpoint — просто зміни рядок нижче
    final data = await _getJson('/approvals/by-id?id=$id');

    if (data is! Map<String, dynamic>) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }

    return PaymentRequest.fromJson(data);
  }

  /// Створення заявки на оплату на основі рахунку (інвойсу)
  ///
  /// [invoiceId]      – внутрішній ID рахунку в 1С
  /// [amount]         – сума
  /// [currency]       – валюта (наприклад, "UAH")
  /// [purpose]        – призначення платежу
  /// [supplierName]   – контрагент
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

    if (data is! Map<String, dynamic>) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }

    return PaymentRequest.fromJson(data);
  }

  /// Ручне створення заявки на оплату (з форми "Нова заявка")
  Future<PaymentRequest> createManualRequest({
    required String orgCode,
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
  }) async {
    final data = await _postJson('/approvals/create-manual', {
      'orgCode': orgCode,
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
      if (paymentForm != null && paymentForm.isNotEmpty)
        'payment_form': paymentForm,
    });

    if (data is! Map<String, dynamic>) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }

    return PaymentRequest.fromJson(data);
  }

  /// Зміна статусу заявки (погодити / відхилити / позначити як оплачено)
  ///
  /// [requestId] – ID заявки
  /// [newStatus] – новий статус
  /// [comment]   – необовʼязковий коментар
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

    return PaymentRequest.fromJson(data as Map<String, dynamic>);
  }

  /// Спеціальні зручні методи для UI

  Future<PaymentRequest> approveRequest(
      String requestId, {
        String? comment,
      }) {
    return changeStatus(
      requestId: requestId,
      newStatus: PaymentRequestStatus.approved,
      comment: comment,
    );
  }

  Future<PaymentRequest> rejectRequest(
      String requestId, {
        String? comment,
      }) {
    return changeStatus(
      requestId: requestId,
      newStatus: PaymentRequestStatus.rejected,
      comment: comment,
    );
  }
}
