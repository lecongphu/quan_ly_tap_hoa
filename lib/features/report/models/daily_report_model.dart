/// Daily report model
class DailyReport {
  final String id;
  final DateTime reportDate;
  final double? totalSales;
  final double? totalCash;
  final double? totalTransfer;
  final double? totalDebt;
  final double? totalCost;
  final double? grossProfit;
  final String? createdBy;
  final DateTime createdAt;

  const DailyReport({
    required this.id,
    required this.reportDate,
    this.totalSales,
    this.totalCash,
    this.totalTransfer,
    this.totalDebt,
    this.totalCost,
    this.grossProfit,
    this.createdBy,
    required this.createdAt,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      id: json['id'] as String,
      reportDate: DateTime.parse(json['report_date'] as String),
      totalSales: (json['total_sales'] as num?)?.toDouble(),
      totalCash: (json['total_cash'] as num?)?.toDouble(),
      totalTransfer: (json['total_transfer'] as num?)?.toDouble(),
      totalDebt: (json['total_debt'] as num?)?.toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      grossProfit: (json['gross_profit'] as num?)?.toDouble(),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_date': reportDate.toIso8601String(),
      'total_sales': totalSales,
      'total_cash': totalCash,
      'total_transfer': totalTransfer,
      'total_debt': totalDebt,
      'total_cost': totalCost,
      'gross_profit': grossProfit,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DailyReport copyWith({
    String? id,
    DateTime? reportDate,
    double? totalSales,
    double? totalCash,
    double? totalTransfer,
    double? totalDebt,
    double? totalCost,
    double? grossProfit,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return DailyReport(
      id: id ?? this.id,
      reportDate: reportDate ?? this.reportDate,
      totalSales: totalSales ?? this.totalSales,
      totalCash: totalCash ?? this.totalCash,
      totalTransfer: totalTransfer ?? this.totalTransfer,
      totalDebt: totalDebt ?? this.totalDebt,
      totalCost: totalCost ?? this.totalCost,
      grossProfit: grossProfit ?? this.grossProfit,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
