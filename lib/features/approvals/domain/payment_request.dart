class PaymentRequest {
  final String id;
  final String number;
  final DateTime date;
  final DateTime requestDate;
  final PaymentOperationType operationType;
  final String orgCode;
  final String contractorName;
  final String contractorCode;
  final double amount;
  final String currency;
  final String purpose;
  final PaymentRequestStatus status;
  final String? approverName;
  final String? requesterName;
  final String requesterUid;
  final String subdivisionUid;
  final String subdivisionName;
  final String statementUid;
  final String statementName;
  final String cashboxUid;
  final String cashboxName;
  final String taxUid;
  final String taxName;
  final bool urgent;
  final PaymentForm paymentForm;
  final List<PaymentRequestAttachment> attachments;
  final List<PaymentRequestPackageItem> paymentPackageItems;
  final double paymentPackageTotalAmount;

  const PaymentRequest({
    required this.id,
    required this.number,
    required this.date,
    required this.requestDate,
    this.operationType = PaymentOperationType.supplierPayment,
    this.orgCode = '',
    required this.contractorName,
    this.contractorCode = '',
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    this.approverName,
    this.requesterName,
    this.requesterUid = '',
    this.subdivisionUid = '',
    this.subdivisionName = '',
    this.statementUid = '',
    this.statementName = '',
    this.cashboxUid = '',
    this.cashboxName = '',
    this.taxUid = '',
    this.taxName = '',
    this.urgent = false,
    this.paymentForm = PaymentForm.unknown,
    this.attachments = const [],
    this.paymentPackageItems = const [],
    this.paymentPackageTotalAmount = 0,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    final paymentDate = _parseDate(json['date']);

    return PaymentRequest(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      date: paymentDate,
      requestDate: _parseDate(
        json['requestDate'] ??
            json['request_date'] ??
            json['createdDate'] ??
            json['documentDate'] ??
            json['document_date'] ??
            json['created_at'] ??
            json['dateCreated'] ??
            json['date_created'] ??
            json['docDate'] ??
            paymentDate,
      ),
      operationType: paymentOperationTypeFromBackend(
        _firstString(json, const [
          'operationType',
          'operation_type',
          'requestType',
          'request_type',
          'paymentType',
          'payment_type',
        ]),
      ),
      orgCode: _firstString(json, const [
        'orgCode',
        'org_code',
      ]),
      contractorName: (json['contractorName'] ?? '').toString(),
      contractorCode: _firstString(json, const [
        'contractorCode',
        'vendorCode',
        'edrpou',
        'edrpouCode',
        'supplierCode',
        'ЄДРПОУ',
        'КодЄДРПОУ',
      ]),
      amount: _parseDouble(json['amount']),
      currency: ((json['currency'] ?? 'UAH').toString()).toUpperCase(),
      purpose: (json['purpose'] ?? '').toString(),
      status: paymentStatusFromBackend((json['status'] ?? '').toString()),
      approverName: json['approverName']?.toString(),
      requesterName: json['requesterName']?.toString(),
      requesterUid: _firstString(json, const [
        'requesterUid',
        'requester_uid',
        'authorUid',
        'author_uid',
        'userUid',
        'createdByUid',
      ]),
      subdivisionUid: _firstString(json, const [
        'subdivisionUid',
        'subdivision_uid',
      ]),
      subdivisionName: _firstString(json, const [
        'subdivisionName',
        'subdivision_name',
        'name_subdivision',
        'subdivision',
      ]),
      statementUid: _firstString(json, const [
        'statementUid',
        'statement_uid',
      ]),
      statementName: _firstString(json, const [
        'statementName',
        'statement_name',
      ]),
      cashboxUid: _firstString(json, const [
        'cashboxUid',
        'cashbox_uid',
      ]),
      cashboxName: _firstString(json, const [
        'cashboxName',
        'cashbox_name',
      ]),
      taxUid: _firstString(json, const [
        'taxUid',
        'tax_uid',
      ]),
      taxName: _firstString(json, const [
        'taxName',
        'tax_name',
      ]),
      urgent: _parseBool(json['urgent']),
      paymentForm: paymentFormFromBackend(json['paymentForm']?.toString()),
      attachments: PaymentRequestAttachment.listFromJson(
        json['attachments'] ?? json['attachment'],
      ),
      paymentPackageItems: PaymentRequestPackageItem.listFromJson(
        json['paymentPackageItems'] ??
            json['payment_package_items'] ??
            json['packageItems'] ??
            json['package_items'],
      ),
      paymentPackageTotalAmount: _parseDouble(
        json['paymentPackageTotalAmount'] ??
            json['payment_package_total_amount'] ??
            json['packageTotalAmount'] ??
            json['package_total_amount'],
      ),
    );
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return '';
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

class PaymentRequestPackageItem {
  final String id;
  final String number;
  final bool isMain;
  final PaymentOperationType operationType;
  final PaymentRequestStatus status;
  final double amount;
  final String currency;
  final String contractorName;
  final String purpose;
  final String taxName;

  const PaymentRequestPackageItem({
    required this.id,
    required this.number,
    required this.isMain,
    required this.operationType,
    required this.status,
    required this.amount,
    required this.currency,
    required this.contractorName,
    required this.purpose,
    required this.taxName,
  });

  static PaymentRequestPackageItem? fromJson(dynamic value) {
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    return PaymentRequestPackageItem(
      id: (map['id'] ?? '').toString(),
      number: (map['number'] ?? '').toString(),
      isMain: PaymentRequest._parseBool(map['isMain'] ?? map['is_main']),
      operationType: paymentOperationTypeFromBackend(
        PaymentRequest._firstString(map, const [
          'operationType',
          'operation_type',
        ]),
      ),
      status: paymentStatusFromBackend((map['status'] ?? '').toString()),
      amount: PaymentRequest._parseDouble(map['amount']),
      currency: ((map['currency'] ?? 'UAH').toString()).toUpperCase(),
      contractorName: (map['contractorName'] ?? '').toString(),
      purpose: (map['purpose'] ?? '').toString(),
      taxName: PaymentRequest._firstString(map, const [
        'taxName',
        'tax_name',
      ]),
    );
  }

  static List<PaymentRequestPackageItem> listFromJson(dynamic value) {
    if (value is! List) return const [];

    return value
        .map(fromJson)
        .whereType<PaymentRequestPackageItem>()
        .toList(growable: false);
  }
}

class PaymentRequestAttachment {
  final String uid;
  final String name;
  final String? url;

  const PaymentRequestAttachment({
    required this.uid,
    required this.name,
    this.url,
  });

  static PaymentRequestAttachment? fromJson(dynamic value) {
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    final uid = PaymentRequest._firstString(map, const [
      'uid',
      'file_uid',
      'fileUid',
      'attachment_uid',
      'attachmentUid',
      'id',
    ]);
    final name = PaymentRequest._firstString(map, const [
      'name',
      'file_name',
      'fileName',
      'filename',
    ]);
    final urlRaw = (map['url'] ?? map['download_url'] ?? map['downloadUrl'])
        ?.toString()
        .trim();

    if (uid.isEmpty && name.isEmpty && (urlRaw == null || urlRaw.isEmpty)) {
      return null;
    }

    return PaymentRequestAttachment(
      uid: uid,
      name: name.isEmpty ? 'Вкладення' : name,
      url: (urlRaw == null || urlRaw.isEmpty) ? null : urlRaw,
    );
  }

  static List<PaymentRequestAttachment> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .map(fromJson)
          .whereType<PaymentRequestAttachment>()
          .toList(growable: false);
    }

    final single = fromJson(value);
    if (single == null) return const [];
    return [single];
  }
}

enum PaymentRequestStatus {
  preliminary,
  draft,
  pending,
  approvedByDepartmentHead,
  approvedByFinanceDirector,
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

enum PaymentOperationType {
  supplierPayment,
  otherExpenses,
  salaryPayment,
  taxPayment,
}

PaymentRequestStatus paymentStatusFromBackend(String value) {
  switch (value.trim().toLowerCase()) {
    case 'preliminary':
    case 'предварительная':
    case 'попередня':
      return PaymentRequestStatus.preliminary;
    case 'draft':
      return PaymentRequestStatus.draft;
    case 'pending':
    case 'несогласована':
    case 'несогласованная':
    case 'не согласована':
    case 'не согласованная':
    case 'непогоджена':
    case 'не погоджена':
      return PaymentRequestStatus.pending;
    case 'approvedbydepartmenthead':
    case 'согласованаруководителемподразделения':
    case 'погодженокерівником':
      return PaymentRequestStatus.approvedByDepartmentHead;
    case 'approvedbyfinancedirector':
    case 'согласованафинансовымдиректором':
    case 'погодженофінансовимдиректором':
      return PaymentRequestStatus.approvedByFinanceDirector;
    case 'approved':
      return PaymentRequestStatus.approved;
    case 'rejected':
    case 'rejectedbyauthor':
    case 'відхилено':
    case 'отклонена':
    case 'відхилена':
    case 'отклонено':
      return PaymentRequestStatus.rejected;
    case 'topaid':
      return PaymentRequestStatus.topaid;
    case 'paid':
    case 'оплачено':
      return PaymentRequestStatus.paid;
    default:
      return PaymentRequestStatus.pending;
  }
}

String paymentStatusToBackend(PaymentRequestStatus status) {
  switch (status) {
    case PaymentRequestStatus.preliminary:
      return 'Preliminary';
    case PaymentRequestStatus.draft:
      return 'Draft';
    case PaymentRequestStatus.pending:
      return 'Pending';
    case PaymentRequestStatus.approvedByDepartmentHead:
      return 'ApprovedByDepartmentHead';
    case PaymentRequestStatus.approvedByFinanceDirector:
      return 'ApprovedByFinanceDirector';
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
    case PaymentRequestStatus.preliminary:
      return 'Попередня';
    case PaymentRequestStatus.draft:
      return 'Чернетка';
    case PaymentRequestStatus.pending:
      return 'На погодженні';
    case PaymentRequestStatus.approvedByDepartmentHead:
      return 'Погоджено керівником';
    case PaymentRequestStatus.approvedByFinanceDirector:
      return 'Погоджено CFO';
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

PaymentOperationType paymentOperationTypeFromBackend(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'supplier_payment':
    case 'supplierpayment':
    case 'supplier':
    case 'оплатапостачальнику':
    case 'оплатапоставщику':
      return PaymentOperationType.supplierPayment;
    case 'other_expenses':
    case 'otherexpenses':
    case 'other':
    case 'іншівитрати':
    case 'иншиерасходы':
    case 'прочиерасходы':
      return PaymentOperationType.otherExpenses;
    case 'salary_payment':
    case 'salarypayment':
    case 'salary':
    case 'виплатазарплати':
    case 'выплатазарплаты':
      return PaymentOperationType.salaryPayment;
    case 'tax_payment':
    case 'taxpayment':
    case 'tax':
    case 'уплатаподатків':
    case 'уплатаналогов':
      return PaymentOperationType.taxPayment;
    default:
      return PaymentOperationType.supplierPayment;
  }
}

String paymentOperationTypeToBackend(PaymentOperationType type) {
  switch (type) {
    case PaymentOperationType.supplierPayment:
      return 'supplier_payment';
    case PaymentOperationType.otherExpenses:
      return 'other_expenses';
    case PaymentOperationType.salaryPayment:
      return 'salary_payment';
    case PaymentOperationType.taxPayment:
      return 'tax_payment';
  }
}

String paymentOperationTypeHuman(PaymentOperationType type) {
  switch (type) {
    case PaymentOperationType.supplierPayment:
      return 'Оплата постачальнику';
    case PaymentOperationType.otherExpenses:
      return 'Інші витрати';
    case PaymentOperationType.salaryPayment:
      return 'Виплата зарплати';
    case PaymentOperationType.taxPayment:
      return 'Уплата податків';
  }
}
