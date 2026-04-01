import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mova_intelligence_app/api/auth_provider.dart';

import '../../../auth/session_store.dart';
import '../../../approvals/approvals_service.dart';
import '../../../approvals/domain/payment_request.dart';

/// Форма оплати, яку будемо відправляти на бекенд
enum PaymentForm {
  cash,       // готівка
  nonCash,    // безготівкова
  any,        // будь-яка
}

/// Маппінг на рядок для 1С
String paymentFormToBackend(PaymentForm f) {
  switch (f) {
    case PaymentForm.cash:
      return 'Cash';      // тут можеш замінити на свій код, напр. "Нал"
    case PaymentForm.nonCash:
      return 'NonCash';   // або "Безнал"
    case PaymentForm.any:
      return 'Any';       // або "AnyForm"/"Любая"
  }
}

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _formKey = GlobalKey<FormState>();

  // поля форми
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController(); // Назва контрагента
  final _vendorCodeCtrl = TextEditingController(); // ЄДРПОУ

  bool _urgent = false;
  String? _orgCode;
  List<OrgAccess> _orgs = [];
  DateTime? _desiredDate; // бажана дата платежу

  bool _sending = false;
  String? _error;

  // форма оплати (за замовчуванням — будь-яка)
  PaymentForm _paymentForm = PaymentForm.any;

  @override
  void initState() {
    super.initState();
    _loadSessionOrgs();
  }

  Future<void> _loadSessionOrgs() async {
    final session = await SessionStore.loadSession();
    setState(() {
      _orgs = session?.orgs ?? [];
      if (_orgs.isNotEmpty) {
        _orgCode = _orgs.first.code;
      }
    });
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_orgCode == null) {
      setState(() {
        _error = 'Виберіть організацію';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final approvals = context.read<ApprovalsService>();

      // поточний користувач (заявник)
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      final requesterUid = user?.uid ?? '';
      final requesterName = user?.name ?? '';

      final amountText = _amountCtrl.text.trim().replaceAll(',', '.');
      final amount = double.parse(amountText);

      final PaymentRequest created = await approvals.createManualRequest(
        orgCode: _orgCode!,
        vendorName: _vendorNameCtrl.text.trim(),
        vendorCode: _vendorCodeCtrl.text.trim(),
        amount: amount,
        currency: 'UAH',
        purpose: _purposeCtrl.text.trim(),
        urgent: _urgent,
        desiredDate: _desiredDate,

        // 🔽 НОВЕ:
        requesterUid: requesterUid,
        requesterName: requesterName,
        paymentForm: paymentFormToBackend(_paymentForm),
      );

      if (!mounted) return;

      final humanNumber = created.number;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заявка $humanNumber відправлена ✅')),
      );

      context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Не вдалося відправити заявку: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _vendorNameCtrl.dispose();
    _vendorCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgItems = _orgs
        .map(
          (o) => DropdownMenuItem<String>(
        value: o.code,
        child: Text(o.name),
      ),
    )
        .toList();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Нова заявка / рахунок'),
      ),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Stack(
          children: [
            Opacity(
              opacity: _sending ? 0.6 : 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== КНОПКА "із файла / камери" =====
                    Card(
                      color: Colors.blueGrey.shade50,
                      child: ListTile(
                        leading: const Icon(
                          Icons.document_scanner_outlined,
                          size: 32,
                        ),
                        title: const Text('Заповнити з файла / камери'),
                        subtitle: const Text(
                          'Рахунок, акт, накладна → сума, призначення,\n'
                              'постачальник підтягнуться автоматично',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // маршрут розпізнавання, як і раніше
                          context.push('/invoices/recognize');
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== ФОРМА =====
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Організація
                          const Text(
                            'Організація (хто платить)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _orgCode,
                            items: orgItems,
                            onChanged: (v) => setState(() => _orgCode = v),
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Обовʼязково' : null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Виберіть юрособу',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Постачальник
                          const Text(
                            'Постачальник (назва контрагента)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _vendorNameCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Наприклад: ТОВ "Пиво Снаб"',
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Вкажіть постачальника'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // ЄДРПОУ (обовʼязково)
                          const Text(
                            'ЄДРПОУ постачальника',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _vendorCodeCtrl,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                signed: false),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Наприклад: 12345678',
                            ),
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Вкажіть ЄДРПОУ';
                              }
                              if (trimmed.length < 8) {
                                return 'Мінімум 8 цифр';
                              }
                              if (int.tryParse(trimmed) == null) {
                                return 'Тільки цифри';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Сума
                          const Text(
                            'Сума, ₴',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Наприклад: 12500.00',
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
                          const SizedBox(height: 16),

                          // Призначення платежу
                          const Text(
                            'Призначення платежу',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _purposeCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText:
                              'За що платимо? Кому? За який період?',
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Заповніть призначення'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Бажана дата платежу
                          const Text(
                            'Бажана дата платежу',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                _desiredDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _desiredDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Виберіть дату платежу',
                              ),
                              child: Text(
                                _desiredDate == null
                                    ? 'Не вибрана'
                                    : '${_desiredDate!.day.toString().padLeft(2, '0')}.'
                                    '${_desiredDate!.month.toString().padLeft(2, '0')}.'
                                    '${_desiredDate!.year}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Форма оплати
                          const Text(
                            'Форма оплати',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),

                          RadioListTile<PaymentForm>(
                            title: const Text('Безготівкова'),
                            value: PaymentForm.nonCash,
                            groupValue: _paymentForm,
                            onChanged: (v) =>
                                setState(() => _paymentForm = v!),
                          ),
                          RadioListTile<PaymentForm>(
                            title: const Text('Готівка'),
                            value: PaymentForm.cash,
                            groupValue: _paymentForm,
                            onChanged: (v) =>
                                setState(() => _paymentForm = v!),
                          ),
                          RadioListTile<PaymentForm>(
                            title: const Text('Будь-яка'),
                            value: PaymentForm.any,
                            groupValue: _paymentForm,
                            onChanged: (v) =>
                                setState(() => _paymentForm = v!),
                          ),

                          const SizedBox(height: 16),

                          // Терміново
                          Row(
                            children: [
                              Checkbox(
                                value: _urgent,
                                onChanged: (v) =>
                                    setState(() => _urgent = v ?? false),
                              ),
                              const Text('Терміново'),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (_error != null)
                            Padding(
                              padding:
                              const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _sending ? null : _submit,
                              icon: const Icon(Icons.send),
                              label:
                              const Text('Відправити заявку на оплату'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_sending)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
