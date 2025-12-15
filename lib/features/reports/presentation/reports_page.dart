import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчёты')),
      body: Center(
        child: Text(
          'Здесь будут отчёты по запросу из 1С\n(динамика, анализ, выгрузка)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
