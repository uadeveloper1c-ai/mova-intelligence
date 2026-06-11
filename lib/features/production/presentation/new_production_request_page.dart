import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../production_service.dart';

class NewProductionRequestPage extends StatefulWidget {
  const NewProductionRequestPage({super.key, this.initialType});

  final ProductionRequestType? initialType;

  @override
  State<NewProductionRequestPage> createState() =>
      _NewProductionRequestPageState();
}

class _NewProductionRequestPageState extends State<NewProductionRequestPage> {
  late ProductionRequestType _type;
  late Future<void> _referencesFuture;
  String _direction = 'Пиво';
  String? _sourceWarehouseUid;
  String? _destinationWarehouseUid;
  DateTime _requiredDate = DateTime.now();
  List<ProductionReference> _warehouses = const [];
  List<ProductionReference> _catalog = const [];
  final List<_LineControllers> _lines = [_LineControllers()];
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? ProductionRequestType.rawMaterial;
    _referencesFuture = _loadReferences();
  }

  Future<void> _loadReferences() async {
    final service = context.read<ProductionService>();
    final values = await Future.wait([
      service.getWarehouses(),
      service.getCatalog(),
    ]);
    if (!mounted) return;
    setState(() {
      _warehouses = values[0];
      _catalog = values[1];
    });
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _comment.dispose();
    super.dispose();
  }

  List<String> get _directions => switch (_type) {
        ProductionRequestType.rawMaterial => const ['Пиво', 'Лимонад'],
        ProductionRequestType.bottling => const ['Тара', 'Розлив'],
        ProductionRequestType.finishedGoods => const [
            'Зі складу',
            'З виробництва',
          ],
        ProductionRequestType.returnToStock => const ['Сировина', 'Тара'],
      };

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _requiredDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _requiredDate = value);
  }

  Future<void> _submit() async {
    if (_sourceWarehouseUid == null || _destinationWarehouseUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть склад відправник і отримувач')),
      );
      return;
    }

    final drafts = <ProductionRequestLineDraft>[];
    for (final line in _lines) {
      final quantity = double.tryParse(line.quantity.text.replaceAll(',', '.'));
      if (line.name.text.trim().isEmpty || quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заповніть усі товарні рядки')),
        );
        return;
      }
      drafts.add(
        ProductionRequestLineDraft(
          itemUid: line.itemUid ?? '',
          itemName: line.name.text.trim(),
          quantity: quantity,
          unit: line.unit,
          purpose: line.purpose.text.trim(),
        ),
      );
    }

    setState(() => _busy = true);
    try {
      await context.read<ProductionService>().createRequest(
            type: _type,
            direction: _direction,
            sourceWarehouseUid: _sourceWarehouseUid!,
            destinationWarehouseUid: _destinationWarehouseUid!,
            requiredDate: _requiredDate,
            lines: drafts,
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося створити заявку: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = theme.dividerTheme.color ?? cs.outlineVariant;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return FutureBuilder<void>(
      future: _referencesFuture,
      builder: (context, snapshot) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 16,
            12,
            desktop ? 24 : 16,
            28,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Назад',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Нове замовлення на переміщення',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 1050),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<ProductionRequestType>(
                      segments: [
                        for (final type in ProductionRequestType.values)
                          ButtonSegment(value: type, label: Text(type.title)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (value) {
                        setState(() {
                          _type = value.first;
                          _direction = _directions.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_warehouses.isEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Склади ще не підключені до API 1С. '
                              'Створення замовлення буде доступне після налаштування довідника складів.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  _ResponsiveFields(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _direction,
                        decoration: const InputDecoration(
                          labelText: 'Процес',
                        ),
                        items: [
                          for (final value in _directions)
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) =>
                            setState(() => _direction = value!),
                      ),
                      _warehouseField(
                        label: 'Склад-відправник',
                        value: _sourceWarehouseUid,
                        onChanged: (value) =>
                            setState(() => _sourceWarehouseUid = value),
                      ),
                      _warehouseField(
                        label: 'Склад-отримувач',
                        value: _destinationWarehouseUid,
                        onChanged: (value) =>
                            setState(() => _destinationWarehouseUid = value),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Бажана дата надходження',
                            suffixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          child: Text(_formatDate(_requiredDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Товари',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _lines.add(_LineControllers())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Додати рядок'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < _lines.length; index++) ...[
                    _ProductLineEditor(
                      index: index,
                      line: _lines[index],
                      catalog: _catalog,
                      canRemove: _lines.length > 1,
                      onRemove: () {
                        final removed = _lines.removeAt(index);
                        removed.dispose();
                        setState(() {});
                      },
                    ),
                    if (index != _lines.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Коментар'),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy || _warehouses.isEmpty ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Створити замовлення'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _warehouseField({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final warehouse in _warehouses)
          DropdownMenuItem(value: warehouse.uid, child: Text(warehouse.name)),
      ],
      onChanged: onChanged,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _ProductLineEditor extends StatelessWidget {
  const _ProductLineEditor({
    required this.index,
    required this.line,
    required this.catalog,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _LineControllers line;
  final List<ProductionReference> catalog;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerTheme.color ?? cs.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Рядок ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Видалити рядок',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          _ResponsiveFields(
            children: [
              if (catalog.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: line.itemUid,
                  decoration: const InputDecoration(labelText: 'Номенклатура'),
                  items: [
                    for (final item in catalog)
                      DropdownMenuItem(value: item.uid, child: Text(item.name)),
                  ],
                  onChanged: (uid) {
                    line.itemUid = uid;
                    final item = catalog.firstWhere((item) => item.uid == uid);
                    line.name.text = item.name;
                  },
                )
              else
                TextField(
                  controller: line.name,
                  decoration: const InputDecoration(labelText: 'Номенклатура'),
                ),
              TextField(
                controller: line.quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Кількість'),
              ),
              DropdownButtonFormField<String>(
                initialValue: line.unit,
                decoration: const InputDecoration(labelText: 'Одиниця'),
                items: const [
                  DropdownMenuItem(value: 'кг', child: Text('кг')),
                  DropdownMenuItem(value: 'шт', child: Text('шт')),
                  DropdownMenuItem(value: 'л', child: Text('л')),
                  DropdownMenuItem(value: 'палета', child: Text('палета')),
                ],
                onChanged: (value) => line.unit = value!,
              ),
              TextField(
                controller: line.purpose,
                decoration: const InputDecoration(
                  labelText: 'Призначення / примітка',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineControllers {
  String? itemUid;
  String unit = 'кг';
  final name = TextEditingController();
  final quantity = TextEditingController();
  final purpose = TextEditingController();

  void dispose() {
    name.dispose();
    quantity.dispose();
    purpose.dispose();
  }
}
