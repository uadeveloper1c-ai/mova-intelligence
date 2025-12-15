import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

  // поля формы
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController(); // Наименование поставщика
  final _vendorCodeCtrl = TextEditingController(); // ЕДРПОУ поставщика

  bool _urgent = false;
  String? _orgCode;
  List<OrgAccess> _orgs = [];
  DateTime? _desiredDate; // желательная дата платежа
  String? _paymentForm; // 'cash' або 'bank'
  String? _requesterUid;
  String? _requesterName;
  bool _sending = false;
  String? _error;

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
      _requesterUid  = session?.userUid ?? session?.token;
      _requesterName = session?.fullName;
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
      _error = null; // сбрасываем старую ошибку
    });

    try {
      final approvals = context.read<ApprovalsService>();

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
        paymentForm: _paymentForm,
        requesterUid: _requesterUid,
        requesterName: _requesterName,
      );

      if (!mounted) return;

      final humanNumber = created.number;

      // 🔹 УСПЕШНО: показываем красивый snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Заявка №$humanNumber успішно створена'),
        ),
      );

      // 🔹 Возврат на меню
      context.go('/home');

    } catch (e) {
      // 🔹 АККУРАТНАЯ ошибка без технических деталей
      setState(() {
        _error = 'Не вдалося відправити заявку. Перевірте дані та спробуйте ще раз.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: не вдалося створити заявку'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Нова заявка'),
      ),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Opacity(
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
                    leading:
                    const Icon(Icons.document_scanner_outlined, size: 32),
                    title: const Text('Заповнити з файла / камери'),
                    subtitle: const Text(
                      'Рахунок, акт, накладна → сума, призначення,\n'
                          'постачальник підтягнуться автоматично',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
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
                        value: _orgCode,
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

                      // ЄДРПОУ постачальника (обовʼязково)
                      const Text(
                        'ЄДРПОУ постачальника',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _vendorCodeCtrl,
                        keyboardType:
                        const TextInputType.numberWithOptions(signed: false),
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
                        const TextInputType.numberWithOptions(decimal: true),
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
                          hintText: 'За що платимо? Кому? За який період?',
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
                            initialDate: _desiredDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                            DateTime.now().add(const Duration(days: 365)),
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

                      // Терміново
                      const Text(
                        'Пріоритет',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                setState(() {
                                  _urgent = !_urgent;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: _urgent
                                      ? Colors.red.withOpacity(0.08)
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: _urgent
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.priority_high,
                                      size: 20,
                                      color: _urgent ? Colors.red : Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _urgent ? 'Терміново' : 'Звичайний платіж',
                                      style: TextStyle(
                                        fontWeight:
                                        _urgent ? FontWeight.w700 : FontWeight.w500,
                                        color: _urgent ? Colors.red.shade800 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16), // ← небольшой отступ

                      // ===== ФОРМА ОПЛАТИ =====
                      const Text(
                        'Форма оплати',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      FormField<String>(
                        validator: (_) =>
                        _paymentForm == null ? 'Виберіть форму оплати' : null,
                        builder: (field) {
                          final hasError = field.errorText != null;

                          Widget buildOption({
                            required String value,
                            required IconData icon,
                            required String label,
                            required String description,
                          }) {
                            final bool selected = _paymentForm == value;
                            final theme = Theme.of(context);
                            final colorScheme = theme.colorScheme;

                            return Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _paymentForm = value;
                                  });
                                  field.didChange(value);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? colorScheme.primary
                                          : Colors.grey.shade300,
                                    ),
                                    color: selected
                                        ? colorScheme.primary.withOpacity(0.08)
                                        : Colors.grey.shade50,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        size: 28,
                                        color: selected
                                            ? colorScheme.primary
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        label,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight:
                                          selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  buildOption(
                                    value: 'bank',
                                    icon: Icons.credit_card,
                                    label: 'Безготівкова',
                                    description: 'Оплата з рахунку\nюридичної особи',
                                  ),
                                  const SizedBox(width: 12),
                                  buildOption(
                                    value: 'cash',
                                    icon: Icons.attach_money,
                                    label: 'Готівкова',
                                    description: 'Оплата готівкою\nз каси / підзвіт',
                                  ),
                                ],
                              ),
                              if (hasError) ...[
                                const SizedBox(height: 6),
                                Text(
                                  field.errorText!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),


                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: const Text('Відправити заявку'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
