// lib/features/approvals/presentation/new_request_page.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/api_client.dart';
import 'package:mova_intelligence_app/features/auth/session_store.dart';
import 'package:mova_intelligence_app/features/approvals/approvals_service.dart';
import 'package:mova_intelligence_app/features/approvals/domain/payment_request.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

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
  bool _otherExpenses = false;

  String? _orgCode;
  List<_OrgUiData> _orgs = [];
  List<_SubdivisionOption> _subdivisions = [];
  String? _subdivisionUid;
  DateTime? _desiredDate;

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
  File? _attachmentFile;
  String? _attachmentName;
  Uint8List? _attachmentPreviewBytes;

  Timer? _edrpouDebounce;
  bool _edrpouLookupBusy = false;
  String? _lastEdrpouLookupValue;

  static const Color _bg = Color(0xFF14263D);
  static const Color _bgTop = Color(0xFF18314C);
  static const Color _panel = Color(0xFF20344F);
  static const Color _fieldFill = Color(0xFF2A4366);
  static const Color _border = Color(0xFF3A506B);

  static const Color _text = Color(0xFFF3F7FB);
  static const Color _sub = Color(0xFF9FB3C8);

  static const Color _accentBlue = Color(0xFF38E1FF);
  static const Color _accentAmber = Color(0xFFFFB020);
  static const Color _accentGreen = Color(0xFF4ADE80);
  static const Color _accentSky = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    _loadSessionAndMe();
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
            (s) => _SubdivisionOption(
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
        if (_subdivisions.length == 1) {
          _subdivisionUid = _subdivisions.first.uid;
        }
      });

      final api = context.read<ApiClient>();
      final me = await api.getMe();

      if (!mounted) return;

      if (me != null) {
        final orgsRaw = me['orgs'] as List<dynamic>? ?? const [];
        final parsed = orgsRaw
            .map((e) => _OrgUiData.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.code.isNotEmpty)
            .toList();

        final subdivisionsRaw = me['subdivisions'] as List<dynamic>? ?? const [];
        final parsedSubdivisions = subdivisionsRaw
            .map((e) =>
            _SubdivisionOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.uid.isNotEmpty)
            .toList();

        setState(() {
          if (parsed.isNotEmpty) {
            _orgs = parsed;
            final exists = _orgs.any((o) => o.code == _orgCode);
            if (!exists) {
              _orgCode = _orgs.first.code;
            }
          }

          _subdivisions = parsedSubdivisions;

          if (_subdivisions.isEmpty) {
            _subdivisionUid = null;
          } else if (_subdivisions.length == 1) {
            _subdivisionUid = _subdivisions.first.uid;
          } else if (_subdivisionUid != null &&
              !_subdivisions.any((s) => s.uid == _subdivisionUid)) {
            _subdivisionUid = null;
          }
        });
      }

      _syncDeliveryMethodsByOrg();
    } catch (e) {
      debugPrint('NewRequestPage _loadSessionAndMe error: $e');
      _syncDeliveryMethodsByOrg();
    } finally {
      if (mounted) {
        setState(() => _loadingOrgMeta = false);
      }
    }
  }

  void _syncDeliveryMethodsByOrg() {
    final selected =
        _orgs.where((o) => o.code == _orgCode).cast<_OrgUiData?>().firstOrNull;
    final methods = selected?.deliveryMethods ?? const <_DeliveryMethodOption>[];
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

  InputDecoration _dec({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: _sub),
      labelStyle: const TextStyle(color: _sub, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: _sub.withValues(alpha: 0.82)),
      filled: true,
      fillColor: _fieldFill.withValues(alpha: 0.78),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
        BorderSide(color: _accentBlue.withValues(alpha: 0.72), width: 1.35),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
        BorderSide(color: const Color(0xFFF97373).withValues(alpha: 0.85)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFFF97373).withValues(alpha: 0.92),
          width: 1.35,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    );
  }

  Widget _card({
    required Widget child,
    Color? accent,
  }) {
    final a = accent ?? _accentBlue;

    return Container(
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: a.withValues(alpha: 0.18),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _panel.withValues(alpha: 0.98),
            _panel.withValues(alpha: 0.90),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: a.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
      String title, {
        Color accent = _accentBlue,
        IconData? icon,
      }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: TextStyle(
            color: accent.withValues(alpha: 0.96),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
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
      final res = await FilePicker.platform.pickFiles(withData: false);
      if (res == null || res.files.isEmpty) return;

      final f = res.files.single;
      if (f.path == null) return;

      final file = File(f.path!);
      Uint8List? preview;
      final lower = f.name.toLowerCase();
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp')) {
        preview = await file.readAsBytes();
      }

      if (!mounted) return;
      setState(() {
        _attachmentFile = file;
        _attachmentName = f.name;
        _attachmentPreviewBytes = preview;
      });
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
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
        _attachmentFile = file;
        _attachmentName = x.name;
        _attachmentPreviewBytes = bytes;
      });
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _clearAttachment() {
    setState(() {
      _attachmentFile = null;
      _attachmentName = null;
      _attachmentPreviewBytes = null;
    });
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

    _edrpouDebounce?.cancel();

    if (digitsOnly.length != 8) {
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
          if (_vendorNameCtrl.text.trim().isEmpty) {
            _vendorNameCtrl.text = foundName.trim();
          }
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

  Future<void> _submit() async {
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

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final approvals = context.read<ApprovalsService>();
      final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));
      final projectRows = _buildProjectRowsForSubmit();

      final PaymentRequest created = await approvals.createManualRequest(
        orgCode: _orgCode!,
        vendorName: _vendorNameCtrl.text.trim(),
        vendorCode: _vendorCodeCtrl.text.trim(),
        amount: amount,
        currency: 'UAH',
        purpose: _purposeCtrl.text.trim(),
        urgent: _urgent,
        desiredDate: _desiredDate,
        paymentForm: _paymentForm,
        subdivisionUid: _subdivisionUid,
        requesterUid: _requesterUid,
        requesterName: _requesterName,
        companyContacts: _companyContactsCtrl.text.trim(),
        deliveryMethod: _deliveryMethodCode,
        otherExpenses: _otherExpenses,
        projectRows: projectRows,
      );

      if (_attachmentFile != null) {
        try {
          await approvals.uploadAttachment(
            requestId: created.id,
            file: _attachmentFile!,
            fileName: _attachmentName,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Заявка створена. Вкладення поки не відправлено.',
                ),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заявка №${created.number} успішно створена')),
      );

      context.go('/home');
    } catch (e, stack) {
      debugPrint('CREATE REQUEST ERROR: $e');
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

  Widget _payFormTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
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
            color: selected
                ? _fieldFill.withValues(alpha: 0.90)
                : _fieldFill.withValues(alpha: 0.60),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.4 : 1.0,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 16,
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
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _sub.withValues(alpha: 0.98),
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
                color: selected ? accent : Colors.white.withValues(alpha: 0.25),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgItems = _orgs
        .map(
          (o) => DropdownMenuItem<String>(
        value: o.code,
        child: Text(o.name, style: const TextStyle(color: _text)),
      ),
    )
        .toList();

    final subdivisionItems = _subdivisions
        .map(
          (s) => DropdownMenuItem<String>(
        value: s.uid,
        child: Text(s.name, style: const TextStyle(color: _text)),
      ),
    )
        .toList();

    final deliveryItems = _deliveryMethods
        .map(
          (m) => DropdownMenuItem<String>(
        value: m.code,
        child: Text(m.name, style: const TextStyle(color: _text)),
      ),
    )
        .toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel.withValues(alpha: 0.92),
        foregroundColor: _text,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Нова заявка',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bg],
          ),
        ),
        child: AbsorbPointer(
          absorbing: _sending,
          child: Opacity(
            opacity: _sending ? 0.65 : 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(
                    accent: _accentBlue,
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accentBlue.withValues(alpha: 0.12),
                          border: Border.all(
                            color: _accentBlue.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.document_scanner_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: const Text(
                        'Заповнити з файла / камери',
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        'Рахунок, акт, накладна → сума, призначення,\nпостачальник підтягнуться автоматично',
                        style: TextStyle(
                          color: _sub.withValues(alpha: 0.98),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: _sub),
                      onTap: () => context.push('/invoices/recognize'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    accent: _accentSky,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Організація (хто платить)',
                              accent: _accentBlue,
                              icon: Icons.apartment_rounded,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _orgCode,
                              items: orgItems,
                              dropdownColor: _panel,
                              onChanged: (v) {
                                setState(() => _orgCode = v);
                                _syncDeliveryMethodsByOrg();
                              },
                              validator: (v) =>
                              (v == null || v.isEmpty) ? 'Обовʼязково' : null,
                              decoration: _dec(
                                label: 'Організація',
                                hint: _loadingOrgMeta
                                    ? 'Завантаження...'
                                    : 'Виберіть юрособу',
                                icon: Icons.apartment_rounded,
                              ),
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                              iconEnabledColor: _sub,
                            ),
                            if (_subdivisions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _subdivisionUid,
                                items: subdivisionItems,
                                dropdownColor: _panel,
                                onChanged: (v) =>
                                    setState(() => _subdivisionUid = v),
                                validator: (v) {
                                  if (_subdivisions.isEmpty) return null;
                                  return (v == null || v.isEmpty)
                                      ? 'Оберіть підрозділ'
                                      : null;
                                },
                                decoration: _dec(
                                  label: 'Підрозділ',
                                  hint: 'Оберіть підрозділ заявника',
                                  icon: Icons.account_tree_outlined,
                                ),
                                style: const TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w800,
                                ),
                                iconEnabledColor: _sub,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _sectionTitle(
                              'Реквізити постачальника',
                              accent: _accentSky,
                              icon: Icons.storefront_rounded,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vendorNameCtrl,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: _dec(
                                label: 'Постачальник (назва контрагента)',
                                hint: 'Наприклад: ТОВ "Пиво Снаб"',
                                icon: Icons.storefront_rounded,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Вкажіть постачальника'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _vendorCodeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                signed: false,
                              ),
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                              onChanged: _onVendorCodeChanged,
                              decoration: _dec(
                                label: 'ЄДРПОУ постачальника',
                                hint: 'Наприклад: 12345678',
                                icon: Icons.badge_rounded,
                              ).copyWith(
                                suffixIcon: _edrpouLookupBusy
                                    ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                                    : null,
                              ),
                              validator: (v) {
                                final trimmed = v?.trim() ?? '';
                                if (trimmed.isEmpty) return 'Вкажіть ЄДРПОУ';
                                if (trimmed.length < 8) return 'Мінімум 8 цифр';
                                if (int.tryParse(trimmed) == null) {
                                  return 'Тільки цифри';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _companyContactsCtrl,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: _dec(
                                label: 'Контакти компанії',
                                hint: 'Телефон, контактна особа, коментар',
                                icon: Icons.contact_phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _sectionTitle(
                              'Сума та оплата',
                              accent: _accentAmber,
                              icon: Icons.payments_rounded,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: _dec(
                                label: 'Сума, ₴',
                                hint: 'Наприклад: 12500.00',
                                icon: Icons.payments_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Введіть суму';
                                }
                                final parsed =
                                num.tryParse(v.trim().replaceAll(',', '.'));
                                if (parsed == null || parsed <= 0) {
                                  return 'Сума некоректна';
                                }
                                return null;
                              },
                            ),
                            if (_deliveryMethods.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _deliveryMethodCode,
                                items: deliveryItems,
                                dropdownColor: _panel,
                                onChanged: (v) =>
                                    setState(() => _deliveryMethodCode = v),
                                decoration: _dec(
                                  label: 'Спосіб отримання',
                                  hint: 'Виберіть спосіб отримання',
                                  icon: Icons.local_shipping_outlined,
                                ),
                                style: const TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w800,
                                ),
                                iconEnabledColor: _sub,
                              ),
                            ],
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              value: _otherExpenses,
                              activeColor: _accentAmber,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 2),
                              title: const Text(
                                'Інші витрати',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onChanged: (v) => setState(() => _otherExpenses = v),
                            ),
                            const SizedBox(height: 8),
                            _card(
                              accent: _accentBlue,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Розподіл по проектах',
                                            style: TextStyle(
                                              color: _text,
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
                                          label: Text(
                                            _showProjectRows
                                                ? 'Сховати'
                                                : 'По проектах',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Необов’язково. Дані будуть передані в 1С разом із заявкою.',
                                      style: TextStyle(
                                        color: _sub.withValues(alpha: 0.95),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_showProjectRows) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: const [
                                          Expanded(
                                            flex: 6,
                                            child: Text(
                                              'Організація',
                                              style: TextStyle(
                                                color: _sub,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'Сума',
                                              style: TextStyle(
                                                color: _sub,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 40),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(_projectRows.length, (index) {
                                        final row = _projectRows[index];
                                        return Padding(
                                          padding:
                                          const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 6,
                                                child:
                                                DropdownButtonFormField<String>(
                                                  value: row.orgCode,
                                                  items: orgItems,
                                                  dropdownColor: _panel,
                                                  onChanged: (v) =>
                                                      setState(() => row.orgCode = v),
                                                  decoration: _dec(
                                                    label: 'Організація',
                                                    icon: Icons.apartment_rounded,
                                                  ),
                                                  style: const TextStyle(
                                                    color: _text,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  iconEnabledColor: _sub,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 4,
                                                child: TextField(
                                                  controller: row.amountCtrl,
                                                  keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                                  style: const TextStyle(
                                                    color: _text,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  decoration: _dec(
                                                    label: 'Сума',
                                                    hint: '0.00',
                                                    icon: Icons.payments_rounded,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                onPressed: () =>
                                                    _removeProjectRow(index),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                ),
                                                color: Colors.redAccent.shade100,
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
                            ),
                            const SizedBox(height: 14),
                            _sectionTitle(
                              'Призначення та дата',
                              accent: _accentAmber,
                              icon: Icons.edit_note_rounded,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _purposeCtrl,
                              maxLines: 3,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              decoration: _dec(
                                label: 'Призначення платежу',
                                hint:
                                'Наприклад: оплата рахунку №123 за сировину',
                                icon: Icons.subject_rounded,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Вкажіть призначення'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _pickDesiredDate,
                              child: InputDecorator(
                                decoration: _dec(
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
                                          color:
                                          _desiredDate == null ? _sub : _text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (_desiredDate != null)
                                      IconButton(
                                        onPressed: () =>
                                            setState(() => _desiredDate = null),
                                        icon: const Icon(Icons.close_rounded),
                                        color: _sub,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              value: _urgent,
                              activeColor: _accentAmber,
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 2),
                              title: const Text(
                                'Терміново',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'Позначка для пріоритетної обробки заявки.',
                                style: TextStyle(
                                  color: _sub.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onChanged: (v) => setState(() => _urgent = v),
                            ),
                            const SizedBox(height: 12),
                            _sectionTitle(
                              'Форма оплати',
                              accent: _accentBlue,
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                            const SizedBox(height: 8),
                            FormField<String>(
                              validator: (_) =>
                              _paymentForm == null || _paymentForm!.isEmpty
                                  ? 'Виберіть форму оплати'
                                  : null,
                              builder: (field) {
                                final hasError = field.hasError;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _payFormTile(
                                          value: 'Form1',
                                          icon: Icons.account_balance_rounded,
                                          title: 'Безготівка',
                                          subtitle:
                                          'Оплата з банківського\nрахунку',
                                          accent: _accentBlue,
                                        ),
                                        const SizedBox(width: 10),
                                        _payFormTile(
                                          value: 'Form2',
                                          icon: Icons.payments_rounded,
                                          title: 'Готівка',
                                          subtitle:
                                          'Оплата готівкою\nз каси / підзвіт',
                                          accent: _accentAmber,
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
                            _sectionTitle(
                              'Вкладення (фото/файл)',
                              accent: _accentGreen,
                              icon: Icons.attach_file_rounded,
                            ),
                            const SizedBox(height: 8),
                            if (_attachmentFile != null)
                              Container(
                                padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                decoration: BoxDecoration(
                                  color: _accentGreen.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _accentGreen.withValues(alpha: 0.20),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (_attachmentPreviewBytes != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          _attachmentPreviewBytes!,
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
                                          color:
                                          Colors.white.withValues(alpha: 0.06),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.10),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.insert_drive_file_rounded,
                                          color: _sub,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _attachmentName ?? 'attachment',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _text,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _clearAttachment,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: _text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed:
                                  (_attachmentBusy || _sending) ? null : _pickFile,
                                  icon: _attachmentBusy
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Icon(Icons.attach_file_rounded),
                                  label: const Text('Додати файл'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (_attachmentBusy || _sending)
                                      ? null
                                      : () => _pickPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Камера'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (_attachmentBusy || _sending)
                                      ? null
                                      : () => _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_outlined),
                                  label: const Text('Галерея'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_error != null)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97373)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
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
                                onPressed: _sending ? null : _submit,
                                icon: const Icon(Icons.send),
                                label: Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _sending
                                        ? 'Відправляємо...'
                                        : 'Відправити заявку',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }
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
      name: json['Наименование']?.toString() ??
          json['name']?.toString() ??
          '',
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
        .map((e) => _DeliveryMethodOption.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.code.isNotEmpty)
        .toList();

    return _OrgUiData(
      code: json['Код']?.toString() ?? json['code']?.toString() ?? '',
      name: json['Наименование']?.toString() ??
          json['name']?.toString() ??
          '',
      deliveryMethods: methods,
      defaultDeliveryCode: json['ОсновнойСпособДоставки']?.toString() ??
          json['defaultDeliveryMethod']?.toString(),
    );
  }
}

class _SubdivisionOption {
  final String uid;
  final String name;

  const _SubdivisionOption({
    required this.uid,
    required this.name,
  });

  factory _SubdivisionOption.fromJson(Map<String, dynamic> json) {
    return _SubdivisionOption(
      uid: json['Ссылка']?.toString() ??
          json['uid']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['Наименование']?.toString() ??
          json['name']?.toString() ??
          '',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}