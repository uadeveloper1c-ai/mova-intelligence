import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../sales_service.dart';

class CustomerOrderPage extends StatefulWidget {
  const CustomerOrderPage({super.key});

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  SalesReference? _partner;
  SalesReference? _agreement;
  SalesReference? _contract;
  DateTime _shipmentDate = DateTime.now();
  List<SalesReference> _agreements = const [];
  List<SalesReference> _contracts = const [];
  List<SalesReference> _priceTypes = const [];
  List<SalesDebtRow> _debts = const [];
  final List<_OrderLineData> _lines = [_OrderLineData()];
  final _comment = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _priceTypes = await context.read<SalesService>().getPriceTypes();
      if (_priceTypes.isNotEmpty) {
        for (final line in _lines) {
          line.priceType = _priceTypes.first;
        }
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _shipmentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _shipmentDate = selected);
  }

  Future<void> _selectPartner(SalesReference selected) async {
    if (!mounted) return;
    setState(() {
      _partner = selected;
      _agreement = null;
      _contract = null;
      _agreements = const [];
      _contracts = const [];
      _debts = const [];
    });
    await _loadPartnerDetails();
  }

  Future<void> _loadPartnerDetails() async {
    final partner = _partner;
    if (partner == null) return;
    final service = context.read<SalesService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final agreements = await service.getAgreements(partner.uid);
      if (mounted) {
        setState(() {
          _agreements = agreements;
          _agreement = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _agreements = const [];
          _agreement = null;
        });
      }
    }
    try {
      final contracts = await service.getContracts(
          partnerUid: partner.uid, contractorUid: '');
      if (mounted) {
        setState(() {
          _contracts = contracts;
          _contract = contracts.isNotEmpty ? contracts.first : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contracts = const [];
          _contract = null;
        });
      }
    }
    try {
      final debts = await service.getReceivables(
          partnerUid: partner.uid, contractorUid: '');
      if (mounted) setState(() => _debts = debts);
    } catch (_) {
      if (mounted) setState(() => _debts = const []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickItem(_OrderLineData line) async {
    final selected = await _searchReference(
      title: 'Оберіть номенклатуру',
      search: (query) => context.read<SalesService>().searchCatalog(
            query,
            warehouseUid: _agreementWarehouse()?.uid ?? '',
          ),
      showStock: true,
    );
    if (selected == null || !mounted) return;
    await _selectItem(line, selected);
  }

  Future<void> _selectItem(_OrderLineData line, SalesReference selected) async {
    if (!mounted) return;
    setState(() {
      line.item = selected;
      line.name.text = selected.name;
      final boxQuantity = selected.boxQuantity;
      if (boxQuantity != null && boxQuantity > 0) {
        line.quantity.text = _formatNumber(boxQuantity);
      }
    });
    await _refreshPrice(line);
  }

  SalesReference? _agreementPriceType() {
    final agreement = _agreement;
    if (agreement == null || agreement.priceTypeUid.isEmpty) return null;
    return SalesReference(
      uid: agreement.priceTypeUid,
      name: agreement.priceTypeName.isEmpty
          ? 'Вид ціни з оферти'
          : agreement.priceTypeName,
    );
  }

  SalesReference? _agreementWarehouse() {
    final agreement = _agreement;
    if (agreement == null || agreement.warehouseUid.isEmpty) return null;
    return SalesReference(
      uid: agreement.warehouseUid,
      name: agreement.warehouseName.isEmpty
          ? 'Склад з оферти'
          : agreement.warehouseName,
    );
  }

  void _applyAgreementPriceTypeToLines({bool refreshPrices = true}) {
    final priceType = _agreementPriceType();
    if (priceType == null) return;
    if (!_priceTypes.any((item) => item.uid == priceType.uid)) {
      _priceTypes = [priceType, ..._priceTypes];
    }
    for (final line in _lines) {
      if (!line.manualPrice) line.priceType = priceType;
    }
    if (refreshPrices) {
      for (final line in _lines) {
        _refreshPrice(line);
      }
    }
  }

  Future<void> _refreshPrice(_OrderLineData line) async {
    if (line.item == null) return;
    try {
      final price = await context.read<SalesService>().getPrice(
            itemUid: line.item!.uid,
            priceTypeUid: line.priceType?.uid ?? '',
            warehouseUid: _agreementWarehouse()?.uid ?? '',
          );
      if (!mounted) return;
      setState(() {
        if (!line.manualPrice) line.price.text = _formatNumber(price.price);
      });
    } catch (_) {
      // Цена может отсутствовать: пользователь сможет ввести вручную.
    }
  }

  Future<SalesReference?> _searchReference({
    required String title,
    required Future<List<SalesReference>> Function(String query) search,
    bool showStock = false,
  }) async {
    final controller = TextEditingController();
    var results = <SalesReference>[];
    var loading = false;
    var initialSearchStarted = false;
    Timer? debounce;
    String? error;
    final selected = await showDialog<SalesReference>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> runSearch() async {
            setDialogState(() {
              loading = true;
              error = null;
            });
            try {
              final found = await search(controller.text);
              setDialogState(() => results = found);
            } catch (e) {
              setDialogState(() => error = '$e');
            } finally {
              setDialogState(() => loading = false);
            }
          }

          void scheduleSearch() {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 350), runSearch);
          }

          if (!initialSearchStarted) {
            initialSearchStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) runSearch();
            });
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 680,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Пошук',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Знайти',
                        onPressed: loading ? null : runSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => scheduleSearch(),
                    onSubmitted: (_) => runSearch(),
                  ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: results.isEmpty && !loading
                        ? const Center(child: Text('Нічого не знайдено'))
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                title: Text(item.name),
                                subtitle:
                                    item.code.isEmpty ? null : Text(item.code),
                                trailing: showStock
                                    ? _StockBadge(stock: item.stock)
                                    : null,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Скасувати'),
              ),
            ],
          );
        },
      ),
    );
    debounce?.cancel();
    controller.dispose();
    return selected;
  }

  Future<void> _submit() async {
    final partner = _partner;
    if (partner == null) {
      setState(() => _error = 'Оберіть клієнта');
      return;
    }
    final agreement = _agreement;
    if (agreement == null) {
      setState(() => _error = 'Оберіть оферту');
      return;
    }
    final drafts = <CustomerOrderLineDraft>[];
    for (final line in _lines) {
      final item = line.item;
      final quantity = double.tryParse(line.quantity.text.replaceAll(',', '.'));
      final price = double.tryParse(line.price.text.replaceAll(',', '.'));
      if (item == null || quantity == null || quantity <= 0 || price == null) {
        setState(() => _error = 'Заповніть номенклатуру, кількість та ціну');
        return;
      }
      drafts.add(
        CustomerOrderLineDraft(
          itemUid: item.uid,
          itemName: item.name,
          quantity: quantity,
          price: price,
          priceTypeUid: line.priceType?.uid ?? '',
          manualPrice: line.manualPrice,
        ),
      );
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final number = await context.read<SalesService>().createCustomerOrder(
            partnerUid: partner.uid,
            agreementUid: agreement.uid,
            contractUid: _contract?.uid ?? '',
            shipmentDate: _shipmentDate,
            lines: drafts,
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            number.isEmpty
                ? 'Заказ клиента создан'
                : 'Заказ клиента №$number создан',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double get _draftTotal {
    return _lines.fold<double>(0, (sum, line) {
      final qty = double.tryParse(line.quantity.text.replaceAll(',', '.')) ?? 0;
      final price = double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0;
      return sum + qty * price;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1000;
    final compact = width < 620;
    return ListView(
      padding: EdgeInsets.all(desktop ? 28 : 16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Новий заказ клієнта',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (!compact) _CreateOrderButton(busy: _busy, onPressed: _submit),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
          ),
        if (compact) ...[
          _MobileOrderDraftHero(
            partner: _partner?.name ?? '',
            agreement: _agreement?.name ?? '',
            contract: _contract?.name ?? '',
            shipmentDate: _formatDate(_shipmentDate),
            total: _formatNumber(_draftTotal),
            lines: _lines.length,
          ),
          const SizedBox(height: 14),
        ],
        _Section(
          title: 'Клієнт та умови',
          child: _ResponsiveFields(
            children: [
              _ReferenceAutocompleteField(
                label: 'Клієнт / партнер',
                value: _partner,
                search: (query) =>
                    context.read<SalesService>().searchPartners(query),
                onSelected: (value) => _selectPartner(value),
              ),
              _ReferenceAutocompleteField(
                label: 'Оферта',
                value: _agreement,
                options: _agreements,
                enabled: _agreements.isNotEmpty,
                helperText: _agreementWarehouse()?.name,
                emptyText: _busy ? 'Завантаження...' : 'Оферти не знайдені',
                itemBuilder: (context, item) =>
                    _AgreementMenuItem(agreement: item),
                onSelected: (value) {
                  setState(() {
                    _agreement = value;
                    _applyAgreementPriceTypeToLines();
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _contract?.uid,
                decoration: const InputDecoration(labelText: 'Договір'),
                disabledHint:
                    Text(_busy ? 'Завантаження...' : 'Договори не знайдені'),
                items: [
                  for (final item in _contracts)
                    DropdownMenuItem(value: item.uid, child: Text(item.name)),
                ],
                onChanged: _contracts.isEmpty
                    ? null
                    : (value) => setState(
                          () => _contract = _contracts
                              .where((item) => item.uid == value)
                              .firstOrNull,
                        ),
              ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата відвантаження',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(_formatDate(_shipmentDate)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DebtPanel(rows: _debts),
        const SizedBox(height: 14),
        _Section(
          title: 'Товари',
          trailing: OutlinedButton.icon(
            onPressed: () => setState(
              () => _lines.add(
                _OrderLineData(
                  priceType: _agreementPriceType() ?? _priceTypes.firstOrNull,
                ),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Додати рядок'),
          ),
          child: Column(
            children: [
              for (var index = 0; index < _lines.length; index++) ...[
                _LineEditor(
                  index: index,
                  line: _lines[index],
                  priceTypes: _priceTypes,
                  canRemove: _lines.length > 1,
                  onPickItem: () => _pickItem(_lines[index]),
                  itemSearch: (query) =>
                      context.read<SalesService>().searchCatalog(
                            query,
                            warehouseUid: _agreementWarehouse()?.uid ?? '',
                          ),
                  onItemSelected: (value) => _selectItem(_lines[index], value),
                  onRefreshPrice: () => _refreshPrice(_lines[index]),
                  onRemove: () {
                    final removed = _lines.removeAt(index);
                    removed.dispose();
                    setState(() {});
                  },
                  onChanged: () => setState(() {}),
                ),
                if (index != _lines.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Коментар'),
        ),
        const SizedBox(height: 16),
        _CreateOrderButton(
          busy: _busy,
          onPressed: _submit,
          expanded: true,
        ),
      ],
    );
  }
}

class _CreateOrderButton extends StatelessWidget {
  const _CreateOrderButton({
    required this.busy,
    required this.onPressed,
    this.expanded = false,
  });

  final bool busy;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: const Text('Створити'),
    );
    if (!expanded) return button;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: button,
    );
  }
}

class _MobileOrderDraftHero extends StatelessWidget {
  const _MobileOrderDraftHero({
    required this.partner,
    required this.agreement,
    required this.contract,
    required this.shipmentDate,
    required this.total,
    required this.lines,
  });

  final String partner;
  final String agreement;
  final String contract;
  final String shipmentDate;
  final String total;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = partner.trim().isEmpty ? 'Новий клієнтський заказ' : partner;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$total грн',
            style: TextStyle(
              color: cs.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DraftChip(
                icon: Icons.calendar_month_outlined,
                value: shipmentDate,
                color: cs.primary,
              ),
              _DraftChip(
                icon: Icons.receipt_long_outlined,
                value: '$lines ряд.',
                color: const Color(0xFF14B8A6),
              ),
              _DraftChip(
                icon: Icons.sell_outlined,
                value:
                    agreement.trim().isEmpty ? 'Оферта не вибрана' : agreement,
                color: const Color(0xFFF59E0B),
              ),
              if (contract.trim().isNotEmpty)
                _DraftChip(
                  icon: Icons.description_outlined,
                  value: contract,
                  color: const Color(0xFF0EA5E9),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftChip extends StatelessWidget {
  const _DraftChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLineEditorLayout extends StatelessWidget {
  const _MobileLineEditorLayout({
    required this.itemField,
    required this.quantityCell,
    required this.priceTypeSelector,
    required this.priceCell,
    required this.manualSwitch,
    required this.total,
  });

  final Widget itemField;
  final Widget quantityCell;
  final Widget priceTypeSelector;
  final Widget priceCell;
  final Widget manualSwitch;
  final Widget total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        itemField,
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(child: _MobileMetricHeader('Кількість')),
            SizedBox(width: 8),
            Expanded(child: _MobileMetricHeader('Ціна')),
            SizedBox(width: 8),
            Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: quantityCell),
            const SizedBox(width: 8),
            Expanded(child: priceCell),
            const SizedBox(width: 8),
            Expanded(child: total),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: priceTypeSelector),
            const SizedBox(width: 8),
            SizedBox(width: 152, child: manualSwitch),
          ],
        ),
      ],
    );
  }
}

class _MobileMetricHeader extends StatelessWidget {
  const _MobileMetricHeader(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .58),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _MobileTinyNumberField extends StatelessWidget {
  const _MobileTinyNumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: enabled
              ? cs.outlineVariant.withValues(alpha: .72)
              : cs.outlineVariant.withValues(alpha: .38),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: TextStyle(
          color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: .58),
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _MobilePriceTypeSelector extends StatelessWidget {
  const _MobilePriceTypeSelector({
    required this.line,
    required this.priceTypes,
    required this.onSelected,
  });

  final _OrderLineData line;
  final List<SalesReference> priceTypes;
  final ValueChanged<SalesReference?> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = !line.manualPrice && priceTypes.isNotEmpty;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'Вид ціни',
      onSelected: (value) => onSelected(
        priceTypes.where((item) => item.uid == value).firstOrNull,
      ),
      itemBuilder: (context) => [
        for (final item in priceTypes)
          PopupMenuItem(
            value: item.uid,
            child:
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: .34),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                enabled ? cs.primary.withValues(alpha: .5) : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.sell_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                line.priceType?.name ?? 'Вид ціни',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: .52),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: .62),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLineTotal extends StatelessWidget {
  const _MobileLineTotal({required this.line});

  final _OrderLineData line;

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(line.quantity.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0;
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .72)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        _formatNumber(qty * price),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.index,
    required this.line,
    required this.priceTypes,
    required this.canRemove,
    required this.onPickItem,
    required this.itemSearch,
    required this.onItemSelected,
    required this.onRefreshPrice,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _OrderLineData line;
  final List<SalesReference> priceTypes;
  final bool canRemove;
  final VoidCallback onPickItem;
  final Future<List<SalesReference>> Function(String query) itemSearch;
  final ValueChanged<SalesReference> onItemSelected;
  final VoidCallback onRefreshPrice;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final itemField = _ReferenceAutocompleteField(
      label: 'Номенклатура',
      value: line.item,
      search: itemSearch,
      showStock: true,
      onSelected: onItemSelected,
      onOpenDialog: onPickItem,
    );
    final quantityField = TextField(
      controller: line.quantity,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Кількість'),
      onChanged: (_) => onChanged(),
    );
    final priceTypeField = DropdownButtonFormField<String>(
      initialValue: line.priceType?.uid,
      decoration: const InputDecoration(labelText: 'Вид ціни'),
      items: [
        for (final item in priceTypes)
          DropdownMenuItem(
            value: item.uid,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: line.manualPrice
          ? null
          : (value) {
              line.priceType =
                  priceTypes.where((item) => item.uid == value).firstOrNull;
              onRefreshPrice();
            },
    );
    final priceField = TextField(
      controller: line.price,
      enabled: line.manualPrice,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Ціна'),
      onChanged: (_) => onChanged(),
    );
    final manualSwitch = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            'Довільна',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Switch(
          value: line.manualPrice,
          onChanged: (value) {
            line.manualPrice = value;
            onChanged();
            if (!value) onRefreshPrice();
          },
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Рядок ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                tooltip: 'Видалити рядок',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1120) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 34, child: itemField),
                    const SizedBox(width: 10),
                    SizedBox(width: 120, child: quantityField),
                    const SizedBox(width: 10),
                    Expanded(flex: 24, child: priceTypeField),
                    const SizedBox(width: 10),
                    SizedBox(width: 130, child: priceField),
                    const SizedBox(width: 10),
                    SizedBox(width: 128, child: _LineTotal(line: line)),
                    const SizedBox(width: 10),
                    SizedBox(width: 132, child: manualSwitch),
                  ],
                );
              }

              if (constraints.maxWidth < 620) {
                return _MobileLineEditorLayout(
                  itemField: itemField,
                  quantityCell: _MobileTinyNumberField(
                    label: 'Кількість',
                    controller: line.quantity,
                    onChanged: (_) => onChanged(),
                  ),
                  priceTypeSelector: _MobilePriceTypeSelector(
                    line: line,
                    priceTypes: priceTypes,
                    onSelected: (value) {
                      line.priceType = value;
                      onChanged();
                      onRefreshPrice();
                    },
                  ),
                  priceCell: _MobileTinyNumberField(
                    label: 'Ціна',
                    controller: line.price,
                    enabled: line.manualPrice,
                    onChanged: (_) => onChanged(),
                  ),
                  manualSwitch: manualSwitch,
                  total: _MobileLineTotal(line: line),
                );
              }

              return _ResponsiveFields(
                children: [
                  itemField,
                  quantityField,
                  priceTypeField,
                  priceField,
                  SwitchListTile(
                    value: line.manualPrice,
                    onChanged: (value) {
                      line.manualPrice = value;
                      onChanged();
                      if (!value) onRefreshPrice();
                    },
                    title: const Text('Довільна ціна'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  _LineTotal(line: line),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AgreementMenuItem extends StatelessWidget {
  const _AgreementMenuItem({required this.agreement});

  final SalesReference agreement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIndividual = agreement.kind == 'individual';
    final label = agreement.kindLabel.isEmpty
        ? (isIndividual ? 'Індивідуальна' : 'Загальна')
        : agreement.kindLabel;
    return Row(
      children: [
        Expanded(
          child: Text(
            agreement.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (agreement.kind.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isIndividual
                  ? cs.tertiaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isIndividual ? cs.tertiary : cs.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color:
                    isIndividual ? cs.onTertiaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LineTotal extends StatelessWidget {
  const _LineTotal({required this.line});

  final _OrderLineData line;

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(line.quantity.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0;
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Сума'),
      child: Text(
        _formatNumber(qty * price),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final double? stock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = stock;
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        value == null ? '-' : _formatNumber(value),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DebtPanel extends StatelessWidget {
  const _DebtPanel({required this.rows});

  final List<SalesDebtRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDebt = rows.fold<double>(0, (sum, row) => sum + row.debt);
    final totalPrepayment =
        rows.fold<double>(0, (sum, row) => sum + row.prepayment);
    final totalBalance = rows.fold<double>(0, (sum, row) => sum + row.balance);
    return _Section(
      title: 'Дебіторка',
      child: rows.isEmpty
          ? Text(
              'Дані по розрахунках ще не завантажені або відсутні.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .62)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DebtRow(
                  contract: 'Договір',
                  debt: 'Борг',
                  prepayment: 'Передплата',
                  balance: 'Сальдо',
                  header: true,
                ),
                const Divider(height: 1),
                for (final row in rows)
                  _DebtRow(
                    contract: row.contract.isEmpty ? 'Договір' : row.contract,
                    debt: _formatNumber(row.debt),
                    prepayment: _formatNumber(row.prepayment),
                    balance: _formatNumber(row.balance),
                  ),
                const Divider(height: 1),
                _DebtRow(
                  contract: 'Разом',
                  debt: _formatNumber(totalDebt),
                  prepayment: _formatNumber(totalPrepayment),
                  balance: _formatNumber(totalBalance),
                  header: true,
                ),
              ],
            ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.contract,
    required this.debt,
    required this.prepayment,
    required this.balance,
    this.header = false,
  });

  final String contract;
  final String debt;
  final String prepayment;
  final String balance;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 13 : 14,
      fontWeight: header ? FontWeight.w900 : FontWeight.w700,
    );
    final mutedStyle = style.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .72),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              contract,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: header ? mutedStyle : style,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(debt, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(prepayment, textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(balance, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _ReferenceAutocompleteField extends StatefulWidget {
  const _ReferenceAutocompleteField({
    required this.label,
    required this.value,
    required this.onSelected,
    this.search,
    this.options,
    this.enabled = true,
    this.showStock = false,
    this.helperText,
    this.emptyText = 'Нічого не знайдено',
    this.itemBuilder,
    this.onOpenDialog,
  });

  final String label;
  final SalesReference? value;
  final ValueChanged<SalesReference> onSelected;
  final Future<List<SalesReference>> Function(String query)? search;
  final List<SalesReference>? options;
  final bool enabled;
  final bool showStock;
  final String? helperText;
  final String emptyText;
  final Widget Function(BuildContext context, SalesReference item)? itemBuilder;
  final VoidCallback? onOpenDialog;

  @override
  State<_ReferenceAutocompleteField> createState() =>
      _ReferenceAutocompleteFieldState();
}

class _ReferenceAutocompleteFieldState
    extends State<_ReferenceAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SalesReference> _options = const [];
  Timer? _debounce;
  bool _loading = false;
  bool _syncingText = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value?.name ?? '';
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _runSearch(_controller.text);
    });
    _refreshLocalOptions(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _ReferenceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value?.name ?? '';
    if (nextText != _controller.text && !_focusNode.hasFocus) {
      _syncingText = true;
      _controller.text = nextText;
      _syncingText = false;
    }
    if (oldWidget.options != widget.options) {
      _refreshLocalOptions(_controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_syncingText) return;
    final text = _controller.text;
    if (widget.search != null) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _runSearch(text);
      });
    } else {
      _refreshLocalOptions(text);
    }
  }

  void _refreshLocalOptions(String query) {
    final source = widget.options ?? const <SalesReference>[];
    final needle = query.trim().toLowerCase();
    setState(() {
      _options = needle.isEmpty
          ? source
          : source
              .where(
                (item) =>
                    item.name.toLowerCase().contains(needle) ||
                    item.code.toLowerCase().contains(needle),
              )
              .toList();
    });
  }

  Future<void> _runSearch(String query) async {
    final search = widget.search;
    if (search == null || !widget.enabled) return;
    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final found = await search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() => _options = found);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _options = const []);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RawAutocomplete<SalesReference>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (_) => widget.enabled ? _options : const [],
      onSelected: (value) {
        _syncingText = true;
        _controller.text = value.name;
        _syncingText = false;
        widget.onSelected(value);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.enabled ? widget.helperText : widget.emptyText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (widget.onOpenDialog != null)
                  IconButton(
                    tooltip: 'Відкрити список',
                    onPressed: widget.onOpenDialog,
                    icon: const Icon(Icons.open_in_new_rounded),
                  )
                else
                  const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
          onTap: () => _runSearch(controller.text),
          onSubmitted: (_) {
            if (_options.isNotEmpty) {
              widget.onSelected(_options.first);
              _syncingText = true;
              controller.text = _options.first.name;
              _syncingText = false;
              focusNode.unfocus();
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 10,
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 720),
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(widget.emptyText),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          dense: true,
                          title: widget.itemBuilder?.call(context, item) ??
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          subtitle: item.code.isEmpty ? null : Text(item.code),
                          trailing: widget.showStock
                              ? _StockBadge(stock: item.stock)
                              : null,
                          onTap: () => onSelected(item),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
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

class _OrderLineData {
  _OrderLineData({this.priceType});

  SalesReference? item;
  SalesReference? priceType;
  bool manualPrice = false;
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
