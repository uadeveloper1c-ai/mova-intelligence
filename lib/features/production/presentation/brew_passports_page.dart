import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/session_store.dart';
import '../brew_models.dart';
import '../production_service.dart';

class BrewPassportsPage extends StatefulWidget {
  const BrewPassportsPage({super.key});
  @override
  State<BrewPassportsPage> createState() => _BrewPassportsPageState();
}

class _BrewPassportsPageState extends State<BrewPassportsPage> {
  late Future<List<BrewPassport>> _future;
  @override
  void initState() {
    super.initState();
    _future = context.read<ProductionService>().getBrewPassports();
  }

  Future<void> _refresh() async {
    final future = context.read<ProductionService>().getBrewPassports();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Header(
              title: 'Паспорти варок',
              subtitle: 'Партії, ЦКТ та окремі варки',
              action: FilledButton.icon(
                onPressed: () async {
                  await context.push('/production/brew-passports/new');
                  if (mounted) await _refresh();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Новий паспорт'),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<BrewPassport>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Error(error: snapshot.error, retry: _refresh);
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Паспортів варок ще немає')),
                    ),
                  );
                }
                return _BrewPassportTable(
                  items: items,
                  onOpen: (item) async {
                    await context.push(
                      '/production/brew-passports/${item.id}',
                    );
                    if (mounted) await _refresh();
                  },
                );
              },
            ),
          ],
        ),
      );
}

class NewBrewPassportPage extends StatefulWidget {
  const NewBrewPassportPage({super.key});
  @override
  State<NewBrewPassportPage> createState() => _NewBrewPassportPageState();
}

class _NewBrewPassportPageState extends State<NewBrewPassportPage> {
  final _key = GlobalKey<FormState>();
  final _volume = TextEditingController();
  final _comment = TextEditingController();
  List<OrgAccess> _orgs = const [];
  BrewOptions _options = const BrewOptions(ckts: [], recipes: []);
  String? _orgUid;
  String? _cktUid;
  String? _recipeKey;
  DateTime? _bottlingDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 30)),
  );
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _volume.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load([String? selectedOrg]) async {
    final service = context.read<ProductionService>();
    try {
      final session = await SessionStore.loadSession();
      final orgs =
          session?.orgs.where((item) => item.uid.trim().isNotEmpty).toList() ??
              const <OrgAccess>[];
      final uid = selectedOrg ?? (orgs.isEmpty ? null : orgs.first.uid);
      final options = uid == null
          ? const BrewOptions(ckts: [], recipes: [])
          : await service.getBrewOptions(orgUid: uid);
      if (!mounted) return;
      setState(() {
        _orgs = orgs;
        _orgUid = uid;
        _options = options;
        _cktUid = null;
        _recipeKey = null;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  List<BrewRecipeOption> get _matchingRecipes {
    final capacity = _ckt?.capacity ?? 0;
    if (capacity <= 0) return const [];
    return _options.recipes.where((item) {
      final loss = capacity - item.batchVolume;
      final isProductionBatch = item.batchVolume + 0.01 >= item.portionSize;
      return isProductionBatch && loss >= -0.01 && loss < item.portionSize;
    }).toList();
  }

  BrewRecipeOption? get _recipe {
    for (final item in _matchingRecipes) {
      if (item.key == _recipeKey) return item;
    }
    return null;
  }

  BrewCktOption? get _ckt {
    for (final item in _options.ckts) {
      if (item.uid == _cktUid) return item;
    }
    return null;
  }

  double get _plannedVolume =>
      double.tryParse(_volume.text.replaceAll(',', '.')) ?? 0;
  double get _portionSize => _recipe?.portionSize ?? 2000;
  int get _portionCount {
    final size = _portionSize;
    return _plannedVolume <= 0 || size <= 0
        ? 0
        : (_plannedVolume / size).ceil();
  }

  double get _plannedPortionVolume =>
      _portionCount <= 0 ? 0 : _plannedVolume / _portionCount;

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _bottlingDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value != null && mounted) setState(() => _bottlingDate = value);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final recipe = _recipe;
    if (recipe == null || _orgUid == null || _cktUid == null) return;
    setState(() => _saving = true);
    try {
      final passport =
          await context.read<ProductionService>().createBrewPassport(
                CreateBrewPassportDraft(
                  organizationUid: _orgUid!,
                  productUid: recipe.productUid,
                  cktUid: _cktUid!,
                  specificationUid: recipe.specificationUid,
                  plannedVolume: _plannedVolume,
                  portionSize: _portionSize,
                  portionCount: _portionCount,
                  plannedBottlingDate: _bottlingDate,
                  comment: _comment.text,
                ),
              );
      if (mounted) {
        context.go('/production/brew-passports/${passport.id}');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: _Error(error: _error, retry: _load));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _Header(
          title: 'Новий паспорт варки',
          subtitle: 'Номер партії та порції створить 1С',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _orgUid,
                    decoration: const InputDecoration(labelText: 'Організація'),
                    items: _orgs
                        .map((item) => DropdownMenuItem(
                              value: item.uid,
                              child: Text(item.name),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _loading = true);
                              _load(value);
                            }
                          },
                    validator: (value) =>
                        value == null ? 'Оберіть організацію' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _cktUid,
                    decoration: const InputDecoration(labelText: 'ЦКТ'),
                    items: _options.ckts
                        .map((item) => DropdownMenuItem(
                              value: item.uid,
                              child: Text(item.capacity > 0
                                  ? '${item.name} · ${_num(item.capacity)} л'
                                  : item.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _cktUid = value;
                        _recipeKey = null;
                        final capacity = _ckt?.capacity ?? 0;
                        _volume.text = capacity > 0 ? _num(capacity) : '';
                      });
                    },
                    validator: (value) => value == null ? 'Оберіть ЦКТ' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('recipe-$_cktUid'),
                    initialValue: _recipeKey,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _cktUid == null
                          ? 'Спочатку оберіть ЦКТ'
                          : 'Пиво / рецептура',
                    ),
                    items: _matchingRecipes
                        .map((item) => DropdownMenuItem(
                              value: item.key,
                              child: Text(
                                '${item.productName} — '
                                '${item.specificationName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: _cktUid == null
                        ? null
                        : (value) => setState(() {
                              _recipeKey = value;
                              final recipe = _recipe;
                              _volume.text = recipe == null
                                  ? ''
                                  : _num(recipe.batchVolume);
                            }),
                    validator: (value) {
                      if (_cktUid == null) return 'Спочатку оберіть ЦКТ';
                      if (_matchingRecipes.isEmpty) {
                        return 'Для об’єму ЦКТ немає специфікації';
                      }
                      return value == null ? 'Оберіть рецептуру' : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _volume,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Плановий об’єм за рецептурою, л',
                      helperText:
                          'Може бути меншим за об’єм ЦКТ через технологічні втрати',
                    ),
                    validator: (_) =>
                        _plannedVolume <= 0 ? 'Вкажіть об’єм' : null,
                  ),
                  if (_recipe != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Номінал варочного обладнання: ${_num(_portionSize)} л · '
                      'варок: $_portionCount · '
                      'план на варку: ${_num(_plannedPortionVolume)} л',
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_bottlingDate == null
                        ? 'Планова дата розливу: не вказана'
                        : 'Планова дата розливу: ${_date(_bottlingDate!)}'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _comment,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Коментар'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Створити паспорт і порції'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BrewPassportDetailsPage extends StatefulWidget {
  const BrewPassportDetailsPage({super.key, required this.uid});
  final String uid;
  @override
  State<BrewPassportDetailsPage> createState() =>
      _BrewPassportDetailsPageState();
}

class _BrewPassportDetailsPageState extends State<BrewPassportDetailsPage> {
  late Future<BrewPassport> _future;
  @override
  void initState() {
    super.initState();
    _future = context.read<ProductionService>().getBrewPassport(widget.uid);
  }

  Future<void> _refresh() async {
    final future =
        context.read<ProductionService>().getBrewPassport(widget.uid);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BrewPassport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: _Error(error: snapshot.error, retry: _refresh));
          }
          final item = snapshot.data!;
          final readyForColdDepartment = item.portions.isNotEmpty &&
              item.portions.every((portion) => portion.finishedAt != null);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Header(
                  title: 'Партія #${item.batchNumber}',
                  subtitle: '${item.productName} · ${item.cktName}',
                  action: readyForColdDepartment
                      ? FilledButton.icon(
                          onPressed: () =>
                              context.push('/production/cold-department'),
                          icon: const Icon(Icons.ac_unit_rounded),
                          label: const Text('До холодного відділення'),
                        )
                      : null,
                ),
                if (readyForColdDepartment) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .09),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .32),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 19),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Усі варки завершено, ЦКТ заповнена. '
                            'Подальші внесення ведуться у холодному відділенні.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Wrap(
                    children: [
                      _Fact('Статус', item.status),
                      _Fact('План', '${_num(item.plannedVolume)} л'),
                      _Fact('Порція', '${_num(item.portionSize)} л'),
                      _Fact('Кількість варок', '${item.portionCount}'),
                      _Fact('Рецептура', item.specificationName),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Варки',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                if (item.portions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Порції ще не створені'),
                    ),
                  )
                else
                  _BrewPortionsTable(
                    portions: item.portions,
                    onOpen: (portion) async {
                      await context.push(
                        '/production/brew-passports/${item.id}/portions/${portion.id}',
                      );
                      if (mounted) await _refresh();
                    },
                  ),
              ],
            ),
          );
        },
      );
}

class _BrewPassportTable extends StatelessWidget {
  const _BrewPassportTable({required this.items, required this.onOpen});
  final List<BrewPassport> items;
  final ValueChanged<BrewPassport> onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 36,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          horizontalMargin: 12,
          columnSpacing: 24,
          border: TableBorder.all(color: cs.outlineVariant),
          columns: const [
            DataColumn(label: Text('Партія')),
            DataColumn(label: Text('Дата')),
            DataColumn(label: Text('Продукція')),
            DataColumn(label: Text('ЦКТ')),
            DataColumn(label: Text('План'), numeric: true),
            DataColumn(label: Text('Варок'), numeric: true),
            DataColumn(label: Text('Статус')),
          ],
          rows: [
            for (final item in items)
              DataRow(
                onSelectChanged: (_) => onOpen(item),
                cells: [
                  DataCell(Text('#${item.batchNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
                  DataCell(Text(_date(item.createdAt))),
                  DataCell(SizedBox(width: 280, child: Text(item.productName))),
                  DataCell(SizedBox(width: 140, child: Text(item.cktName))),
                  DataCell(Text('${_num(item.plannedVolume)} л')),
                  DataCell(Text('${item.portionCount}')),
                  DataCell(Text(item.status.isEmpty ? '—' : item.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BrewPortionsTable extends StatelessWidget {
  const _BrewPortionsTable({required this.portions, required this.onOpen});
  final List<BrewPortion> portions;
  final ValueChanged<BrewPortion> onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 36,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 46,
          horizontalMargin: 12,
          columnSpacing: 24,
          border: TableBorder.all(color: cs.outlineVariant),
          columns: const [
            DataColumn(label: Text('N')),
            DataColumn(label: Text('Документ')),
            DataColumn(label: Text('План'), numeric: true),
            DataColumn(label: Text('Статус')),
          ],
          rows: [
            for (final portion in portions)
              DataRow(
                onSelectChanged: (_) => onOpen(portion),
                cells: [
                  DataCell(Text('${portion.portionNumber}')),
                  DataCell(SizedBox(
                    width: 300,
                    child: Text(portion.number.isEmpty
                        ? 'Варка ${portion.portionNumber}'
                        : portion.number),
                  )),
                  DataCell(Text('${_num(portion.plannedVolume)} л')),
                  DataCell(Text(portion.status.isEmpty ? '—' : portion.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/production'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(subtitle),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.retry});
  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorText(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторити'),
              ),
            ],
          ),
        ),
      );
}

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';
String _num(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
String _errorText(Object? error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
