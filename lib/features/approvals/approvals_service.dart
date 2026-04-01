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

class AttachmentDownloadResult {
  final Uint8List bytes;
  final String contentType;
  final String fileName;

  const AttachmentDownloadResult({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  bool get isImage {
    final ct = contentType.toLowerCase();
    return ct.startsWith('image/');
  }

  bool get isPdf {
    return contentType.toLowerCase() == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');
  }
}

class ApprovalsService {
  final ApiClient _apiClient;

  ApprovalsService(this._apiClient);

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

  Future<List<PaymentRequest>> getMyRequests() async {
    final data = await _getJson('/approvals/my-requests');
    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }
    return data
        .map((e) => PaymentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PaymentRequest>> getIncomingRequests() async {
    final data = await _getJson('/approvals/incoming');
    if (data is! List) {
      throw Exception('Очікувався список заявок, отримав: $data');
    }
    return data
        .map((e) => PaymentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PaymentRequest> getRequestById(String id) async {
    final data = await _getJson('/approvals/by-id?id=$id');
    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data as Map));
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
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data as Map));
  }

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
    String? companyContacts,
    String? deliveryMethod,
    String? subdivisionUid,
    bool otherExpenses = false,
    List<ProjectSplitRow>? projectRows,
  }) async {
    final data = await _postJson(
      '/approvals/create-manual',
      {
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
        if (companyContacts != null && companyContacts.trim().isNotEmpty)
          'companyContacts': companyContacts.trim(),
        if (deliveryMethod != null && deliveryMethod.trim().isNotEmpty)
          'deliveryMethod': deliveryMethod.trim(),
        if (subdivisionUid != null && subdivisionUid.trim().isNotEmpty)
          'subdivision_uid': subdivisionUid.trim(),
        'otherExpenses': otherExpenses,
        'projectRows': (projectRows ?? []).map((e) => e.toJson()).toList(),
      },
    );

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PaymentRequest> changeStatus({
    required String requestId,
    required PaymentRequestStatus newStatus,
    String? comment,
  }) async {
    final data = await _postJson('/approvals/change-status', {
      'id': requestId,
      'status': paymentStatusToBackend(newStatus),
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });

    if (data is! Map) {
      throw Exception('Очікувався обʼєкт заявки, отримав: $data');
    }
    return PaymentRequest.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PaymentRequest> approve({
    required String requestId,
    String? comment,
  }) {
    return changeStatus(
      requestId: requestId,
      newStatus: PaymentRequestStatus.approved,
      comment: comment,
    );
  }

  Future<PaymentRequest> reject({
    required String requestId,
    String? comment,
  }) {
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
    final base64Data = base64Encode(bytes);

    final r = await _apiClient.sendAuthorizedRequest(
      'POST',
      '/approvals/attachment/upload?id=$requestId',
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_name': fileName ?? file.uri.pathSegments.last,
        'data_base64': base64Data,
      }),
    );

    final responseBody = utf8.decode(r.bodyBytes);

    if (r.statusCode != 200) {
      throw Exception(responseBody);
    }
  }

  Future<AttachmentDownloadResult> downloadAttachment({
    required String requestId,
  }) async {
    final r = await _apiClient.sendAuthorizedRequest(
      'GET',
      '/approvals/attachment/download?id=$requestId',
    );

    if (r.statusCode != 200) {
      throw Exception(
        'Download failed HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}',
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

    return AttachmentDownloadResult(
      bytes: bytes,
      contentType: ct,
      fileName: fileName,
    );
  }
}