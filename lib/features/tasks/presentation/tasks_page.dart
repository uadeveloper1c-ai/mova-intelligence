import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Задачи')),
      body: Center(
        child: Text(
          'Здесь будут задачи, поручения, статусы выполнения',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
