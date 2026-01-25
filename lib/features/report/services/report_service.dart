import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../models/daily_report_model.dart';

/// Report service for daily report management
class ReportService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Get daily reports in date range (optional)
  Future<List<DailyReport>> getDailyReports({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      var query = _supabase.from(AppConstants.tableDailyReports).select();

      if (dateFrom != null) {
        query = query.gte('report_date', _formatDate(dateFrom));
      }
      if (dateTo != null) {
        query = query.lte('report_date', _formatDate(dateTo));
      }

      final response = await query.order('report_date', ascending: false);
      return (response as List)
          .map((item) => DailyReport.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Lỗi khi tải báo cáo: ${e.toString()}');
    }
  }

  /// Get daily report by date
  Future<DailyReport?> getDailyReportByDate(DateTime date) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableDailyReports)
          .select()
          .eq('report_date', _formatDate(date))
          .maybeSingle();

      if (response == null) return null;
      return DailyReport.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi tải báo cáo ngày: ${e.toString()}');
    }
  }

  /// Create or update a daily report (upsert by report_date)
  Future<DailyReport> upsertDailyReport({
    required DateTime reportDate,
    double? totalSales,
    double? totalCash,
    double? totalTransfer,
    double? totalDebt,
    double? totalCost,
    double? grossProfit,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final payload = <String, dynamic>{
        'report_date': _formatDate(reportDate),
        'total_sales': totalSales,
        'total_cash': totalCash,
        'total_transfer': totalTransfer,
        'total_debt': totalDebt,
        'total_cost': totalCost,
        'gross_profit': grossProfit,
      };

      if (userId != null) {
        payload['created_by'] = userId;
      }

      final response = await _supabase
          .from(AppConstants.tableDailyReports)
          .upsert(payload, onConflict: 'report_date')
          .select()
          .single();

      return DailyReport.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi khi lưu báo cáo: ${e.toString()}');
    }
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}
