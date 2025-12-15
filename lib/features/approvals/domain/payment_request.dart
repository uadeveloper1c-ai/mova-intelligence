// lib/features/approvals/domain/payment_request.dart

enum PaymentRequestStatus {
  draft,      // чернетка
  pending,    // на погодженні
  approved,   // погоджено
  rejected,   // відхилено
  topaid,     // до оплати (КОплате)
  paid,       // оплачено
}

PaymentRequestStatus paymentStatusFromBackend(String value) {
  switch (value) {
    case 'Draft':
    case 'Черновик':
      return PaymentRequestStatus.draft;

    case 'Pending':
    case 'НаСогласовании':
      return PaymentRequestStatus.pending;

    case 'Approved':
    case 'Согласовано':
      return PaymentRequestStatus.approved;

    case 'Rejected':
    case 'Отклонено':
      return PaymentRequestStatus.rejected;

  // до оплати
    case 'ToPaid':
    case 'КОплате':
      return PaymentRequestStatus.topaid;

  // уже оплачено
    case 'Paid':
    case 'Оплачено':
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
    case PaymentRequestStatus.approved:
      return 'Approved';
    case PaymentRequestStatus.rejected:
      return 'Rejected';
    case PaymentRequestStatus.topaid:
      return 'ToPaid'; // или "КОплате", если на стороне 1С так принято
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

/// Толерантний парсер дати з бекенду.
/// Підтримує:
///  - ISO (2025-12-09T00:00:00 / 2025-12-09)
///  - dd.MM.yyyy (09.12.2025)
DateTime _parseBackendDate(dynamic raw) {
  if (raw is DateTime) return raw;

  final s = (raw ?? '').toString().trim();
  if (s.isEmpty) {
    // якщо дати немає – просто зараз
    return DateTime.now();
  }

  // 1) пробуємо стандартний ISO-парсер
  try {
    return DateTime.parse(s);
  } catch (_) {
    // ignore
  }

  // 2) пробуємо формат dd.MM.yyyy (можливо з часом після пробілу)
  final partsDot = s.split('.');
  if (partsDot.length == 3) {
    final day = int.tryParse(partsDot[0]);
    final month = int.tryParse(partsDot[1]);

    // третя частина може бути "yyyy" або "yyyy HH:MM..."
    final yearStr = partsDot[2].split(' ').first;
    final year = int.tryParse(yearStr);

    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  // Якщо нічого не вийшло – не валимо UI, просто повертаємо now().
  // При бажанні можна залогувати це окремо.
  return DateTime.now();
}

class PaymentRequest {
  final String id;            // внутрішній ID
  final String number;        // номер заявки
  final DateTime date;        // дата створення
  final String requesterName; // хто просить
  final String approverName;  // хто погоджує
  final double amount;        // сума
  final String currency;      // валюта
  final String purpose;       // призначення платежу
  final PaymentRequestStatus status;
  final String contractorName;

  PaymentRequest({
    required this.id,
    required this.number,
    required this.date,
    required this.requesterName,
    required this.approverName,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    this.contractorName = '',
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: json['id'] as String,
      number: json['number'] as String,
      date: _parseBackendDate(json['date']),
      requesterName: json['requesterName'] as String? ?? '',
      approverName: json['approverName'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'UAH',
      purpose: json['purpose'] as String? ?? '',
      status: paymentStatusFromBackend(json['status'] as String),
      contractorName: json['contractorName'] as String? ?? '',
    );
  }
}
