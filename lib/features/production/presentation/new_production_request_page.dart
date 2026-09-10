import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../production_service.dart';

const _productionOrderGroups = ['Зерно', 'ХмельИДрожжи', 'Компоненты', 'Тара'];

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
  String? _organizationCode;
  String? _sourceWarehouseUid;
  String? _destinationWarehouseUid;
  DateTime _requiredDate = DateTime.now();
  List<OrgAccess> _orgs = const [];
  List<ProductionReference> _sourceWarehouses = const [];
  List<ProductionReference> _destinationWarehouses = const [];
  List<ProductionReference> _catalog = const [];
  List<ProductionTemplate> _templates = const [];
  List<SubdivisionAccess> _subdivisions = const [];
  String? _defaultSubdivisionUid;
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
    List<ProductionReference> catalog = const [];
    List<ProductionTemplate> templates = const [];
    SessionData? session;

    try {
      session = await SessionStore.loadSession();
    } catch (_) {
      // Організація/підрозділ для ручного режиму підтягнуться, якщо є сесія.
    }
    try {
      templates = await service.getTemplates();
    } catch (_) {
      // Шаблони загружаются независимо от ручного режима.
    }
    try {
      catalog = await service.getCatalog();
    } catch (_) {
      // Каталог не требуется для создания по шаблону.
    }

    if (!mounted) return;
    setState(() {
      _orgs = session?.orgs ?? const [];
      _organizationCode = _orgs.isNotEmpty ? _orgs.first.code : null;
      _catalog = catalog;
      _templates = templates;
      _subdivisions = session?.subdivisions ?? const [];
    });
    await _reloadWarehouses();
  }

  String? get _warehouseTemplateType => switch (_type) {
        ProductionRequestType.rawMaterial => 'Сырье',
        ProductionRequestType.bottling => 'Тара',
        ProductionRequestType.returnToStock =>
          _warehouseGroup == 'Тара' ? 'Тара' : 'Сырье',
        ProductionRequestType.finishedGoods => null,
      };

  String? get _warehouseGroup {
    if (_type == ProductionRequestType.finishedGoods) return null;
    if (_type == ProductionRequestType.bottling) return 'Тара';
    return _lines.isEmpty ? null : _lines.first.group;
  }

  Future<void> _reloadWarehouses() async {
    final orgCode = _organizationCode;
    final templateType = _warehouseTemplateType;
    if (orgCode == null || orgCode.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _sourceWarehouses = const [];
        _destinationWarehouses = const [];
        _sourceWarehouseUid = null;
        _destinationWarehouseUid = null;
      });
      return;
    }

    final service = context.read<ProductionService>();
    Future<List<ProductionReference>> loadWarehouses(String role) async {
      Future<List<ProductionReference>> load({
        String? templateTypeValue,
        String? groupValue,
        String? orgCodeValue,
      }) {
        return service.getWarehouses(
          orgCode: orgCodeValue ?? orgCode,
          templateType: templateTypeValue,
          group: groupValue,
          requestType: _type,
          warehouseRole: role,
        );
      }

      final group = _warehouseGroup;
      final attempts = [
        () => load(templateTypeValue: templateType, groupValue: group),
        () => load(templateTypeValue: templateType),
        () => load(groupValue: group),
        () => load(),
        () => load(orgCodeValue: ''),
        () => service.getWarehouses(),
        () => service.getWarehousesFromRules(
              orgCode: orgCode,
              templateType: templateType,
              group: group,
              requestType: _type,
              warehouseRole: role,
            ),
      ];
      for (final attempt in attempts) {
        try {
          final warehouses = await attempt();
          if (warehouses.isNotEmpty) return warehouses;
        } catch (_) {
          // Наступна спроба йде з ширшим фільтром.
        }
      }
      return const [];
    }

    final source = await loadWarehouses('source');
    final destination = await loadWarehouses('destination');

    if (!mounted) return;
    setState(() {
      _sourceWarehouses = source;
      _destinationWarehouses = destination;
      if (!_sourceWarehouses.any((item) => item.uid == _sourceWarehouseUid)) {
        _sourceWarehouseUid =
            _sourceWarehouses.length == 1 ? _sourceWarehouses.first.uid : null;
      }
      if (!_destinationWarehouses
          .any((item) => item.uid == _destinationWarehouseUid)) {
        _destinationWarehouseUid = _destinationWarehouses.length == 1
            ? _destinationWarehouses.first.uid
            : null;
      }
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

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _requiredDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _requiredDate = value);
  }

  String? get _templateType => switch (_type) {
        ProductionRequestType.rawMaterial => 'Сырье',
        ProductionRequestType.bottling => 'Тара',
        _ => null,
      };

  String get _manualDirection => switch (_type) {
        ProductionRequestType.rawMaterial => 'Сырье',
        ProductionRequestType.bottling => 'Тара',
        ProductionRequestType.finishedGoods => 'ГотоваяПродукция',
        ProductionRequestType.returnToStock => 'Возврат',
      };

  Future<void> _useTemplate() async {
    final templateType = _templateType;
    final matching = templateType == null
        ? _templates
        : _templates
            .where((template) => template.templateType == templateType)
            .toList();
    final templates = matching.isEmpty ? _templates : matching;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спочатку створіть виробничий шаблон')),
      );
      return;
    }

    final selected = await showDialog<ProductionTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оберіть виробничий шаблон'),
        content: SizedBox(
          width: 680,
          height: 440,
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(template.name),
                subtitle: Text(
                  '${template.organizationName} · ${template.drinkType} · '
                  'позицій: ${template.lines.length}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, template),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _createFromTemplate(selected);
  }

  String? _defaultTemplateSubdivisionUid() {
    final defaultUid = _defaultSubdivisionUid?.trim() ?? '';
    if (defaultUid.isNotEmpty &&
        _subdivisions.any((item) => item.uid == defaultUid)) {
      return defaultUid;
    }
    if (_subdivisions.length == 1) return _subdivisions.first.uid;
    return null;
  }

  Future<void> _createFromTemplate(ProductionTemplate template) async {
    final volume = TextEditingController(
      text: template.baseVolume.toStringAsFixed(
        template.baseVolume == template.baseVolume.roundToDouble() ? 0 : 2,
      ),
    );
    final comment = TextEditingController();
    var date = _requiredDate;
    String? subdivisionUid = _defaultTemplateSubdivisionUid();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Створити переміщення за шаблоном «${template.name}»'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: volume,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Обсяг'),
                ),
                const SizedBox(height: 12),
                if (_subdivisions.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: subdivisionUid,
                    decoration: const InputDecoration(labelText: 'Підрозділ'),
                    items: [
                      for (final subdivision in _subdivisions)
                        DropdownMenuItem(
                          value: subdivision.uid,
                          child: Text(subdivision.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => subdivisionUid = value),
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Бажана дата'),
                  subtitle: Text(_formatDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selected != null) {
                      setDialogState(() => date = selected);
                    }
                  },
                ),
                TextField(
                  controller: comment,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Коментар'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Створити переміщення'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      volume.dispose();
      comment.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      final parsed = double.tryParse(volume.text.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) {
        throw Exception('Вкажіть коректний обсяг');
      }
      await context.read<ProductionService>().createFromTemplate(
            templateUid: template.uid,
            volume: parsed,
            requiredDate: date,
            subdivisionUid: subdivisionUid ?? '',
            comment: comment.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Переміщення за шаблоном створено')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося створити переміщення: $e')),
        );
      }
    } finally {
      volume.dispose();
      comment.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ProductionReference?> _pickCatalogItem({String? group}) async {
    final search = TextEditingController();
    var results = group == null || group.trim().isEmpty
        ? _catalog.take(30).toList()
        : <ProductionReference>[];
    var loading = false;
    String? error;
    Timer? searchDebounce;
    var initialSearchStarted = false;

    final selected = await showDialog<ProductionReference>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> runSearch() async {
            setDialogState(() {
              loading = true;
              error = null;
            });
            try {
              final found =
                  await context.read<ProductionService>().searchCatalog(
                        search.text.trim(),
                        orgCode: _organizationCode,
                        templateType: _warehouseTemplateType,
                        group: group,
                      );
              setDialogState(() => results = found);
            } catch (e) {
              setDialogState(() => error = '$e');
            } finally {
              setDialogState(() => loading = false);
            }
          }

          void scheduleSearch(String value) {
            searchDebounce?.cancel();
            searchDebounce = Timer(const Duration(milliseconds: 320), () {
              if (!dialogContext.mounted) return;
              runSearch();
            });
          }

          if (!initialSearchStarted) {
            initialSearchStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!dialogContext.mounted) return;
              runSearch();
            });
          }

          return AlertDialog(
            title: const Text('Оберіть номенклатуру'),
            content: SizedBox(
              width: 680,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Пошук за назвою або кодом',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Знайти',
                        onPressed: loading ? null : runSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: scheduleSearch,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Номенклатура',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        SizedBox(
                          width: 112,
                          child: Text(
                            'Залишок',
                            textAlign: TextAlign.right,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty && !loading
                        ? const Center(child: Text('Нічого не знайдено'))
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              final stock = item.stock;
                              final stockColor = stock == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                  : stock <= 0
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.primary;
                              return ListTile(
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(item.name),
                                subtitle:
                                    item.code.isEmpty ? null : Text(item.code),
                                trailing: SizedBox(
                                  width: 112,
                                  child: Text(
                                    stock == null
                                        ? '-'
                                        : [
                                            _formatQuantity(stock),
                                            item.stockUnit,
                                          ]
                                            .where((part) => part.isNotEmpty)
                                            .join(' '),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: stockColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
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
    searchDebounce?.cancel();
    search.dispose();
    if (selected != null && !_catalog.any((item) => item.uid == selected.uid)) {
      setState(() => _catalog = [..._catalog, selected]);
    }
    return selected;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _submit() async {
    final orgCode = _organizationCode?.trim();
    if (orgCode == null || orgCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть організацію')),
      );
      return;
    }

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
          unit: line.unit.trim(),
          group: line.group,
        ),
      );
    }

    setState(() => _busy = true);
    try {
      await context.read<ProductionService>().createRequest(
            type: _type,
            orgCode: orgCode,
            direction: _manualDirection,
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
            8,
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 1280),
              padding: const EdgeInsets.all(14),
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
                          _sourceWarehouseUid = null;
                          _destinationWarehouseUid = null;
                        });
                        unawaited(_reloadWarehouses());
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TemplateActionPanel(
                    templatesCount: _templates.length,
                    busy: _busy,
                    onUseTemplate: _useTemplate,
                    onManageTemplates: () =>
                        context.push('/production/templates'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Ручне заповнення',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Divider(color: border)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ResponsiveFields(
                    children: [
                      if (_orgs.length > 1)
                        DropdownButtonFormField<String>(
                          initialValue: _organizationCode,
                          decoration: const InputDecoration(
                            labelText: 'Організація',
                          ),
                          items: [
                            for (final org in _orgs)
                              DropdownMenuItem(
                                value: org.code,
                                child: Text(org.name),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _organizationCode = value;
                              _sourceWarehouseUid = null;
                              _destinationWarehouseUid = null;
                            });
                            unawaited(_reloadWarehouses());
                          },
                        ),
                      _warehouseField(
                        label: 'Склад-відправник',
                        value: _sourceWarehouseUid,
                        items: _sourceWarehouses,
                        onChanged: (value) =>
                            setState(() => _sourceWarehouseUid = value),
                      ),
                      _warehouseField(
                        label: 'Склад-отримувач',
                        value: _destinationWarehouseUid,
                        items: _destinationWarehouses,
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
                  const SizedBox(height: 14),
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
                        onPressed: () => setState(
                            () => _lines.insert(0, _LineControllers())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Додати рядок'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _lines.length; index++) ...[
                    _ProductLineEditor(
                      index: index,
                      line: _lines[index],
                      catalog: _catalog,
                      onPickItem: () async {
                        final selected = await _pickCatalogItem(
                          group: _lines[index].group,
                        );
                        if (selected == null) return;
                        setState(() {
                          _lines[index].itemUid = selected.uid;
                          _lines[index].name.text = selected.name;
                          _lines[index].unit = selected.stockUnit;
                        });
                      },
                      canRemove: _lines.length > 1,
                      onRemove: () {
                        final removed = _lines.removeAt(index);
                        removed.dispose();
                        setState(() {});
                      },
                      onChanged: () {
                        setState(() {});
                        unawaited(_reloadWarehouses());
                      },
                    ),
                    if (index != _lines.length - 1) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Коментар'),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy ||
                              _sourceWarehouses.isEmpty ||
                              _destinationWarehouses.isEmpty
                          ? null
                          : _submit,
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
    required List<ProductionReference> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(
        '$label-${value ?? ''}-${items.map((item) => item.uid).join('|')}',
      ),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final warehouse in items)
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

class _TemplateActionPanel extends StatelessWidget {
  const _TemplateActionPanel({
    required this.templatesCount,
    required this.busy,
    required this.onUseTemplate,
    required this.onManageTemplates,
  });

  final int templatesCount;
  final bool busy;
  final VoidCallback onUseTemplate;
  final VoidCallback onManageTemplates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: .42)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Створити за виробничим шаблоном',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Склади, товари та кількість заповняться автоматично. '
                      'Доступно шаблонів: $templatesCount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Керування шаблонами',
                onPressed: onManageTemplates,
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: busy ? null : onUseTemplate,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Використати шаблон'),
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
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
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 800
                ? 2
                : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 8,
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
    required this.onPickItem,
    required this.onChanged,
  });

  final int index;
  final _LineControllers line;
  final List<ProductionReference> catalog;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickItem;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerTheme.color ?? cs.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth >= 980;
          if (!compact) {
            return Column(
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
                    _groupField(dense: true),
                    _itemField(dense: true),
                    _quantityField(dense: true),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 170, child: _groupField(dense: true)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _itemField(dense: true)),
              const SizedBox(width: 10),
              SizedBox(width: 132, child: _quantityField(dense: true)),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Видалити рядок',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          );
        },
      ),
    );
  }

  String _productionGroupLabel(String group) {
    return switch (group) {
      'ХмельИДрожжи' => 'Хміль і дріжджі',
      'Компоненты' => 'Компоненти',
      _ => group,
    };
  }

  bool _matchesProductionGroup(String itemGroup, String selectedGroup) {
    final item = _normalizeProductionGroup(itemGroup);
    if (item.isEmpty) return false;
    final selected = _normalizeProductionGroup(selectedGroup);
    final selectedLabel = _normalizeProductionGroup(
      _productionGroupLabel(selectedGroup),
    );
    return item == selected || item == selectedLabel;
  }

  String _normalizeProductionGroup(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll('і', 'и')
        .replaceAll(RegExp(r'[^а-яa-z0-9]+'), '')
        .trim();
  }

  Widget _groupField({required bool dense}) {
    return DropdownButtonFormField<String>(
      initialValue: line.group,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Група',
        isDense: dense,
      ),
      items: [
        for (final group in _productionOrderGroups)
          DropdownMenuItem(
              value: group, child: Text(_productionGroupLabel(group))),
      ],
      onChanged: (value) {
        line.group = value ?? 'Зерно';
        final selectedUid = line.itemUid;
        if (selectedUid != null &&
            !_filteredCatalog.any((item) => item.uid == selectedUid)) {
          line.itemUid = null;
          line.name.clear();
        }
        onChanged();
      },
    );
  }

  List<ProductionReference> get _filteredCatalog {
    final group = line.group.trim();
    if (group.isEmpty) return catalog;
    final filtered = catalog
        .where((item) => _matchesProductionGroup(item.group, group))
        .toList();
    return filtered;
  }

  Widget _itemField({required bool dense}) {
    ProductionReference? value;
    for (final item in catalog) {
      if (item.uid == line.itemUid) {
        value = item;
        break;
      }
    }
    value ??= line.itemUid == null || line.name.text.trim().isEmpty
        ? null
        : ProductionReference(uid: line.itemUid!, name: line.name.text.trim());
    return _CatalogPickerField(
      label: 'Номенклатура',
      value: value,
      onTap: onPickItem,
    );
  }

  Widget _quantityField({required bool dense}) {
    final unit = line.unit.trim();
    return TextField(
      controller: line.quantity,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: unit.isEmpty ? 'Кількість' : 'Кількість, $unit',
        isDense: dense,
      ),
    );
  }
}

class _CatalogPickerField extends StatelessWidget {
  const _CatalogPickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final ProductionReference? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: const Icon(Icons.chevron_right_rounded),
        ),
        isEmpty: value == null,
        child: Text(
          value?.name ?? 'Натисніть, щоб знайти',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _LineControllers {
  String? itemUid;
  String unit = '';
  final name = TextEditingController();
  String group = 'Зерно';
  final quantity = TextEditingController();

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}
