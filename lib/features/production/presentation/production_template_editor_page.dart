import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../production_service.dart';

class ProductionTemplateEditorPage extends StatefulWidget {
  const ProductionTemplateEditorPage({super.key, this.uid});

  final String? uid;

  @override
  State<ProductionTemplateEditorPage> createState() =>
      _ProductionTemplateEditorPageState();
}

class _ProductionTemplateEditorPageState
    extends State<ProductionTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseVolume = TextEditingController(text: '2');
  final _comment = TextEditingController();
  final List<_LineData> _lines = [];
  List<ProductionReference> _catalog = const [];
  List<OrgAccess> _orgs = const [];
  String? _organizationCode;
  String _templateType = 'Сырье';
  String _drinkType = 'Пиво';
  String? _productUid;
  bool _active = true;
  bool _busy = false;
  bool _loading = true;
  String? _error;

  bool get _editing => widget.uid != null && widget.uid!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = context.read<ProductionService>();
      final session = await SessionStore.loadSession();
      _orgs = session?.orgs ?? const [];
      try {
        _catalog = await service.getCatalog();
      } catch (_) {
        _catalog = const [];
      }
      if (_editing) {
        _applyTemplate(await service.getTemplate(widget.uid!));
      } else {
        _organizationCode = _orgs.isNotEmpty ? _orgs.first.code : null;
        _lines.add(_LineData());
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyTemplate(ProductionTemplate template) {
    final knownUids = _catalog.map((item) => item.uid).toSet();
    final missing = <ProductionReference>[];
    if (template.productUid.isNotEmpty &&
        !knownUids.contains(template.productUid)) {
      missing.add(
        ProductionReference(
            uid: template.productUid, name: template.productName),
      );
      knownUids.add(template.productUid);
    }
    for (final line in template.lines) {
      if (line.itemUid.isNotEmpty && !knownUids.contains(line.itemUid)) {
        missing
            .add(ProductionReference(uid: line.itemUid, name: line.itemName));
        knownUids.add(line.itemUid);
      }
    }
    _catalog = [..._catalog, ...missing];
    _name.text = template.name;
    _baseVolume.text = template.baseVolume.toString();
    _comment.text = template.comment;
    final organization = _orgs
        .where(
          (item) =>
              item.code == template.organizationCode ||
              item.name.trim().toLowerCase() ==
                  template.organizationName.trim().toLowerCase(),
        )
        .firstOrNull;
    _organizationCode = organization?.code ??
        (_orgs.isNotEmpty ? _orgs.first.code : template.organizationCode);
    _templateType = template.templateType;
    _drinkType = template.drinkType;
    _productUid = template.productUid.isEmpty ? null : template.productUid;
    _active = template.active;
    for (final line in template.lines) {
      _lines.add(_LineData.fromTemplate(line));
    }
    if (_lines.isEmpty) _lines.add(_LineData());
  }

  @override
  void dispose() {
    _name.dispose();
    _baseVolume.dispose();
    _comment.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_organizationCode == null) {
      setState(() => _error = 'Оберіть організацію');
      return;
    }
    final templateLines = <ProductionTemplateLine>[];
    for (final line in _lines) {
      final quantity = double.tryParse(line.quantity.text.replaceAll(',', '.'));
      if (line.itemUid == null || quantity == null || quantity <= 0) {
        setState(() => _error = 'Заповніть номенклатуру та кількість');
        return;
      }
      final item = _catalog.firstWhere((item) => item.uid == line.itemUid);
      templateLines.add(
        ProductionTemplateLine(
          group: line.group,
          itemUid: line.itemUid!,
          itemName: item.name,
          quantity: quantity,
          required: line.required,
          comment: line.comment.text.trim(),
        ),
      );
    }
    final org = _orgs.firstWhere((item) => item.code == _organizationCode);
    final base = double.tryParse(_baseVolume.text.replaceAll(',', '.')) ?? 0;
    final product =
        _catalog.where((item) => item.uid == _productUid).firstOrNull;
    final template = ProductionTemplate(
      uid: widget.uid ?? '',
      name: _name.text.trim(),
      organizationUid: '',
      organizationCode: org.code,
      organizationName: org.name,
      templateType: _templateType,
      drinkType: _drinkType,
      productUid: product?.uid ?? '',
      productName: product?.name ?? '',
      baseVolume: base,
      active: _active,
      comment: _comment.text.trim(),
      lines: templateLines,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = context.read<ProductionService>();
      if (_editing) {
        await service.updateTemplate(template);
      } else {
        await service.createTemplate(template);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ProductionReference?> _pickCatalogItem() async {
    final search = TextEditingController();
    var results = _catalog.take(30).toList();
    var loading = false;
    String? error;

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
              final found = await context
                  .read<ProductionService>()
                  .searchCatalog(search.text.trim());
              setDialogState(() => results = found);
            } catch (e) {
              setDialogState(() => error = '$e');
            } finally {
              setDialogState(() => loading = false);
            }
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
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(item.name),
                                subtitle:
                                    item.code.isEmpty ? null : Text(item.code),
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
    search.dispose();
    if (selected != null && !_catalog.any((item) => item.uid == selected.uid)) {
      setState(() => _catalog = [..._catalog, selected]);
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final desktop = MediaQuery.sizeOf(context).width >= 900;
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
                _editing ? 'Редагування шаблону' : 'Новий виробничий шаблон',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Зберегти'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            color: Colors.red.withValues(alpha: .12),
            child: Text(_error!),
          ),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _Section(
                title: 'Основне',
                child: _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Назва'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Вкажіть назву'
                              : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _organizationCode,
                      decoration:
                          const InputDecoration(labelText: 'Організація'),
                      items: [
                        for (final org in _orgs)
                          DropdownMenuItem(
                            value: org.code,
                            child: Text(org.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _organizationCode = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _templateType,
                      decoration:
                          const InputDecoration(labelText: 'Вид шаблону'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Сырье', child: Text('Сировина')),
                        DropdownMenuItem(value: 'Тара', child: Text('Тара')),
                      ],
                      onChanged: (value) =>
                          setState(() => _templateType = value!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _drinkType,
                      decoration: const InputDecoration(labelText: 'Вид напою'),
                      items: const [
                        DropdownMenuItem(value: 'Пиво', child: Text('Пиво')),
                        DropdownMenuItem(
                          value: 'Лимонад',
                          child: Text('Лимонад'),
                        ),
                        DropdownMenuItem(
                          value: 'НеПрименяется',
                          child: Text('Не застосовується'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _drinkType = value!),
                    ),
                    _CatalogPickerField(
                      label: 'Продукція',
                      value: _catalog
                          .where((item) => item.uid == _productUid)
                          .firstOrNull,
                      onTap: () async {
                        final selected = await _pickCatalogItem();
                        if (selected != null) {
                          setState(() => _productUid = selected.uid);
                        }
                      },
                    ),
                    TextFormField(
                      controller: _baseVolume,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Базовий обсяг'),
                      validator: (value) {
                        final parsed =
                            double.tryParse(value?.replaceAll(',', '.') ?? '');
                        return parsed == null || parsed <= 0
                            ? 'Вкажіть обсяг'
                            : null;
                      },
                    ),
                    SwitchListTile(
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                      title: const Text('Активний'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    TextFormField(
                      controller: _comment,
                      decoration: const InputDecoration(labelText: 'Коментар'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Склад',
                trailing: OutlinedButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineData())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Додати позицію'),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < _lines.length; index++) ...[
                      _LineEditor(
                        line: _lines[index],
                        catalog: _catalog,
                        canRemove: _lines.length > 1,
                        onRemove: () {
                          final line = _lines.removeAt(index);
                          line.dispose();
                          setState(() {});
                        },
                        onChanged: () => setState(() {}),
                        onPickItem: () async {
                          final selected = await _pickCatalogItem();
                          if (selected != null) {
                            setState(
                                () => _lines[index].itemUid = selected.uid);
                          }
                        },
                      ),
                      if (index != _lines.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.line,
    required this.catalog,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.onPickItem,
  });

  final _LineData line;
  final List<ProductionReference> catalog;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: _ResponsiveFields(
        children: [
          DropdownButtonFormField<String>(
            initialValue: line.group,
            decoration: const InputDecoration(labelText: 'Група замовлення'),
            items: const [
              DropdownMenuItem(value: 'Зерно', child: Text('Зерно')),
              DropdownMenuItem(
                value: 'ХмельИДрожжи',
                child: Text('Хміль і дріжджі'),
              ),
              DropdownMenuItem(
                value: 'Компоненты',
                child: Text('Компоненти'),
              ),
              DropdownMenuItem(value: 'Тара', child: Text('Тара')),
            ],
            onChanged: (value) {
              line.group = value!;
              onChanged();
            },
          ),
          _CatalogPickerField(
            label: 'Номенклатура',
            value:
                catalog.where((item) => item.uid == line.itemUid).firstOrNull,
            onTap: onPickItem,
          ),
          TextFormField(
            controller: line.quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Кількість'),
          ),
          TextFormField(
            controller: line.comment,
            decoration: const InputDecoration(labelText: 'Коментар'),
          ),
          CheckboxListTile(
            value: line.required,
            onChanged: (value) {
              line.required = value ?? true;
              onChanged();
            },
            title: const Text('Обов’язково'),
            contentPadding: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Видалити позицію',
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ],
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
          const SizedBox(height: 14),
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

class _LineData {
  _LineData();

  factory _LineData.fromTemplate(ProductionTemplateLine line) {
    return _LineData()
      ..group = line.group
      ..itemUid = line.itemUid
      ..quantity.text = line.quantity.toString()
      ..required = line.required
      ..comment.text = line.comment;
  }

  String group = 'Зерно';
  String? itemUid;
  bool required = true;
  final quantity = TextEditingController();
  final comment = TextEditingController();

  void dispose() {
    quantity.dispose();
    comment.dispose();
  }
}
