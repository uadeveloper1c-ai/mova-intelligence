import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/api_client.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';
import 'package:mova_intelligence_app/features/approvals/approvals_service.dart';
import 'package:mova_intelligence_app/features/approvals/domain/payment_request.dart';

enum RequestFormMode { create, edit, copy }

class NewRequestPage extends StatefulWidget {
  final PaymentRequest? initial;
  final RequestFormMode mode;

  const NewRequestPage({
    super.key,
    this.initial,
    this.mode = RequestFormMode.create,
  });

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController();
  final _vendorCodeCtrl = TextEditingController();
  final _companyContactsCtrl = TextEditingController();

  bool _urgent = false;
  PaymentOperationType _operationType = PaymentOperationType.supplierPayment;

  String? _orgCode;
  List<_OrgUiData> _orgs = [];
  String? _subdivisionUid;
  List<_SubdivisionUiData> _subdivisions = [];
  DateTime? _desiredDate;
  String? _statementUid;
  String? _cashboxUid;
  String? _taxUid;
  List<SalaryStatementOption> _statements = [];
  List<CashboxOption> _cashboxes = [];
  List<TaxOption> _taxes = [];
  bool _loadingSalaryMeta = false;
  String? _salaryMetaError;
  String? _taxMetaError;

  String? _paymentForm;

  String? _requesterUid;
  String? _requesterName;

  bool _sending = false;
  bool _loadingOrgMeta = false;
  String? _error;

  bool _showProjectRows = false;
  final List<_ProjectRowData> _projectRows = [];

  List<_DeliveryMethodOption> _deliveryMethods = [];
  String? _deliveryMethodCode;

  final _imagePicker = ImagePicker();
  bool _attachmentBusy = false;
  final List<_PendingAttachment> _attachments = [];

  Timer? _edrpouDebounce;
  bool _edrpouLookupBusy = false;
  String? _lastEdrpouLookupValue;
  String? _selectedContractorUid;
  bool _contractorSelectionConfirmed = false;
  bool _initialApplied = false;

  bool get _isEdit => widget.mode == RequestFormMode.edit;
  bool get _isCopy => widget.mode == RequestFormMode.copy;
  bool get _isSupplierPayment =>
      _operationType == PaymentOperationType.supplierPayment;
  bool get _isOtherExpenses =>
      _operationType == PaymentOperationType.otherExpenses;
  bool get _isSalaryPayment =>
      _operationType == PaymentOperationType.salaryPayment;
  bool get _isTaxPayment => _operationType == PaymentOperationType.taxPayment;

  String get _pageTitle {
    switch (widget.mode) {
      case RequestFormMode.create:
        return 'Нова заявка';
      case RequestFormMode.edit:
        return 'Редагування заявки';
      case RequestFormMode.copy:
        return 'Копія заявки';
    }
  }

  String get _submitLabel {
    switch (widget.mode) {
      case RequestFormMode.create:
        return 'Відправити заявку';
      case RequestFormMode.edit:
        return 'Зберегти зміни';
      case RequestFormMode.copy:
        return 'Створити копію';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSessionAndMe();
    _applyInitialRequestIfNeeded();
  }

  void _applyInitialRequestIfNeeded() {
    if (_initialApplied || widget.initial == null) return;

    final r = widget.initial!;
    final dynamic a = r;

    if (_isCopy) {
      _attachments.clear();
    }

    _orgCode ??= _tryString(() => a.orgCode);
    _vendorNameCtrl.text =
        _tryString(() => a.contractorName) ?? _vendorNameCtrl.text;
    _vendorCodeCtrl.text = _tryString(() => a.contractorCode) ??
        _tryString(() => a.vendorCode) ??
        _tryString(() => a.edrpou) ??
        _tryString(() => a.edrpouCode) ??
        _tryString(() => a.supplierCode) ??
        _vendorCodeCtrl.text;
    _contractorSelectionConfirmed = _vendorNameCtrl.text.trim().isNotEmpty &&
        _vendorCodeCtrl.text.trim().isNotEmpty;
    _companyContactsCtrl.text =
        _tryString(() => a.companyContacts) ?? _companyContactsCtrl.text;
    _amountCtrl.text = _formatAmountForInput(r.amount);
    _purposeCtrl.text = _tryString(() => a.purpose) ?? _purposeCtrl.text;
    _urgent = _tryBool(() => a.urgent) ?? _urgent;
    _operationType = r.operationType;
    final legacyOtherExpenses = _tryBool(() => a.otherExpenses) ?? false;
    if (legacyOtherExpenses) {
      _operationType = PaymentOperationType.otherExpenses;
    }
    _desiredDate = _tryDate(() => a.desiredDate) ?? _desiredDate;
    _deliveryMethodCode =
        _tryString(() => a.deliveryMethod) ?? _deliveryMethodCode;
    _subdivisionUid ??= _tryString(() => a.subdivisionUid) ?? _subdivisionUid;
    _statementUid ??= _tryString(() => a.statementUid) ?? _statementUid;
    _cashboxUid ??= _tryString(() => a.cashboxUid) ?? _cashboxUid;
    _taxUid ??= _tryString(() => a.taxUid) ?? _taxUid;
    _paymentForm ??= _paymentFormToBackend(r.paymentForm);

    final rows = _tryProjectRows(() => a.projectRows);
    if (rows.isNotEmpty) {
      _projectRows.clear();
      _projectRows.addAll(rows);
      _showProjectRows = true;
    }

    _initialApplied = true;
  }

  String _formatAmountForInput(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatAmountLabel(double value) {
    final rounded =
        value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    final parts = rounded.split('.');
    final chars = parts.first.split('').reversed.toList();
    final grouped = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) grouped.add(' ');
      grouped.add(chars[i]);
    }
    final whole = grouped.reversed.join();
    return parts.length > 1 ? '$whole.${parts.last}' : whole;
  }

  String? _tryString(dynamic Function() getter) {
    try {
      final v = getter();
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  bool? _tryBool(dynamic Function() getter) {
    try {
      final v = getter();
      if (v is bool) return v;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'так') return true;
        if (s == 'false' || s == '0' || s == 'ні') return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _tryDate(dynamic Function() getter) {
    try {
      final v = getter();
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  List<_ProjectRowData> _tryProjectRows(dynamic Function() getter) {
    try {
      final raw = getter();
      if (raw is! Iterable) return const [];

      return raw.map<_ProjectRowData>((e) {
        final dynamic row = e;
        final orgCode = _tryString(() => row.orgCode) ??
            _tryString(() => row.organizationCode) ??
            '';
        final amount = (() {
          try {
            final v = row.amount;
            if (v is num) {
              return v.toDouble().toString();
            }
            return v.toString();
          } catch (_) {
            return '';
          }
        })();

        return _ProjectRowData(
          orgCode: orgCode.isEmpty ? null : orgCode,
          amount: amount,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  String _paymentFormToBackend(PaymentForm form) {
    switch (form) {
      case PaymentForm.cash:
        return 'Form2';
      case PaymentForm.cashless:
        return 'Form1';
      case PaymentForm.unknown:
        return 'Form1';
    }
  }

  Future<void> _loadSessionAndMe() async {
    setState(() => _loadingOrgMeta = true);

    try {
      final session = await SessionStore.loadSession();

      if (!mounted) return;

      _requesterUid = session?.userUid ?? session?.token;
      _requesterName = session?.fullName;
      _paymentForm ??= 'Form1';

      final fallbackOrgs = (session?.orgs ?? const <OrgAccess>[])
          .map(
            (o) => _OrgUiData(
              code: o.code,
              name: o.name,
              deliveryMethods: const [],
              defaultDeliveryCode: null,
            ),
          )
          .toList();
      final fallbackSubdivisions =
          (session?.subdivisions ?? const <SubdivisionAccess>[])
              .map(
                (s) => _SubdivisionUiData(
                  uid: s.uid,
                  name: s.name,
                ),
              )
              .where((s) => s.uid.isNotEmpty)
              .toList();

      setState(() {
        _orgs = fallbackOrgs;
        _subdivisions = fallbackSubdivisions;
        if (_orgCode == null && _orgs.isNotEmpty) {
          _orgCode = _orgs.first.code;
        }
        _subdivisionUid = _resolveSubdivisionSelection(
          current: _subdivisionUid,
          defaultUid: session?.defaultSubdivisionUid,
          items: _subdivisions,
        );
      });

      final api = context.read<ApiClient>();
      final me = await api.getMe();

      if (!mounted) return;

      if (me != null) {
        final orgsRaw = me['orgs'] as List<dynamic>? ?? const [];
        final parsed = orgsRaw
            .map(
                (e) => _OrgUiData.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.code.isNotEmpty)
            .toList();

        if (parsed.isNotEmpty) {
          setState(() {
            _orgs = parsed;
            final exists = _orgs.any((o) => o.code == _orgCode);
            if (!exists) {
              _orgCode = _orgs.first.code;
            }
          });
        }

        final subdivisionsRaw =
            me['subdivisions'] as List<dynamic>? ?? const [];
        final parsedSubdivisions = subdivisionsRaw
            .map(
              (e) => _SubdivisionUiData.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .where((e) => e.uid.isNotEmpty)
            .toList();
        final defaultSubdivisionUid = me['defaultSubdivision']?.toString() ??
            me['defaultsubdivision']?.toString();

        setState(() {
          _subdivisions = parsedSubdivisions;
          _subdivisionUid = _resolveSubdivisionSelection(
            current: _subdivisionUid,
            defaultUid: defaultSubdivisionUid,
            items: _subdivisions,
          );
        });
      }

      _applyInitialRequestIfNeeded();
      _syncDeliveryMethodsByOrg();
      unawaited(_syncOperationTypeMeta());
    } catch (e) {
      debugPrint('NewRequestPage _loadSessionAndMe error: $e');
      _applyInitialRequestIfNeeded();
      _syncDeliveryMethodsByOrg();
      unawaited(_syncOperationTypeMeta());
    } finally {
      if (mounted) {
        setState(() => _loadingOrgMeta = false);
      }
    }
  }

  void _syncDeliveryMethodsByOrg() {
    final selected =
        _orgs.where((o) => o.code == _orgCode).cast<_OrgUiData?>().firstOrNull;
    final methods =
        selected?.deliveryMethods ?? const <_DeliveryMethodOption>[];
    final defaultCode = selected?.defaultDeliveryCode;

    String? nextCode;
    if (methods.isEmpty) {
      nextCode = null;
    } else if (defaultCode != null &&
        defaultCode.isNotEmpty &&
        methods.any((m) => m.code == defaultCode)) {
      nextCode = defaultCode;
    } else if (_deliveryMethodCode != null &&
        methods.any((m) => m.code == _deliveryMethodCode)) {
      nextCode = _deliveryMethodCode;
    } else {
      nextCode = methods.first.code;
    }

    if (!mounted) return;
    setState(() {
      _deliveryMethods = methods;
      _deliveryMethodCode = nextCode;
    });
  }

  String get _selectedOrgName {
    final code = _orgCode?.trim() ?? '';
    if (code.isEmpty) return '';

    final selected = _orgs.where((o) => o.code == code).firstOrNull;
    return selected?.name.trim().isNotEmpty == true ? selected!.name : code;
  }

  Future<void> _syncOperationTypeMeta() async {
    if (!mounted) return;

    if (_isSalaryPayment) {
      await _loadSalaryMeta();
      return;
    }

    if (_isTaxPayment) {
      await _loadTaxes();
      return;
    }
  }

  Future<void> _loadSalaryMeta() async {
    final orgCode = _orgCode?.trim();
    if (orgCode == null || orgCode.isEmpty) return;

    setState(() {
      _loadingSalaryMeta = true;
      _salaryMetaError = null;
    });
    try {
      final approvals = context.read<ApprovalsService>();
      final results = await Future.wait([
        approvals.getSalaryStatements(orgCode: orgCode),
        approvals.getCashboxes(orgCode: orgCode),
      ]);

      if (!mounted) return;

      final statements = results[0] as List<SalaryStatementOption>;
      final cashboxes = results[1] as List<CashboxOption>;

      setState(() {
        _statements = statements;
        _cashboxes = cashboxes;
        _salaryMetaError = null;

        if (!_statements.any((s) => s.uid == _statementUid)) {
          _statementUid = _statements.isNotEmpty ? _statements.first.uid : null;
        }
        if (!_cashboxes.any((c) => c.uid == _cashboxUid)) {
          _cashboxUid = _cashboxes.isNotEmpty ? _cashboxes.first.uid : null;
        }
      });

      _applyStatementDefaults();
    } catch (e) {
      debugPrint('Load salary meta error: $e');
      if (!mounted) return;
      setState(() {
        _statements = const [];
        _cashboxes = const [];
        _salaryMetaError = 'Не вдалося завантажити відомості або каси';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSalaryMeta = false);
      }
    }
  }

  Future<void> _loadTaxes() async {
    setState(() {
      _loadingSalaryMeta = true;
      _taxMetaError = null;
    });
    try {
      final approvals = context.read<ApprovalsService>();
      final taxes = await approvals.getTaxes();
      if (!mounted) return;
      setState(() {
        _taxes = taxes;
        _taxMetaError = null;
        if (!_taxes.any((t) => t.uid == _taxUid)) {
          _taxUid = _taxes.isNotEmpty ? _taxes.first.uid : null;
        }
      });
    } catch (e) {
      debugPrint('Load taxes error: $e');
      if (!mounted) return;
      setState(() {
        _taxes = const [];
        _taxMetaError = 'Не вдалося завантажити перелік податків';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSalaryMeta = false);
      }
    }
  }

  void _applyStatementDefaults({bool forceAmount = false}) {
    if (!_isSalaryPayment) return;

    final selected =
        _statements.where((s) => s.uid == _statementUid).firstOrNull;
    if (selected == null) return;

    if (selected.subdivisionUid.isNotEmpty &&
        _subdivisions.any((s) => s.uid == selected.subdivisionUid)) {
      setState(() {
        _subdivisionUid = selected.subdivisionUid;
      });
    }

    if ((forceAmount || _amountCtrl.text.trim().isEmpty) &&
        selected.amount > 0) {
      setState(() {
        _amountCtrl.text = _formatAmountForInput(selected.amount);
      });
    }
  }

  String? _resolveSubdivisionSelection({
    required String? current,
    required String? defaultUid,
    required List<_SubdivisionUiData> items,
  }) {
    if (items.isEmpty) return null;

    final trimmedCurrent = current?.trim();
    if (trimmedCurrent != null &&
        trimmedCurrent.isNotEmpty &&
        items.any((s) => s.uid == trimmedCurrent)) {
      return trimmedCurrent;
    }

    final trimmedDefault = defaultUid?.trim();
    if (trimmedDefault != null &&
        trimmedDefault.isNotEmpty &&
        items.any((s) => s.uid == trimmedDefault)) {
      return trimmedDefault;
    }

    return items.first.uid;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _vendorNameCtrl.dispose();
    _vendorCodeCtrl.dispose();
    _companyContactsCtrl.dispose();
    _edrpouDebounce?.cancel();

    for (final row in _projectRows) {
      row.dispose();
    }

    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDesiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _desiredDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Виберіть бажану дату платежу',
      cancelText: 'Скасувати',
      confirmText: 'Готово',
    );

    if (picked != null) {
      setState(() => _desiredDate = picked);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _attachmentBusy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        withReadStream: kIsWeb,
        allowMultiple: true,
      );
      if (res == null || res.files.isEmpty) return;

      final picked = <_PendingAttachment>[];
      for (final f in res.files) {
        File? file;
        if (!kIsWeb && f.path != null) {
          file = File(f.path!);
        }

        final lower = f.name.toLowerCase();
        final isImage = lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp');

        Uint8List? bytes;
        if (kIsWeb || isImage) {
          bytes = await _readPickedFileBytes(f, file);
        }

        if (file == null && bytes == null) continue;

        picked.add(
          _PendingAttachment(
            file: file,
            bytes: bytes,
            fileName: f.name,
            previewBytes: isImage ? bytes : null,
          ),
        );
      }

      if (picked.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося прочитати вибраний файл у браузері.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _attachments.addAll(picked);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося додати файл: $e')),
      );
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile f, File? file) async {
    final directBytes = f.bytes;
    if (directBytes != null) return directBytes;

    final stream = f.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    if (file != null) {
      return file.readAsBytes();
    }

    return null;
  }

  Future<void> _pickPhoto(ImageSource src) async {
    setState(() => _attachmentBusy = true);
    try {
      final x = await _imagePicker.pickImage(source: src, imageQuality: 92);
      if (x == null) return;

      final file = File(x.path);
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _attachments.add(
          _PendingAttachment(
            file: file,
            fileName: x.name,
            previewBytes: bytes,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _removeAttachment(_PendingAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }

  void _setOperationType(PaymentOperationType? value) {
    if (value == null || value == _operationType) return;

    setState(() {
      _operationType = value;
      if (!_isSupplierPayment) {
        _showProjectRows = false;
      }
      if (!_isSalaryPayment) {
        _statementUid = null;
        _cashboxUid = null;
      }
      if (!_isTaxPayment) {
        _taxUid = null;
      }
    });

    unawaited(_syncOperationTypeMeta());
  }

  void _applyExpensesSupplierCode() {
    _vendorCodeCtrl.text = '11111111';
    _onVendorCodeChanged('11111111');
  }

  void _toggleProjectRows() {
    setState(() {
      _showProjectRows = !_showProjectRows;
      if (_showProjectRows && _projectRows.isEmpty) {
        _projectRows.add(_ProjectRowData(orgCode: _orgCode));
      }
    });
  }

  void _addProjectRow() {
    setState(() {
      _projectRows.add(_ProjectRowData(orgCode: _orgCode));
    });
  }

  void _removeProjectRow(int index) {
    setState(() {
      _projectRows[index].dispose();
      _projectRows.removeAt(index);
      if (_projectRows.isEmpty) {
        _showProjectRows = false;
      }
    });
  }

  void _onVendorCodeChanged(String rawValue) {
    final digitsOnly = rawValue.replaceAll(RegExp(r'[^0-9]'), '');

    if (_vendorCodeCtrl.text != digitsOnly) {
      _vendorCodeCtrl.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    }

    if (_selectedContractorUid != null || _contractorSelectionConfirmed) {
      _selectedContractorUid = null;
      _contractorSelectionConfirmed = false;
    }

    _edrpouDebounce?.cancel();

    if (digitsOnly.length != 8 && digitsOnly.length != 10) {
      if (mounted) {
        setState(() {
          _edrpouLookupBusy = false;
        });
      }
      return;
    }

    _edrpouDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      if (_lastEdrpouLookupValue == digitsOnly &&
          _vendorNameCtrl.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        _edrpouLookupBusy = true;
      });

      try {
        final approvals = context.read<ApprovalsService>();
        final foundName = await approvals.getContractorByEdrpou(digitsOnly);

        if (!mounted) return;

        _lastEdrpouLookupValue = digitsOnly;

        if (foundName != null && foundName.trim().isNotEmpty) {
          _vendorNameCtrl.text = foundName.trim();
          _contractorSelectionConfirmed = true;
          _selectedContractorUid = null;
        }
      } catch (e) {
        debugPrint('EDRPOU lookup error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _edrpouLookupBusy = false;
          });
        }
      }
    });
  }

  Future<void> _searchContractorByName() async {
    final selected = await showModalBottomSheet<ContractorLookupOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _ContractorSearchSheet(
        initialQuery: _vendorNameCtrl.text.trim(),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _vendorNameCtrl.text = selected.name;
      if (selected.edrpou.trim().isNotEmpty) {
        _vendorCodeCtrl.text = selected.edrpou.trim();
      }
      _selectedContractorUid =
          selected.uid.trim().isEmpty ? null : selected.uid;
      _contractorSelectionConfirmed = true;
    });

    if (selected.edrpou.trim().isNotEmpty) {
      _onVendorCodeChanged(selected.edrpou.trim());
    }
  }

  String? _validateProjectRows() {
    if (!_showProjectRows) return null;

    for (final row in _projectRows) {
      final org = row.orgCode?.trim() ?? '';
      final amountText = row.amountCtrl.text.trim().replaceAll(',', '.');

      if (org.isEmpty) {
        return 'У таблиці "По проектах" виберіть організацію в кожному рядку';
      }

      final parsed = double.tryParse(amountText);
      if (parsed == null || parsed <= 0) {
        return 'У таблиці "По проектах" вкажіть коректну суму в кожному рядку';
      }
    }

    return null;
  }

  List<ProjectSplitRow> _buildProjectRowsForSubmit() {
    if (!_showProjectRows) return const [];

    return _projectRows
        .where((row) {
          final org = row.orgCode?.trim() ?? '';
          final amountText = row.amountCtrl.text.trim();
          return org.isNotEmpty && amountText.isNotEmpty;
        })
        .map(
          (row) => ProjectSplitRow(
            orgCode: row.orgCode!.trim(),
            amount: double.parse(
              row.amountCtrl.text.trim().replaceAll(',', '.'),
            ),
          ),
        )
        .toList();
  }

  Future<void> _submit({PaymentRequestStatus? createStatus}) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_orgCode == null) {
      setState(() => _error = 'Виберіть організацію');
      return;
    }

    final projectRowsError = _validateProjectRows();
    if (projectRowsError != null) {
      setState(() => _error = projectRowsError);
      return;
    }

    if (_isSalaryPayment && (_statementUid == null || _statementUid!.isEmpty)) {
      setState(() => _error = 'Оберіть відомість');
      return;
    }

    if (_isSalaryPayment && (_cashboxUid == null || _cashboxUid!.isEmpty)) {
      setState(() => _error = 'Оберіть касу');
      return;
    }

    if (_isTaxPayment && (_taxUid == null || _taxUid!.isEmpty)) {
      setState(() => _error = 'Оберіть податок');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final approvals = context.read<ApprovalsService>();
      final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));
      final projectRows = _isSupplierPayment
          ? _buildProjectRowsForSubmit()
          : const <ProjectSplitRow>[];
      final vendorName = _isSupplierPayment ? _vendorNameCtrl.text.trim() : '';
      final vendorCode = _isSupplierPayment ? _vendorCodeCtrl.text.trim() : '';
      final companyContacts =
          _isSupplierPayment ? _companyContactsCtrl.text.trim() : '';
      final deliveryMethod = _isSupplierPayment ? _deliveryMethodCode : null;
      final otherExpenses = _isOtherExpenses;

      late final PaymentRequest saved;

      if (_isEdit && widget.initial != null) {
        saved = await approvals.updateRequest(
          requestId: widget.initial!.id,
          orgCode: _orgCode!,
          operationType: _operationType,
          subdivisionUid: _subdivisionUid,
          statementUid: _isSalaryPayment ? _statementUid : null,
          cashboxUid: _isSalaryPayment ? _cashboxUid : null,
          taxUid: _isTaxPayment ? _taxUid : null,
          vendorName: vendorName,
          vendorCode: vendorCode,
          amount: amount,
          currency: 'UAH',
          purpose: _purposeCtrl.text.trim(),
          urgent: _urgent,
          desiredDate: _desiredDate,
          paymentForm: _paymentForm,
          companyContacts: companyContacts,
          deliveryMethod: deliveryMethod,
          otherExpenses: otherExpenses,
          projectRows: projectRows,
        );
      } else {
        saved = await approvals.createManualRequest(
          orgCode: _orgCode!,
          operationType: _operationType,
          subdivisionUid: _subdivisionUid,
          statementUid: _isSalaryPayment ? _statementUid : null,
          cashboxUid: _isSalaryPayment ? _cashboxUid : null,
          taxUid: _isTaxPayment ? _taxUid : null,
          vendorName: vendorName,
          vendorCode: vendorCode,
          amount: amount,
          currency: 'UAH',
          purpose: _purposeCtrl.text.trim(),
          urgent: _urgent,
          desiredDate: _desiredDate,
          paymentForm: _paymentForm,
          requesterUid: _requesterUid,
          requesterName: _requesterName,
          companyContacts: companyContacts,
          deliveryMethod: deliveryMethod,
          otherExpenses: otherExpenses,
          projectRows: projectRows,
          status: createStatus,
        );
      }

      if (_attachments.isNotEmpty) {
        final failed = <String>[];
        for (final attachment in _attachments) {
          try {
            final file = attachment.file;
            final bytes = attachment.bytes;

            if (file != null) {
              await approvals.uploadAttachment(
                requestId: saved.id,
                file: file,
                fileName: attachment.fileName,
              );
            } else if (bytes != null) {
              await approvals.uploadAttachmentBytes(
                requestId: saved.id,
                bytes: bytes,
                fileName: attachment.fileName,
              );
            } else {
              failed.add(attachment.fileName);
            }
          } catch (_) {
            failed.add(attachment.fileName);
          }
        }

        if (mounted && failed.isNotEmpty) {
          final failedLabel = failed.length == 1
              ? failed.first
              : 'Не вдалося відправити ${failed.length} вкладень';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Заявка збережена. $failedLabel.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      final successText = _isEdit
          ? 'Заявку №${saved.number} успішно оновлено'
          : (_isCopy
              ? 'Копію заявки №${saved.number} успішно створено'
              : (createStatus == PaymentRequestStatus.preliminary
                  ? 'Попередню заявку №${saved.number} успішно створено'
                  : 'Заявка №${saved.number} успішно створена'));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText)),
      );

      if (_isEdit || _isCopy) {
        Navigator.of(context).pop(saved);
      } else {
        context.go('/home');
      }
    } catch (e, stack) {
      debugPrint('SAVE REQUEST ERROR: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _error = 'Помилка: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  _UiTheme _ui(BuildContext context) => _UiTheme.from(context);

  InputDecoration _dec(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    final ui = _ui(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: ui.sub),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(color: ui.sub, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: ui.sub.withValues(alpha: 0.78)),
      filled: true,
      fillColor: ui.fieldFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: ui.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: ui.accentBlue, width: 1.35),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFFF97373).withValues(alpha: 0.90),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFF97373),
          width: 1.35,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    );
  }

  Widget _card(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final ui = _ui(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ui.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ui.isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _payFormTile({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    final ui = _ui(context);
    final selected = _paymentForm == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _paymentForm = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected ? accent.withValues(alpha: 0.10) : ui.fieldFill,
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : ui.fieldBorder,
              width: selected ? 1.35 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ui.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ui.sub,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? accent : ui.sub.withValues(alpha: 0.40),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentPreview(BuildContext context) {
    if (_attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < _attachments.length; i++) ...[
          _attachmentPreviewTile(context, _attachments[i]),
          if (i != _attachments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _attachmentPreviewTile(
    BuildContext context,
    _PendingAttachment attachment,
  ) {
    final ui = _ui(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ui.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.fieldBorder),
      ),
      child: Row(
        children: [
          if (attachment.previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                attachment.previewBytes!,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: ui.fieldFill,
                border: Border.all(color: ui.fieldBorder),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: ui.sub,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.text,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeAttachment(attachment),
            icon: Icon(Icons.close_rounded, color: ui.text),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectRowsSection(
      BuildContext context, List<DropdownMenuItem<String>> orgItems) {
    final ui = _ui(context);

    return _card(
      context,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Розподіл по проектах',
                    style: TextStyle(
                      color: ui.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleProjectRows,
                  icon: Icon(
                    _showProjectRows
                        ? Icons.expand_less_rounded
                        : Icons.account_tree_outlined,
                  ),
                  label: Text(_showProjectRows ? 'Сховати' : 'По проектах'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Необов’язково. Дані будуть передані в 1С разом із заявкою.',
              style: TextStyle(
                color: ui.sub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_showProjectRows) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      'Організація',
                      style: TextStyle(
                        color: ui.sub,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Сума',
                      style: TextStyle(
                        color: ui.sub,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_projectRows.length, (index) {
                final row = _projectRows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<String>(
                          initialValue: row.orgCode,
                          items: orgItems,
                          dropdownColor: ui.panel,
                          onChanged: (v) => setState(() => row.orgCode = v),
                          decoration: _dec(
                            context,
                            label: 'Організація',
                            icon: Icons.apartment_rounded,
                          ),
                          style: TextStyle(
                            color: ui.text,
                            fontWeight: FontWeight.w800,
                          ),
                          iconEnabledColor: ui.sub,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: row.amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: TextStyle(
                            color: ui.text,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _dec(
                            context,
                            label: 'Сума',
                            hint: '0.00',
                            icon: Icons.payments_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _removeProjectRow(index),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.redAccent.shade200,
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addProjectRow,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Додати рядок'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = _ui(context);

    final orgItems = _orgs
        .map(
          (o) => DropdownMenuItem<String>(
            value: o.code,
            child: Text(
              o.name,
              style: TextStyle(color: ui.text),
            ),
          ),
        )
        .toList();

    final deliveryItems = _deliveryMethods
        .map(
          (m) => DropdownMenuItem<String>(
            value: m.code,
            child: Text(
              m.name,
              style: TextStyle(color: ui.text),
            ),
          ),
        )
        .toList();
    final operationTypeItems = PaymentOperationType.values
        .where(
          (type) =>
              type == PaymentOperationType.supplierPayment ||
              type == PaymentOperationType.otherExpenses ||
              type == PaymentOperationType.salaryPayment ||
              type == PaymentOperationType.taxPayment,
        )
        .map(
          (type) => DropdownMenuItem<PaymentOperationType>(
            value: type,
            child: Text(paymentOperationTypeHuman(type)),
          ),
        )
        .toList();
    final statementItems = _statements
        .map(
          (s) => DropdownMenuItem<String>(
            value: s.uid,
            child: _StatementDropdownLabel(
              name: s.name,
              amount: s.amount,
              amountText:
                  s.amount > 0 ? '${_formatAmountLabel(s.amount)} ₴' : '',
              textColor: ui.text,
              subColor: ui.sub,
            ),
          ),
        )
        .toList();
    final cashboxItems = _cashboxes
        .map(
          (c) => DropdownMenuItem<String>(
            value: c.uid,
            child: Text(
              c.name,
              style: TextStyle(color: ui.text),
            ),
          ),
        )
        .toList();
    final taxItems = _taxes
        .map(
          (t) => DropdownMenuItem<String>(
            value: t.uid,
            child: Text(
              t.name,
              style: TextStyle(color: ui.text),
            ),
          ),
        )
        .toList();
    final subdivisionItems = _subdivisions
        .map(
          (s) => DropdownMenuItem<String>(
            value: s.uid,
            child: Text(
              s.name,
              style: TextStyle(color: ui.text),
            ),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: ui.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          _pageTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Opacity(
          opacity: _sending ? 0.72 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1100;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 12,
                  isDesktop ? 18 : 8,
                  isDesktop ? 24 : 12,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1280 : double.infinity,
                    ),
                    child: _ResponsiveNewRequestLayout(
                      isDesktop: isDesktop,
                      sidePanel: _DesktopNewRequestRail(
                        ui: ui,
                        title: _pageTitle,
                        mode: widget.mode,
                        amountText: _amountCtrl.text,
                        orgName: _selectedOrgName,
                        contractorName: _vendorNameCtrl.text,
                        contractorCode: _vendorCodeCtrl.text,
                        purposeText: _purposeCtrl.text,
                        paymentForm: _paymentForm,
                        desiredDate: _desiredDate,
                        attachmentCount: _attachments.length,
                        projectRowsCount:
                            _showProjectRows ? _projectRows.length : 0,
                        urgent: _urgent,
                        isSupplierPayment: _isSupplierPayment,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.mode != RequestFormMode.create) ...[
                            _card(
                              context,
                              child: ListTile(
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        ui.accentBlue.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color:
                                          ui.accentBlue.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Icon(
                                    _isEdit
                                        ? Icons.edit_rounded
                                        : Icons.copy_rounded,
                                    color: ui.accentBlue,
                                  ),
                                ),
                                title: Text(
                                  _isEdit
                                      ? 'Редагування заявки'
                                      : 'Створення копії заявки',
                                  style: TextStyle(
                                    color: ui.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  _isEdit
                                      ? 'Ви змінюєте існуючу чернетку.'
                                      : 'Поля заповнені з існуючої заявки.',
                                  style: TextStyle(
                                    color: ui.sub,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _QuickFillCard(
                            ui: ui,
                            isDesktop: isDesktop,
                            onTap: () => context.push('/invoices/recognize'),
                          ),
                          const SizedBox(height: 12),
                          _card(
                            context,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 14, 12, 14),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _NewRequestSectionHeader(
                                      ui: ui,
                                      icon: Icons.apartment_rounded,
                                      title: 'Основне',
                                      subtitle:
                                          'Юрособа, тип операції та внутрішній підрозділ.',
                                    ),
                                    const SizedBox(height: 12),
                                    _ResponsiveFieldRow(
                                      isDesktop: isDesktop,
                                      children: [
                                        _LabeledField(
                                          ui: ui,
                                          label: 'Організація (хто платить)',
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: _orgCode,
                                            items: orgItems,
                                            dropdownColor: ui.panel,
                                            onChanged: (v) {
                                              setState(() => _orgCode = v);
                                              _syncDeliveryMethodsByOrg();
                                              unawaited(
                                                  _syncOperationTypeMeta());
                                            },
                                            validator: (v) =>
                                                (v == null || v.isEmpty)
                                                    ? 'Обовʼязково'
                                                    : null,
                                            decoration: _dec(
                                              context,
                                              label: 'Організація',
                                              hint: _loadingOrgMeta
                                                  ? 'Завантаження...'
                                                  : 'Виберіть юрособу',
                                              icon: Icons.apartment_rounded,
                                            ),
                                            style: TextStyle(
                                              color: ui.text,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            iconEnabledColor: ui.sub,
                                          ),
                                        ),
                                        _LabeledField(
                                          ui: ui,
                                          label: 'Вид операції',
                                          child: DropdownButtonFormField<
                                              PaymentOperationType>(
                                            initialValue: _operationType,
                                            items: operationTypeItems,
                                            dropdownColor: ui.panel,
                                            onChanged: _setOperationType,
                                            decoration: _dec(
                                              context,
                                              label: 'Вид операції',
                                              hint: 'Оберіть вид операції',
                                              icon: Icons.category_rounded,
                                            ),
                                            style: TextStyle(
                                              color: ui.text,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            iconEnabledColor: ui.sub,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_subdivisions.isNotEmpty) ...[
                                      DropdownButtonFormField<String>(
                                        initialValue: _subdivisionUid,
                                        items: subdivisionItems,
                                        dropdownColor: ui.panel,
                                        onChanged: (v) =>
                                            setState(() => _subdivisionUid = v),
                                        validator: (v) {
                                          if (_subdivisions.isEmpty) {
                                            return null;
                                          }
                                          return (v == null || v.isEmpty)
                                              ? 'Оберіть підрозділ'
                                              : null;
                                        },
                                        decoration: _dec(
                                          context,
                                          label: 'Підрозділ',
                                          hint: 'Оберіть підрозділ',
                                          icon: Icons.account_tree_rounded,
                                        ),
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        iconEnabledColor: ui.sub,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (_isSalaryPayment) ...[
                                      DropdownButtonFormField<String>(
                                        initialValue: _statementUid,
                                        items: statementItems,
                                        dropdownColor: ui.panel,
                                        onChanged: (v) {
                                          setState(() => _statementUid = v);
                                          _applyStatementDefaults(
                                            forceAmount: true,
                                          );
                                        },
                                        validator: (v) => _isSalaryPayment &&
                                                (v == null || v.isEmpty)
                                            ? 'Оберіть відомість'
                                            : null,
                                        decoration: _dec(
                                          context,
                                          label: 'Відомість на виплату',
                                          hint: _loadingSalaryMeta
                                              ? 'Завантаження...'
                                              : 'Оберіть відомість',
                                          icon: Icons.receipt_long_rounded,
                                        ),
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        iconEnabledColor: ui.sub,
                                      ),
                                      if (_salaryMetaError != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _salaryMetaError!,
                                          style: TextStyle(
                                            color: Colors.red.shade300,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ] else if (!_loadingSalaryMeta &&
                                          _statements.isEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Немає доступних відомостей для обраної організації',
                                          style: TextStyle(
                                            color: ui.sub,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        initialValue: _cashboxUid,
                                        items: cashboxItems,
                                        dropdownColor: ui.panel,
                                        onChanged: (v) =>
                                            setState(() => _cashboxUid = v),
                                        validator: (v) => _isSalaryPayment &&
                                                (v == null || v.isEmpty)
                                            ? 'Оберіть касу'
                                            : null,
                                        decoration: _dec(
                                          context,
                                          label: 'Каса',
                                          hint: _loadingSalaryMeta
                                              ? 'Завантаження...'
                                              : 'Оберіть касу',
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                        ),
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        iconEnabledColor: ui.sub,
                                      ),
                                      if (_salaryMetaError == null &&
                                          !_loadingSalaryMeta &&
                                          _cashboxes.isEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Немає доступних кас для обраної організації',
                                          style: TextStyle(
                                            color: ui.sub,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                    if (_isTaxPayment) ...[
                                      DropdownButtonFormField<String>(
                                        initialValue: _taxUid,
                                        items: taxItems,
                                        dropdownColor: ui.panel,
                                        onChanged: (v) =>
                                            setState(() => _taxUid = v),
                                        validator: (v) => _isTaxPayment &&
                                                (v == null || v.isEmpty)
                                            ? 'Оберіть податок'
                                            : null,
                                        decoration: _dec(
                                          context,
                                          label: 'Податок',
                                          hint: _loadingSalaryMeta
                                              ? 'Завантаження...'
                                              : 'Оберіть податок',
                                          icon: Icons.request_quote_rounded,
                                        ),
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        iconEnabledColor: ui.sub,
                                      ),
                                      if (_taxMetaError != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _taxMetaError!,
                                          style: TextStyle(
                                            color: Colors.red.shade300,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ] else if (!_loadingSalaryMeta &&
                                          _taxes.isEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Немає доступних податків',
                                          style: TextStyle(
                                            color: ui.sub,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                    if (_isSupplierPayment) ...[
                                      _NewRequestSectionHeader(
                                        ui: ui,
                                        icon: Icons.storefront_rounded,
                                        title: 'Контрагент',
                                        subtitle:
                                            'Постачальник, ЄДРПОУ та контакти для бухгалтерії.',
                                      ),
                                      const SizedBox(height: 12),
                                      _ResponsiveFieldRow(
                                        isDesktop: isDesktop,
                                        children: [
                                          TextFormField(
                                            controller: _vendorNameCtrl,
                                            onChanged: (_) {
                                              if (_selectedContractorUid !=
                                                      null ||
                                                  _contractorSelectionConfirmed) {
                                                setState(() {
                                                  _selectedContractorUid = null;
                                                  _contractorSelectionConfirmed =
                                                      false;
                                                });
                                              } else {
                                                setState(() {});
                                              }
                                            },
                                            style: TextStyle(
                                              color: ui.text,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            decoration: _dec(
                                              context,
                                              label:
                                                  'Постачальник (назва контрагента)',
                                              hint:
                                                  'Наприклад: ТОВ "Пиво Снаб"',
                                              icon: Icons.storefront_rounded,
                                              suffixIcon: IconButton(
                                                tooltip: 'Знайти контрагента',
                                                onPressed:
                                                    _searchContractorByName,
                                                icon: const Icon(
                                                    Icons.search_rounded),
                                              ),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Вкажіть постачальника'
                                                    : null,
                                          ),
                                          TextFormField(
                                            controller: _vendorCodeCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                              signed: false,
                                            ),
                                            style: TextStyle(
                                              color: ui.text,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            onChanged: _onVendorCodeChanged,
                                            decoration: _dec(
                                              context,
                                              label: 'ЄДРПОУ постачальника',
                                              hint: '8 або 10 цифр',
                                              icon: Icons.badge_rounded,
                                              suffixIcon: SizedBox(
                                                width:
                                                    _edrpouLookupBusy ? 84 : 48,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (_edrpouLookupBusy)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.all(12),
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    IconButton(
                                                      tooltip:
                                                          'Підставити 11111111',
                                                      onPressed:
                                                          _applyExpensesSupplierCode,
                                                      icon: const Icon(Icons
                                                          .filter_8_rounded),
                                                      color: ui.accentAmber,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            validator: (v) {
                                              final trimmed = v?.trim() ?? '';
                                              if (trimmed.isEmpty) {
                                                return 'Вкажіть ЄДРПОУ';
                                              }
                                              if (trimmed.length < 8) {
                                                return 'Мінімум 8 цифр';
                                              }
                                              if (int.tryParse(trimmed) ==
                                                  null) {
                                                return 'Тільки цифри';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _companyContactsCtrl,
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        decoration: _dec(
                                          context,
                                          label: 'Контакти компанії',
                                          hint:
                                              'Телефон, контактна особа, коментар',
                                          icon: Icons.contact_phone_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    _NewRequestSectionHeader(
                                      ui: ui,
                                      icon: Icons.payments_rounded,
                                      title: 'Оплата',
                                      subtitle:
                                          'Сума, дата, спосіб отримання та призначення платежу.',
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _amountCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      style: TextStyle(
                                        color: ui.text,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      decoration: _dec(
                                        context,
                                        label: 'Сума, ₴',
                                        hint: 'Наприклад: 12500.00',
                                        icon: Icons.payments_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Введіть суму';
                                        }
                                        final parsed = num.tryParse(
                                            v.trim().replaceAll(',', '.'));
                                        if (parsed == null || parsed <= 0) {
                                          return 'Сума некоректна';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_isSupplierPayment &&
                                        _deliveryMethods.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        initialValue: _deliveryMethodCode,
                                        items: deliveryItems,
                                        dropdownColor: ui.panel,
                                        onChanged: (v) => setState(
                                            () => _deliveryMethodCode = v),
                                        decoration: _dec(
                                          context,
                                          label: 'Спосіб отримання',
                                          hint: 'Виберіть спосіб отримання',
                                          icon: Icons.local_shipping_outlined,
                                        ),
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        iconEnabledColor: ui.sub,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    if (_isSupplierPayment) ...[
                                      _buildProjectRowsSection(
                                          context, orgItems),
                                      const SizedBox(height: 12),
                                    ],
                                    TextFormField(
                                      controller: _purposeCtrl,
                                      maxLines: 3,
                                      maxLength: 210,
                                      style: TextStyle(
                                        color: ui.text,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                      decoration: _dec(
                                        context,
                                        label: 'Призначення платежу',
                                        hint:
                                            'Наприклад: оплата рахунку №123 за сировину',
                                        icon: Icons.subject_rounded,
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Вкажіть призначення'
                                              : null,
                                    ),
                                    const SizedBox(height: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _pickDesiredDate,
                                      child: InputDecorator(
                                        decoration: _dec(
                                          context,
                                          label: 'Бажана дата платежу',
                                          icon: Icons.event_rounded,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _desiredDate == null
                                                    ? 'Не вказано'
                                                    : _fmtDate(_desiredDate!),
                                                style: TextStyle(
                                                  color: _desiredDate == null
                                                      ? ui.sub
                                                      : ui.text,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (_desiredDate != null)
                                              IconButton(
                                                onPressed: () => setState(
                                                    () => _desiredDate = null),
                                                icon: const Icon(
                                                    Icons.close_rounded),
                                                color: ui.sub,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SwitchListTile.adaptive(
                                      value: _urgent,
                                      activeThumbColor: ui.accentAmber,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 2),
                                      title: Text(
                                        'Терміново',
                                        style: TextStyle(
                                          color: ui.text,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Позначка для пріоритетної обробки заявки.',
                                        style: TextStyle(
                                          color: ui.sub,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _urgent = v),
                                    ),
                                    const SizedBox(height: 12),
                                    FormField<String>(
                                      validator: (_) => _paymentForm == null ||
                                              _paymentForm!.isEmpty
                                          ? 'Виберіть форму оплати'
                                          : null,
                                      builder: (field) {
                                        final hasError = field.hasError;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Форма оплати',
                                              style: TextStyle(
                                                color: ui.sub,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                _payFormTile(
                                                  context: context,
                                                  value: 'Form1',
                                                  icon: Icons
                                                      .account_balance_rounded,
                                                  title: 'Безготівка',
                                                  subtitle:
                                                      'Оплата з банківського\nрахунку',
                                                  accent: ui.accentBlue,
                                                ),
                                                const SizedBox(width: 10),
                                                _payFormTile(
                                                  context: context,
                                                  value: 'Form2',
                                                  icon: Icons.payments_rounded,
                                                  title: 'Готівка',
                                                  subtitle:
                                                      'Оплата готівкою\nз каси / підзвіт',
                                                  accent: ui.accentAmber,
                                                ),
                                              ],
                                            ),
                                            if (hasError) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                field.errorText!,
                                                style: TextStyle(
                                                  color: Colors.red.shade300,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _NewRequestSectionHeader(
                                      ui: ui,
                                      icon: Icons.attach_file_rounded,
                                      title: 'Документи',
                                      subtitle:
                                          'Додайте рахунок, акт, накладну або фото підтвердження.',
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Вкладення (фото/файли)',
                                      style: TextStyle(
                                        color: ui.sub,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _attachmentPreview(context),
                                    if (_attachments.isNotEmpty)
                                      const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.icon(
                                          onPressed:
                                              (_attachmentBusy || _sending)
                                                  ? null
                                                  : _pickFile,
                                          icon: _attachmentBusy
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.attach_file_rounded),
                                          label: const Text('Додати файли'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed:
                                              (_attachmentBusy || _sending)
                                                  ? null
                                                  : () => _pickPhoto(
                                                      ImageSource.camera),
                                          icon: const Icon(
                                              Icons.photo_camera_outlined),
                                          label: const Text('Камера'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed:
                                              (_attachmentBusy || _sending)
                                                  ? null
                                                  : () => _pickPhoto(
                                                      ImageSource.gallery),
                                          icon:
                                              const Icon(Icons.photo_outlined),
                                          label: const Text('Галерея'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _NewRequestSectionHeader(
                                      ui: ui,
                                      icon: Icons.task_alt_rounded,
                                      title: 'Завершення',
                                      subtitle:
                                          'Перевірте дані та відправте заявку у маршрут погодження.',
                                    ),
                                    const SizedBox(height: 12),
                                    if (_error != null)
                                      Container(
                                        width: double.infinity,
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97373)
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFF97373)
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: Colors.red.shade200,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed:
                                            _sending ? null : () => _submit(),
                                        icon: _sending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Icon(
                                                _isEdit
                                                    ? Icons.save_rounded
                                                    : (_isCopy
                                                        ? Icons.copy_rounded
                                                        : Icons.send),
                                              ),
                                        label: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Text(
                                            _sending
                                                ? 'Зберігаємо...'
                                                : _submitLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!_isEdit) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _sending
                                              ? null
                                              : () => _submit(
                                                    createStatus:
                                                        PaymentRequestStatus
                                                            .preliminary,
                                                  ),
                                          icon: const Icon(
                                              Icons.event_note_rounded),
                                          label: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Text(
                                              'Зберегти як попередню',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResponsiveNewRequestLayout extends StatelessWidget {
  const _ResponsiveNewRequestLayout({
    required this.isDesktop,
    required this.child,
    required this.sidePanel,
  });

  final bool isDesktop;
  final Widget child;
  final Widget sidePanel;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: 16),
        SizedBox(
          width: 360,
          child: Align(
            alignment: Alignment.topCenter,
            child: sidePanel,
          ),
        ),
      ],
    );
  }
}

class _NewRequestSectionHeader extends StatelessWidget {
  const _NewRequestSectionHeader({
    required this.ui,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _UiTheme ui;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: ui.accentBlue.withValues(alpha: ui.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.accentBlue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ui.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ui.fieldBorder),
            ),
            child: Icon(icon, color: ui.accentBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.sub,
                    fontSize: 11.8,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({
    required this.isDesktop,
    required this.children,
  });

  final bool isDesktop;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.ui,
    required this.label,
    required this.child,
  });

  final _UiTheme ui;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ui.sub,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _QuickFillCard extends StatelessWidget {
  const _QuickFillCard({
    required this.ui,
    required this.isDesktop,
    required this.onTap,
  });

  final _UiTheme ui;
  final bool isDesktop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 14 : 12,
            isDesktop ? 12 : 12,
            isDesktop ? 14 : 12,
            isDesktop ? 12 : 12,
          ),
          decoration: BoxDecoration(
            color: ui.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ui.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: ui.isDark ? 0.14 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ui.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: ui.accentBlue.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  Icons.document_scanner_outlined,
                  color: ui.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заповнити з файла / камери',
                      style: TextStyle(
                        color: ui.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDesktop
                          ? 'OCR допоможе підтягнути постачальника, суму та призначення.'
                          : 'Рахунок, акт, накладна → сума, призначення,\nпостачальник підтягнуться автоматично',
                      maxLines: isDesktop ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.sub,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: ui.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNewRequestRail extends StatelessWidget {
  const _DesktopNewRequestRail({
    required this.ui,
    required this.title,
    required this.mode,
    required this.amountText,
    required this.orgName,
    required this.contractorName,
    required this.contractorCode,
    required this.purposeText,
    required this.paymentForm,
    required this.desiredDate,
    required this.attachmentCount,
    required this.projectRowsCount,
    required this.urgent,
    required this.isSupplierPayment,
  });

  final _UiTheme ui;
  final String title;
  final RequestFormMode mode;
  final String amountText;
  final String orgName;
  final String contractorName;
  final String contractorCode;
  final String purposeText;
  final String? paymentForm;
  final DateTime? desiredDate;
  final int attachmentCount;
  final int projectRowsCount;
  final bool urgent;
  final bool isSupplierPayment;

  double get _amount =>
      double.tryParse(amountText.trim().replaceAll(',', '.')) ?? 0;

  String get _paymentFormLabel {
    switch (paymentForm) {
      case 'Form1':
        return 'Безготівка';
      case 'Form2':
        return 'Готівка';
      default:
        return 'Не вибрано';
    }
  }

  String get _dateLabel {
    final date = desiredDate;
    if (date == null) return 'Не вказано';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final route = _routePreview();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: ui.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: ui.isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ui.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: ui.accentBlue.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.request_quote_rounded,
                    color: ui.accentBlue, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _modeLabel,
                      style: TextStyle(
                        color: ui.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _amount > 0 ? '${_formatAmount(_amount)} ₴' : 'Сума не вказана',
            style: TextStyle(
              color: _amount > 0 ? ui.accentBlue : ui.sub,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _RailSection(
            ui: ui,
            title: 'Готовність форми',
            child: Column(
              children: _completionItems()
                  .map(
                    (item) => _RailChecklistItem(
                      ui: ui,
                      label: item.$1,
                      done: item.$2,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _RailSection(
            ui: ui,
            title: 'Коротко',
            child: Column(
              children: [
                _RailInfoRow(
                  ui: ui,
                  label: 'Організація',
                  value: orgName.trim().isEmpty ? 'Не вибрано' : orgName,
                ),
                _RailInfoRow(
                  ui: ui,
                  label: 'Контрагент',
                  value: contractorName.trim().isEmpty
                      ? 'Не вказано'
                      : contractorName,
                ),
                _RailInfoRow(
                  ui: ui,
                  label: 'ЄДРПОУ',
                  value: contractorCode.trim().isEmpty
                      ? 'Не вказано'
                      : contractorCode,
                ),
                _RailInfoRow(
                  ui: ui,
                  label: 'Форма',
                  value: _paymentFormLabel,
                ),
                _RailInfoRow(
                  ui: ui,
                  label: 'Дата',
                  value: _dateLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _RailSection(
            ui: ui,
            title: 'Маршрут погодження',
            child: Column(
              children: route
                  .map(
                    (step) => _RailRouteStep(
                      ui: ui,
                      label: step.$1,
                      active: step.$2,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _RailSection(
            ui: ui,
            title: 'Готовність',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RailChip(
                  ui: ui,
                  icon: Icons.attach_file_rounded,
                  text: '$attachmentCount файлів',
                  accent: attachmentCount > 0 ? ui.accentBlue : ui.sub,
                ),
                _RailChip(
                  ui: ui,
                  icon: Icons.account_tree_rounded,
                  text: '$projectRowsCount проектів',
                  accent: projectRowsCount > 0 ? ui.accentBlue : ui.sub,
                ),
                if (urgent)
                  _RailChip(
                    ui: ui,
                    icon: Icons.priority_high_rounded,
                    text: 'Терміново',
                    accent: ui.accentAmber,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: ui.accentAmber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ui.accentAmber.withValues(alpha: 0.22)),
            ),
            child: Text(
              'Без документа або підтвердження маршруту бухгалтерія може не взяти заявку в оплату.',
              style: TextStyle(
                color: ui.text,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _modeLabel {
    switch (mode) {
      case RequestFormMode.create:
        return 'Нова заявка';
      case RequestFormMode.edit:
        return 'Редагування';
      case RequestFormMode.copy:
        return 'Копія заявки';
    }
  }

  List<(String, bool)> _completionItems() {
    return [
      ('Основне', orgName.trim().isNotEmpty),
      if (isSupplierPayment)
        (
          'Контрагент',
          contractorName.trim().isNotEmpty && contractorCode.trim().length >= 8,
        ),
      ('Оплата', _amount > 0 && purposeText.trim().isNotEmpty),
      ('Форма оплати', paymentForm != null && paymentForm!.trim().isNotEmpty),
      ('Документи', attachmentCount > 0),
    ];
  }

  List<(String, bool)> _routePreview() {
    if (_amount <= 0) {
      return const [
        ('Керівник підрозділу', true),
        ('CFO / Власник за сумою', false),
        ('Бухгалтерія', false),
      ];
    }

    return [
      const ('Керівник підрозділу', true),
      if (_amount > 20000) const ('Фінансовий директор', true),
      if (_amount > 100000) const ('Власник', true),
      const ('Бухгалтерія', false),
    ];
  }

  String _formatAmount(double value) {
    final rounded =
        value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    final parts = rounded.split('.');
    final chars = parts.first.split('').reversed.toList();
    final grouped = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) grouped.add(' ');
      grouped.add(chars[i]);
    }
    final whole = grouped.reversed.join();
    return parts.length > 1 ? '$whole.${parts.last}' : whole;
  }
}

class _RailSection extends StatelessWidget {
  const _RailSection({
    required this.ui,
    required this.title,
    required this.child,
  });

  final _UiTheme ui;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: ui.fieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RailInfoRow extends StatelessWidget {
  const _RailInfoRow({
    required this.ui,
    required this.label,
    required this.value,
  });

  final _UiTheme ui;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.sub,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.text,
                fontSize: 12.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailChecklistItem extends StatelessWidget {
  const _RailChecklistItem({
    required this.ui,
    required this.label,
    required this.done,
  });

  final _UiTheme ui;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color =
        done ? const Color(0xFF16A34A) : ui.sub.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? ui.text : ui.sub,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRouteStep extends StatelessWidget {
  const _RailRouteStep({
    required this.ui,
    required this.label,
    required this.active,
  });

  final _UiTheme ui;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? ui.accentBlue : ui.sub.withValues(alpha: 0.56);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? ui.text : ui.sub,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({
    required this.ui,
    required this.icon,
    required this.text,
    required this.accent,
  });

  final _UiTheme ui;
  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UiTheme {
  final bool isDark;
  final Color panel;
  final Color fieldFill;
  final Color border;
  final Color fieldBorder;
  final Color text;
  final Color sub;
  final Color accentBlue;
  final Color accentAmber;

  const _UiTheme({
    required this.isDark,
    required this.panel,
    required this.fieldFill,
    required this.border,
    required this.fieldBorder,
    required this.text,
    required this.sub,
    required this.accentBlue,
    required this.accentAmber,
  });

  factory _UiTheme.from(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final divider = theme.dividerTheme.color ?? cs.outlineVariant;

    return _UiTheme(
      isDark: isDark,
      panel: cs.surface,
      fieldFill: isDark ? const Color(0xFF132235) : const Color(0xFFF7FAFC),
      border: divider,
      fieldBorder: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : const Color(0xFFDCE7F0),
      text: cs.onSurface,
      sub: theme.textTheme.bodyMedium?.color ??
          cs.onSurface.withValues(alpha: 0.72),
      accentBlue: const Color(0xFF38BDF8),
      accentAmber: const Color(0xFFF59E0B),
    );
  }
}

class _PendingAttachment {
  final File? file;
  final Uint8List? bytes;
  final String fileName;
  final Uint8List? previewBytes;

  const _PendingAttachment({
    this.file,
    this.bytes,
    required this.fileName,
    this.previewBytes,
  });
}

class _ProjectRowData {
  String? orgCode;
  final TextEditingController amountCtrl;

  _ProjectRowData({
    this.orgCode,
    String amount = '',
  }) : amountCtrl = TextEditingController(text: amount);

  void dispose() {
    amountCtrl.dispose();
  }
}

class _DeliveryMethodOption {
  final String code;
  final String name;

  const _DeliveryMethodOption({
    required this.code,
    required this.name,
  });

  factory _DeliveryMethodOption.fromJson(Map<String, dynamic> json) {
    return _DeliveryMethodOption(
      code: json['Код']?.toString() ?? json['code']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}

class _OrgUiData {
  final String code;
  final String name;
  final List<_DeliveryMethodOption> deliveryMethods;
  final String? defaultDeliveryCode;

  const _OrgUiData({
    required this.code,
    required this.name,
    required this.deliveryMethods,
    required this.defaultDeliveryCode,
  });

  factory _OrgUiData.fromJson(Map<String, dynamic> json) {
    final methodsRaw = json['СпособыДоставки'] as List<dynamic>? ??
        json['deliveryMethods'] as List<dynamic>? ??
        const [];

    final methods = methodsRaw
        .map(
            (e) => _DeliveryMethodOption.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.code.isNotEmpty)
        .toList();

    return _OrgUiData(
      code: json['Код']?.toString() ?? json['code']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',
      deliveryMethods: methods,
      defaultDeliveryCode: json['ОсновнойСпособДоставки']?.toString() ??
          json['defaultDeliveryMethod']?.toString(),
    );
  }
}

class _SubdivisionUiData {
  final String uid;
  final String name;

  const _SubdivisionUiData({
    required this.uid,
    required this.name,
  });

  factory _SubdivisionUiData.fromJson(Map<String, dynamic> json) {
    return _SubdivisionUiData(
      uid: json['Ссылка']?.toString() ?? json['uid']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}

class _ContractorSearchSheet extends StatefulWidget {
  const _ContractorSearchSheet({
    required this.initialQuery,
  });

  final String initialQuery;

  @override
  State<_ContractorSearchSheet> createState() => _ContractorSearchSheetState();
}

class _ContractorSearchSheetState extends State<_ContractorSearchSheet> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<ContractorLookupOption> _items = const [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().length >= 2) {
      unawaited(_runSearch(widget.initialQuery.trim()));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _items = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final approvals = context.read<ApprovalsService>();
      final items = await approvals.getContractorsByName(query);
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не вдалося знайти контрагентів: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.textTheme.bodyMedium?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Пошук контрагента',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Закрити'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Введіть частину назви',
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Builder(
                builder: (context) {
                  if (_loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_error != null) {
                    return Center(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  if (_searchCtrl.text.trim().length < 2) {
                    return Center(
                      child: Text(
                        'Введіть щонайменше 2 символи для пошуку',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  if (_items.isEmpty) {
                    return Center(
                      child: Text(
                        'Нічого не знайдено',
                        style: TextStyle(
                          color: sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final singleExact = _items.length == 1;
                      return ListTile(
                        tileColor: singleExact
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.edrpou.trim().isEmpty
                              ? item.fullName
                              : '${item.fullName}\nЄДРПОУ: ${item.edrpou}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: sub,
                            height: 1.3,
                          ),
                        ),
                        isThreeLine: item.edrpou.trim().isNotEmpty,
                        trailing: Icon(
                          singleExact
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: singleExact ? theme.colorScheme.primary : null,
                        ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementDropdownLabel extends StatelessWidget {
  final String name;
  final double amount;
  final String amountText;
  final Color textColor;
  final Color subColor;

  const _StatementDropdownLabel({
    required this.name,
    required this.amount,
    required this.amountText,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasAmount = amount > 0 && amountText.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
        if (hasAmount) ...[
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(
              color: subColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
