import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;
            final horizontalPadding = isMobile ? 16.w : 24.w;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isMobile ? 16.h : 24.h,
                horizontalPadding,
                24.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng hợp báo cáo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Theo dõi doanh thu, tồn kho và hiệu suất bán hàng theo ngày/tuần/tháng.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: isMobile ? 16.h : 24.h),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16.w : 20.w),
                      child: Row(
                        children: [
                          Container(
                            width: isMobile ? 48.w : 56.w,
                            height: isMobile ? 48.w : 56.w,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.analytics_rounded,
                              color: scheme.primary,
                              size: isMobile ? 24.sp : 28.sp,
                            ),
                          ),
                          SizedBox(width: isMobile ? 12.w : 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Báo cáo đang được cập nhật',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Sớm ra mắt bảng tổng hợp chi tiết và xuất dữ liệu.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
