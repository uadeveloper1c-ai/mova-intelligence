import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../bottling_models.dart';
import '../production_service.dart';

typedef _PackagingOverview = ({
  List<ProductionRequest> requests,
  List<ProductionReference> stocks,
});

class BottlingPage extends StatefulWidget {
  const BottlingPage({super.key});

  @override
  State<BottlingPage> createState() => _BottlingPageState();
}

class _BottlingPageState extends State<BottlingPage> {
  late Future<BottlingData> _future;
  late Future<_PackagingOverview> _packagingFuture;
  BottlingPassport? _selected;
  final _volumeController = TextEditingController();
  final _commentController = TextEditingController();
  final List<_BottlingLineEditor> _lines = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final service = context.read<ProductionService>();
    _future = service.getBottlingData();
    _packagingFuture = service.getPackagingOverview();
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _commentController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final service = context.read<ProductionService>();
    final future = service.getBottlingData();
    final packagingFuture = service.getPackagingOverview();
    setState(() {
      _future = future;
      _packagingFuture = packagingFuture;
    });
    await Future.wait([future, packagingFuture]);
  }

  void _resetLines(BottlingPassport? passport) {
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
    if (passport == null) return;
    for (final specification in passport.specifications) {
      for (final purpose in const ['Продажа', 'Брак', 'Лаборатория']) {
        _lines.add(_BottlingLineEditor(
          purpose: purpose,
          specificationUid: specification.uid,
        ));
      }
    }
  }

  void _selectPassport(BottlingPassport passport) {
    setState(() {
      _selected = passport;
      _volumeController.text = _number(passport.remainingVolume);
      _resetLines(passport);
    });
  }

  Future<void> _submit() async {
    final passport = _selected;
    if (passport == null) return;

    final inputVolume = _parseNumber(_volumeController.text);
    if (inputVolume <= 0 || inputVolume > passport.remainingVolume + .001) {
      _message(
          'Вкаж\u0456ть об\u2019єм в\u0456д 0 до ${_number(passport.remainingVolume)} л');
      return;
    }

    final drafts = <BottlingLineDraft>[];
    var outputVolume = 0.0;
    for (final line in _lines) {
      final quantity = _parseNumber(line.quantityController.text);
      if (quantity <= 0) continue;
      final specification = line.specification(passport);
      if (specification == null) {
        _message('Не вдалося визначити специфікацію продукції');
        return;
      }
      outputVolume += quantity * specification.volumePerUnit;
      drafts.add(BottlingLineDraft(
        purpose: line.purpose,
        specificationUid: specification.uid,
        outputUid: specification.outputUid,
        quantity: quantity,
      ));
    }

    if (drafts.isEmpty) {
      _message('Вкажіть хоча б одну кількість продукції розливу');
      return;
    }

    if (outputVolume > inputVolume + .001) {
      _message(
        'Об\u2019єм продукц\u0456ї ${_number(outputVolume)} л б\u0456льший за списаний об\u2019єм '
        '${_number(inputVolume)} л',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = await context.read<ProductionService>().createBottling(
            passportUid: passport.id,
            inputVolume: inputVolume,
            items: drafts,
            operationId:
                '${DateTime.now().microsecondsSinceEpoch}-${passport.id}',
            comment: _commentController.text.trim(),
          );
      if (!mounted) return;
      BottlingPassport? updated;
      for (final item in data.passports) {
        if (item.id == passport.id) updated = item;
      }
      setState(() {
        _future = Future.value(data);
        _selected = updated;
        _volumeController.clear();
        _commentController.clear();
        _resetLines(updated);
      });
      _message('Розлив записано. Документ виробництва створено.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Розлив', style: theme.textTheme.headlineSmall),
                      Text(
                        'Тара та випуск готової продукц\u0456ї',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Оновити',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Тара'),
                Tab(icon: Icon(Icons.local_drink_outlined), text: 'Розлив'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.sizeOf(context).height - 190,
              child: TabBarView(
                children: [
                  _PackagingTab(
                    future: _packagingFuture,
                    onRetry: _reload,
                    onCreate: () async {
                      await context.push('/production/new?type=Bottling');
                      if (mounted) await _reload();
                    },
                    onOpen: (request) => context.push(
                      '/production/requests/${request.id}',
                    ),
                  ),
                  FutureBuilder<BottlingData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _LoadError(
                          error: snapshot.error.toString(),
                          onRetry: _reload,
                        );
                      }
                      return _BottlingTab(
                        data:
                            snapshot.data ?? const BottlingData(passports: []),
                        selected: _selected,
                        lines: _lines,
                        volumeController: _volumeController,
                        commentController: _commentController,
                        submitting: _submitting,
                        onSelect: _selectPassport,
                        onChanged: () => setState(() {}),
                        onSubmit: _submit,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagingTab extends StatelessWidget {
  const _PackagingTab({
    required this.future,
    required this.onRetry,
    required this.onCreate,
    required this.onOpen,
  });
  final Future<_PackagingOverview> future;
  final Future<void> Function() onRetry;
  final Future<void> Function() onCreate;
  final ValueChanged<ProductionRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PackagingOverview>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error.toString(), onRetry: onRetry);
        }
        final data = snapshot.data ??
            (requests: <ProductionRequest>[], stocks: <ProductionReference>[]);
        return LayoutBuilder(builder: (context, box) {
          final left = _PackagingRequests(
            items: data.requests,
            onCreate: onCreate,
            onOpen: onOpen,
          );
          final right = _PackagingStocks(items: data.stocks, onRetry: onRetry);
          if (box.maxWidth >= 980) {
            return Row(children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: right),
            ]);
          }
          return Column(children: [
            Expanded(flex: 5, child: left),
            const SizedBox(height: 12),
            Expanded(flex: 4, child: right),
          ]);
        });
      },
    );
  }
}

class _PackagingRequests extends StatelessWidget {
  const _PackagingRequests({
    required this.items,
    required this.onCreate,
    required this.onOpen,
  });
  final List<ProductionRequest> items;
  final Future<void> Function() onCreate;
  final ValueChanged<ProductionRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Заявки на тару', style: theme.textTheme.titleMedium),
            ),
            Badge(label: Text('${items.length}')),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Створити'),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          const Expanded(child: Center(child: Text('Заявок поки немає')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = items[index];
                final lines = request.lines
                    .take(2)
                    .map((line) =>
                        '${line.itemName} — ${_number(line.quantity)} ${line.unitName}')
                    .join(' · ');
                return InkWell(
                  onTap: () => onOpen(request),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 19),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lines.isNotEmpty ? lines : request.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 132,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _shortDate(request.createdAt),
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  request.wmsStatus.isNotEmpty
                                      ? request.wmsStatus
                                      : request.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
                        ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _PackagingStocks extends StatelessWidget {
  const _PackagingStocks({required this.items, required this.onRetry});
  final List<ProductionReference> items;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...items]..sort((a, b) {
        final stock = (b.stock ?? 0).compareTo(a.stock ?? 0);
        return stock != 0 ? stock : a.name.compareTo(b.name);
      });
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(children: [
            const Icon(Icons.warehouse_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Залишки тари на виробництві',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Оновити',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ]),
        ),
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: const Row(children: [
            Expanded(child: Text('Тара')),
            SizedBox(
              width: 110,
              child: Text('Залишок', textAlign: TextAlign.right),
            ),
          ]),
        ),
        if (sorted.isEmpty)
          const Expanded(child: Center(child: Text('Залишків не знайдено')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = sorted[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: Text(
                        '${_number(item.stock ?? 0)} ${item.stockUnit}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _BottlingTab extends StatelessWidget {
  const _BottlingTab({
    required this.data,
    required this.selected,
    required this.lines,
    required this.volumeController,
    required this.commentController,
    required this.submitting,
    required this.onSelect,
    required this.onChanged,
    required this.onSubmit,
  });

  final BottlingData data;
  final BottlingPassport? selected;
  final List<_BottlingLineEditor> lines;
  final TextEditingController volumeController;
  final TextEditingController commentController;
  final bool submitting;
  final ValueChanged<BottlingPassport> onSelect;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (data.passports.isEmpty) {
      return const Center(
        child: Text('Немає паспорт\u0456в \u0456з залишком для розливу'),
      );
    }

    final passport = selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        final list = _PassportList(
          passports: data.passports,
          selected: passport,
          onSelect: onSelect,
        );
        final editor = passport == null
            ? const Center(child: Text('Обер\u0456ть паспорт варки'))
            : _BottlingEditor(
                passport: passport,
                lines: lines,
                volumeController: volumeController,
                commentController: commentController,
                submitting: submitting,
                onChanged: onChanged,
                onSubmit: onSubmit,
              );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 390, child: list),
              const SizedBox(width: 12),
              Expanded(child: editor),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 230, child: list),
            const SizedBox(height: 12),
            Expanded(child: editor),
          ],
        );
      },
    );
  }
}

class _PassportList extends StatelessWidget {
  const _PassportList({
    required this.passports,
    required this.selected,
    required this.onSelect,
  });

  final List<BottlingPassport> passports;
  final BottlingPassport? selected;
  final ValueChanged<BottlingPassport> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const ListTile(
            dense: true,
            title: Text(
              'Паспорти у робот\u0456',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: passports.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = passports[index];
                return ListTile(
                  selected: selected?.id == item.id,
                  onTap: () => onSelect(item),
                  title: Text(
                    '${item.batchNumber}  ${item.productName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.cktName} · розлито ${_number(item.bottledVolume)} '
                    'з ${_number(item.initialVolume)} л',
                  ),
                  trailing: Text(
                    '${_number(item.remainingVolume)} л',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottlingEditor extends StatelessWidget {
  const _BottlingEditor({
    required this.passport,
    required this.lines,
    required this.volumeController,
    required this.commentController,
    required this.submitting,
    required this.onChanged,
    required this.onSubmit,
  });

  final BottlingPassport passport;
  final List<_BottlingLineEditor> lines;
  final TextEditingController volumeController;
  final TextEditingController commentController;
  final bool submitting;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  _BottlingLineEditor _line(
    BottlingSpecification specification,
    String purpose,
  ) =>
      lines.firstWhere(
        (line) =>
            line.specificationUid == specification.uid &&
            line.purpose == purpose,
      );

  @override
  Widget build(BuildContext context) {
    final outputVolume = lines.fold<double>(0, (sum, line) {
      final spec = line.specification(passport);
      return sum +
          _parseNumber(line.quantityController.text) *
              (spec?.volumePerUnit ?? 0);
    });

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Metric(label: 'Партія', value: passport.batchNumber),
              _Metric(label: 'Поточний продукт', value: passport.productName),
              _Metric(label: 'ЦКТ', value: passport.cktName),
              _Metric(
                label: 'Залишок',
                value: '${_number(passport.remainingVolume)} л',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 260,
            child: TextField(
              controller: volumeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Списати з ЦКТ, л',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (passport.specifications.isEmpty)
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Для поточного продукту не знайдено чинних ресурсних '
                  'специфікацій розливу.',
                ),
              ),
            )
          else
            _BottlingMatrix(
              passport: passport,
              lineFor: _line,
              onChanged: onChanged,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Вихід за таблицею: ${_number(outputVolume)} л',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Коментар',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: submitting || passport.specifications.isEmpty
                  ? null
                  : onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.factory_outlined),
              label: const Text('Створити виробництво'),
            ),
          ),
          if (passport.operations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Історія розливів',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            ...passport.operations.map((operation) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${operation.documentNumber} · '
                    '${_number(operation.inputVolume)} л',
                  ),
                  subtitle: Text(
                    operation.items
                        .map((item) =>
                            '${item.itemName}: ${_number(item.quantity)} '
                            '${item.unitName} (${item.purpose})')
                        .join(' · '),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _BottlingMatrix extends StatelessWidget {
  const _BottlingMatrix({
    required this.passport,
    required this.lineFor,
    required this.onChanged,
  });

  final BottlingPassport passport;
  final _BottlingLineEditor Function(
    BottlingSpecification specification,
    String purpose,
  ) lineFor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 900,
          child: Column(
            children: [
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                height: 42,
                child: const Row(
                  children: [
                    _MatrixHeader('N', 42, center: true),
                    _MatrixHeader('Продукція / специфікація', 330),
                    _MatrixHeader('Од.', 90, center: true),
                    _MatrixHeader('Продаж', 140, center: true),
                    _MatrixHeader('Брак', 140, center: true),
                    _MatrixHeader('Лабораторія', 158, center: true),
                  ],
                ),
              ),
              ...passport.specifications.asMap().entries.map((entry) {
                final specification = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 54),
                  child: Row(
                    children: [
                      _MatrixText('${entry.key + 1}', 42, center: true),
                      _MatrixProduct(specification: specification),
                      _MatrixText(specification.unitName, 90, center: true),
                      _MatrixQuantity(
                        width: 140,
                        line: lineFor(specification, 'Продажа'),
                        onChanged: onChanged,
                      ),
                      _MatrixQuantity(
                        width: 140,
                        line: lineFor(specification, 'Брак'),
                        onChanged: onChanged,
                      ),
                      _MatrixQuantity(
                        width: 158,
                        line: lineFor(specification, 'Лаборатория'),
                        onChanged: onChanged,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader(this.text, this.width, {this.center = false});

  final String text;
  final double width;
  final bool center;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: center ? Alignment.center : Alignment.centerLeft,
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _MatrixText extends StatelessWidget {
  const _MatrixText(this.text, this.width, {this.center = false});

  final String text;
  final double width;
  final bool center;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: center ? Alignment.center : Alignment.centerLeft,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}

class _MatrixProduct extends StatelessWidget {
  const _MatrixProduct({required this.specification});

  final BottlingSpecification specification;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 330,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                specification.outputName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                specification.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _MatrixQuantity extends StatelessWidget {
  const _MatrixQuantity({
    required this.width,
    required this.line,
    required this.onChanged,
  });

  final double width;
  final _BottlingLineEditor line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: TextField(
            controller: line.quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: '0',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            ),
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторити'),
          ),
        ],
      ),
    );
  }
}

class _BottlingLineEditor {
  _BottlingLineEditor({
    required this.purpose,
    required this.specificationUid,
  });

  final String purpose;
  final String specificationUid;
  final quantityController = TextEditingController();

  BottlingSpecification? specification(BottlingPassport passport) {
    for (final item in passport.specifications) {
      if (item.uid == specificationUid) return item;
    }
    return null;
  }

  void dispose() => quantityController.dispose();
}

double _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _shortDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

String _number(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'[.,]$'),
        '',
      );
}
