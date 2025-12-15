class DashboardCounts {
  final int approvals;
  final int tasks;
  final int invoicesToday;
  final double expensesMonth;

  const DashboardCounts({
    required this.approvals,
    required this.tasks,
    required this.invoicesToday,
    required this.expensesMonth,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> j) => DashboardCounts(
    approvals: j['approvals'] as int,
    tasks: j['tasks'] as int,
    invoicesToday: j['invoicesToday'] as int,
    expensesMonth: (j['expensesMonth'] as num).toDouble(),
  );
}
