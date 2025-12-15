class Invoice {
  final String number;
  final DateTime date;
  final String supplier;
  final double amount;
  final String purpose;

  Invoice({
    required this.number,
    required this.date,
    required this.supplier,
    required this.amount,
    required this.purpose,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    number: j['Номер'] as String,
    date: DateTime.parse(j['Дата'] as String),
    supplier: j['Поставщик'] as String,
    amount: (j['Сумма'] as num).toDouble(),
    purpose: j['Назначение'] as String,
  );

  Map<String, dynamic> toJson() => {
    'Номер': number,
    'Дата': date.toIso8601String().split('T').first,
    'Поставщик': supplier,
    'Сумма': amount,
    'Назначение': purpose,
  };
}
