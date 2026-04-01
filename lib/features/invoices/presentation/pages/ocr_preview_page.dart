import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../approvals/approvals_service.dart';
import '../../../auth/session_store.dart';
import '../../../approvals/domain/payment_request.dart';

class OcrPreviewPage extends StatefulWidget {
  const OcrPreviewPage({
    super.key,
    required this.fullText,
    required this.vendorName,
    required this.vendorCode,
    required this.amount,
    required this.purpose,
  });

  final String fullText;
  final String vendorName;
  final String vendorCode;
  final double? amount;
  final String purpose;

  @override
  State<OcrPreviewPage> createState() => _OcrPreviewPageState();
}

class _OcrPreviewPageState extends State<OcrPreviewPage> {
  final _formKey = GlobalKey<FormState>();

  final _vendorNameCtrl = TextEditingController();
  final _vendorCodeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();

  bool _urgent = false;
  String? _orgCode;
  String? _paymentForm; // 'cash' | 'bank'
  DateTime? _desiredDate;

  bool _sending = false;

  List<OrgAccess> _orgs = [];

  @override
  void initState() {
    super.initState();
    _vendorNameCtrl.text = widget.vendorName;
    _vendorCodeCtrl.text = widget.vendorCode;
    _amountCtrl.text = widget.amount?.toStringAsFixed(2) ?? '';
    _purposeCtrl.text = widget.purpose;

    _loadSessionOrgs();
  }

  Future<void> _loadSessionOrgs() async {
    final session = await SessionStore.loadSession();
    if (!mounted) return;
    setState(() {
      _orgs = session?.orgs ?? [];
      if (_orgs.isNotEmpty) _orgCode = _orgs.first.code;
    });
  }

  @override
  void dispose() {
    _vendorNameCtrl.dispose();
    _vendorCodeCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_orgCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть організацію')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final approvals = context.read<ApprovalsService>();

      final amount = double.parse(_amountCtrl.text.trim().replaceAll(',', '.'));

      final PaymentRequest created = await approvals.createManualRequest(
        orgCode: _orgCode!,
        vendorName: _vendorNameCtrl.text.trim(),
        vendorCode: _vendorCodeCtrl.text.trim(),
        amount: amount,
        currency: 'UAH',
        purpose: _purposeCtrl.text.trim(),
        urgent: _urgent,
        desiredDate: _desiredDate,
        paymentForm: _paymentForm, // cash/bank
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заявка №${created.number} створена ✅')),
      );

      // Закрываем OCR preview и возвращаемся назад
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не вдалося створити заявку. Спробуйте ще раз.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgItems = _orgs
        .map((o) => DropdownMenuItem<String>(
      value: o.code,
      child: Text(o.name),
    ))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Перевірка (OCR)')),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Opacity(
          opacity: _sending ? 0.6 : 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_sending) const LinearProgressIndicator(),
                  const SizedBox(height: 12),

                  const Text('Організація', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _orgCode,
                    items: orgItems,
                    onChanged: (v) => setState(() => _orgCode = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Обовʼязково' : null,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  const Text('Постачальник', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _vendorNameCtrl,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Вкажіть постачальника' : null,
                  ),
                  const SizedBox(height: 16),

                  const Text('ЄДРПОУ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _vendorCodeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Вкажіть ЄДРПОУ';
                      if (s.length < 8) return 'Мінімум 8 цифр';
                      if (int.tryParse(s) == null) return 'Тільки цифри';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Сума, ₴', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Введіть суму';
                      final n = num.tryParse(s.replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Сума некоректна';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Призначення', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _purposeCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Заповніть призначення' : null,
                  ),
                  const SizedBox(height: 16),

                  const Text('Форма оплати', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentForm,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Оберіть форму оплати',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Готівкова')),
                      DropdownMenuItem(value: 'bank', child: Text('Безготівкова')),
                    ],
                    onChanged: (v) => setState(() => _paymentForm = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Виберіть форму оплати' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: _urgent,
                        onChanged: (v) => setState(() => _urgent = v ?? false),
                      ),
                      const Text('Терміново'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _desiredDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _desiredDate = picked);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _desiredDate == null
                          ? 'Бажана дата: не вибрана'
                          : 'Бажана дата: ${_desiredDate!.day.toString().padLeft(2, '0')}.'
                          '${_desiredDate!.month.toString().padLeft(2, '0')}.'
                          '${_desiredDate!.year}',
                    ),
                  ),

                  const SizedBox(height: 16),

                  ExpansionTile(
                    title: const Text('Розпізнаний текст (debug)'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.black12,
                        child: Text(widget.fullText),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: const Text('Створити заявку'),
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
