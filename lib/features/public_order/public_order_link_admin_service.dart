import 'dart:convert';

import '../../api/api_client.dart';

class PublicOrderLinkInfo {
  const PublicOrderLinkInfo({
    required this.exists,
    required this.token,
    required this.active,
    required this.expirationDate,
    required this.partnerUid,
    required this.partnerName,
    required this.contractorName,
    required this.organizationName,
    required this.agreementUid,
    required this.agreementName,
    required this.warehouseName,
    required this.comment,
  });

  final bool exists;
  final String token;
  final bool active;
  final DateTime? expirationDate;
  final String partnerUid;
  final String partnerName;
  final String contractorName;
  final String organizationName;
  final String agreementUid;
  final String agreementName;
  final String warehouseName;
  final String comment;

  factory PublicOrderLinkInfo.fromJson(Map<String, dynamic> json) {
    return PublicOrderLinkInfo(
      exists: json['exists'] == true,
      token: json['token']?.toString() ?? '',
      active: json['active'] == true,
      expirationDate:
          DateTime.tryParse(json['expirationDate']?.toString() ?? ''),
      partnerUid: json['partnerUid']?.toString() ?? '',
      partnerName: json['partnerName']?.toString() ?? '',
      contractorName: json['contractorName']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      agreementUid: json['agreementUid']?.toString() ?? '',
      agreementName: json['agreementName']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class PublicOrderLinkAdminService {
  const PublicOrderLinkAdminService(this._apiClient);

  final ApiClient _apiClient;

  Future<PublicOrderLinkInfo> getByPartner(String partnerUid) async {
    final params = Uri(queryParameters: {'partnerUid': partnerUid}).query;
    final data = await _request('GET', '/sales/public-order-link?$params');
    return PublicOrderLinkInfo.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<PublicOrderLinkInfo> save({
    required String partnerUid,
    required String agreementUid,
    required DateTime expirationDate,
    required String comment,
    required bool regenerate,
  }) async {
    final data = await _request(
      'POST',
      regenerate
          ? '/sales/public-order-link/regenerate'
          : '/sales/public-order-link/save',
      body: {
        'partnerUid': partnerUid,
        'agreementUid': agreementUid,
        'expirationDate': _dateParam(expirationDate),
        'comment': comment.trim(),
      },
    );
    final result = PublicOrderLinkInfo.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
    if (result.token.trim().isEmpty) {
      throw const FormatException(
        'API не повернув токен. Посилання не було створено.',
      );
    }
    return result;
  }

  Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _apiClient.sendAuthorizedRequest(
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

String _dateParam(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
