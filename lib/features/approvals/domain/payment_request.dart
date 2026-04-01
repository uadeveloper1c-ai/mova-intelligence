class PaymentAttachment {
  final String name;
  final String url;

  const PaymentAttachment({
    required this.name,
    required this.url,
  });

  factory PaymentAttachment.fromJson(Map<String, dynamic> json) {
    return PaymentAttachment(
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class PaymentRequest {
  final String id;
  final String number;
  final DateTime date;
  final String contractorName;
  final double amount;
  final String currency;
  final String purpose;
  final PaymentRequestStatus status;
  final String? approverName;
  final String? requesterName;
  final bool urgent;
  final PaymentForm paymentForm;
  final PaymentAttachment? attachment;

  const PaymentRequest({
    required this.id,
    required this.number,
    required this.date,
    required this.contractorName,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    this.approverName,
    this.requesterName,
    this.urgent = false,
    this.paymentForm = PaymentForm.unknown,
    this.attachment,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      date: _parseDate(json['date']),
      contractorName: (json['contractorName'] ?? '').toString(),
      amount: _parseDouble(json['amount']),
      currency: ((json['currency'] ?? 'UAH').toString()).toUpperCase(),
      purpose: (json['purpose'] ?? '').toString(),
      status: paymentStatusFromBackend((json['status'] ?? '').toString()),
      approverName: json['approverName']?.toString(),
      requesterName: json['requesterName']?.toString(),
      urgent: _parseBool(json['urgent']),
      paymentForm: paymentFormFromBackend(json['paymentForm']?.toString()),
      attachment: json['attachment'] is Map
          ? PaymentAttachment.fromJson(
        Map<String, dynamic>.from(json['attachment'] as Map),
      )
          : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value;

    final s = value.toString().trim();
    if (s.isEmpty) return DateTime.now();

    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value.toDouble();

    final s = value.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;

    final s = value.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }
}

enum PaymentRequestStatus {
  draft,
  pending,
  approvedByDepartmentHead,
  approved,
  rejected,
  topaid,
  paid,
}

enum PaymentForm {
  cash,
  cashless,
  unknown,
}

PaymentRequestStatus paymentStatusFromBackend(String value) {
  switch (value.trim()) {
    case 'Draft':
      return PaymentRequestStatus.draft;
    case 'Pending':
      return PaymentRequestStatus.pending;
    case 'ApprovedByDepartmentHead':
      return PaymentRequestStatus.approvedByDepartmentHead;
    case 'Approved':
      return PaymentRequestStatus.approved;
    case 'Rejected':
      return PaymentRequestStatus.rejected;
    case 'ToPaid':
      return PaymentRequestStatus.topaid;
    case 'Paid':
      return PaymentRequestStatus.paid;
    default:
      return PaymentRequestStatus.pending;
  }
}

String paymentStatusToBackend(PaymentRequestStatus status) {
  switch (status) {
    case PaymentRequestStatus.draft:
      return 'Draft';
    case PaymentRequestStatus.pending:
      return 'Pending';
    case PaymentRequestStatus.approvedByDepartmentHead:
      return 'ApprovedByDepartmentHead';
    case PaymentRequestStatus.approved:
      return 'Approved';
    case PaymentRequestStatus.rejected:
      return 'Rejected';
    case PaymentRequestStatus.topaid:
      return 'ToPaid';
    case PaymentRequestStatus.paid:
      return 'Paid';
  }
}

String paymentStatusHuman(PaymentRequestStatus status) {
  switch (status) {
    case PaymentRequestStatus.draft:
      return 'Чернетка';
    case PaymentRequestStatus.pending:
      return 'На погодженні';
    case PaymentRequestStatus.approvedByDepartmentHead:
      return 'Погоджено керівником';
    case PaymentRequestStatus.approved:
      return 'Погоджено';
    case PaymentRequestStatus.rejected:
      return 'Відхилено';
    case PaymentRequestStatus.topaid:
      return 'До оплати';
    case PaymentRequestStatus.paid:
      return 'Оплачено';
  }
}

PaymentForm paymentFormFromBackend(String? value) {
  switch ((value ?? '').trim()) {
    case 'cash':
    case 'Form2':
      return PaymentForm.cash;
    case 'cashless':
    case 'Form1':
      return PaymentForm.cashless;
    default:
      return PaymentForm.unknown;
  }
}