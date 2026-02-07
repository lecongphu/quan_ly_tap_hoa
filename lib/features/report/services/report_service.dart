import '../../../core/services/supabase_service.dart';
import '../models/daily_report_model.dart';

/// Report service for daily report management
class ReportService {
  /// Get daily reports in date range (optional)
  Future<List<DailyReport>> getDailyReports({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final data = await supabase
          .from('daily_reports')
          .select('*')
          .order('report_date', ascending: false);

      var reports = (data as List<dynamic>)
          .map((item) => DailyReport.fromJson(item as Map<String, dynamic>))
          .toList();

      if (dateFrom != null) {
        reports = reports.where((r) => r.reportDate.isAfter(dateFrom)).toList();
      }
      if (dateTo != null) {
        final end = dateTo.add(const Duration(days: 1));
        reports = reports.where((r) => r.reportDate.isBefore(end)).toList();
      }
      return reports;
    } catch (e) {
      throw Exception('Lỗi khi tải báo cáo: ${e.toString()}');
    }
  }

  /// Get daily report by date
  Future<DailyReport?> getDailyReportByDate(DateTime date) async {
    final reports = await getDailyReports();
    final target = DateTime(date.year, date.month, date.day);
    for (final report in reports) {
      if (report.reportDate == target) return report;
    }
    return null;
  }
}
