import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/services/supabase_service.dart';
import 'core/services/local_db_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/pos/screens/pos_screen.dart';
import 'features/inventory/screens/inventory_management_screen.dart';
import 'features/product/screens/product_management_screen.dart';
import 'features/debt/screens/debt_management_screen.dart';
import 'features/report/screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize local database
  await LocalDbService.instance.database;

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(1920, 1080), // Desktop design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final baseScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        );
        return MaterialApp(
          title: 'Quản lý Tạp hóa',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: baseScheme,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            useMaterial3: true,
            fontFamily: 'Roboto',
            appBarTheme: AppBarTheme(
              backgroundColor: baseScheme.surface,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: baseScheme.onSurface,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          themeMode: ThemeMode.light,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

/// Auth wrapper to handle navigation based on auth state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isAuthenticated && authState.user != null) {
      return const _HomeScreen();
    }

    return const LoginScreen();
  }
}

/// Home screen with navigation
class _HomeScreen extends ConsumerWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.fullName ?? '';

    final quickActions = [
      _QuickActionItem(
        title: 'Bán hàng',
        subtitle: 'Tạo đơn nhanh với POS',
        icon: Icons.point_of_sale,
        color: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const POSScreen()),
        ),
      ),
      _QuickActionItem(
        title: 'Sản phẩm',
        subtitle: 'Quản lý danh mục hàng hóa',
        icon: Icons.category_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProductManagementScreen(),
          ),
        ),
      ),
      _QuickActionItem(
        title: 'Kho hàng',
        subtitle: 'Theo dõi tồn kho & nhập hàng',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InventoryManagementScreen(),
          ),
        ),
      ),
      _QuickActionItem(
        title: 'Công nợ',
        subtitle: 'Quản lý thu chi & đối soát',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFF97316),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DebtManagementScreen(),
          ),
        ),
      ),
      _QuickActionItem(
        title: 'Báo cáo',
        subtitle: 'Xem tổng hợp doanh thu & tồn kho',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF9333EA),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReportScreen()),
        ),
      ),
    ];
    final kpiItems = [
      _KpiItem(
        title: 'Doanh thu hôm nay',
        value: '0 ₫',
        change: '+0%',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF2563EB),
      ),
      _KpiItem(
        title: 'Đơn bán',
        value: '0',
        change: '+0 đơn',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0EA5E9),
      ),
      _KpiItem(
        title: 'Tồn kho',
        value: '0 mặt hàng',
        change: 'Ổn định',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF10B981),
      ),
      _KpiItem(
        title: 'Công nợ',
        value: '0 ₫',
        change: 'Không biến động',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFF97316),
      ),
    ];
    final activities = [
      _ActivityItem(
        title: 'Kiểm tra tồn kho sáng',
        subtitle: 'Đối soát kho & hạn sử dụng',
        time: '08:45',
        icon: Icons.fact_check_rounded,
      ),
      _ActivityItem(
        title: 'Cập nhật giá bán',
        subtitle: 'Đồng bộ bảng giá nhóm hàng',
        time: '10:15',
        icon: Icons.price_change_rounded,
      ),
      _ActivityItem(
        title: 'Theo dõi công nợ',
        subtitle: 'Nhắc thu khoản đến hạn',
        time: '14:00',
        icon: Icons.notifications_active_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tạp hóa'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton.icon(
              onPressed: () async => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth > 1400 ? 80.w : 32.w;
            final columnCount = constraints.maxWidth >= 1500
                ? 4
                : constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 760
                        ? 2
                        : 1;
            final kpiColumnCount = constraints.maxWidth >= 1500
                ? 4
                : constraints.maxWidth >= 1100
                    ? 2
                    : 1;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                28.h,
                horizontalPadding,
                36.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(userName: userName),
                  SizedBox(height: 28.h),
                  Text(
                    'Tổng quan hôm nay',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 28.h),
                  Text(
                    'Lộ trình nghiệp vụ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Các phân hệ chính được sắp xếp theo quy trình ERP.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Truy cập nhanh',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Các tính năng chính được sắp xếp theo luồng vận hành cửa hàng.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 20.h),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quickActions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      crossAxisSpacing: 18.w,
                      mainAxisSpacing: 18.h,
                      childAspectRatio: columnCount == 1 ? 1.55 : 1.25,
                    ),
                    itemBuilder: (context, index) {
                      return _QuickActionCard(item: quickActions[index]);
                    },
                  ),
                  SizedBox(height: 28.h),
                  Text(
                    'Hoạt động ưu tiên',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Những nhiệm vụ nên xử lý trong ca làm việc.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 20.h),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        children: List.generate(activities.length, (index) {
                          final activity = activities[index];
                          return Column(
                            children: [
                              _ActivityRow(item: activity),
                              if (index != activities.length - 1)
                                Divider(
                                  height: 24.h,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                            ],
                          );
                        }),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greetingName = userName.isEmpty ? 'bạn' : userName;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(28.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Wrap(
        spacing: 24.w,
        runSpacing: 24.h,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $greetingName 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Theo dõi hoạt động cửa hàng và bắt đầu nhanh các tác vụ quan trọng chỉ với một chạm.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        height: 1.4,
                      ),
                ),
                SizedBox(height: 20.h),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const POSScreen()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: scheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 18.h),
                    textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Mở POS ngay'),
                ),
              ],
            ),
          ),
          _HeaderHighlights(scheme: scheme),
        ],
      ),
    );
  }
}

class _HeaderHighlights extends StatelessWidget {
  const _HeaderHighlights({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final items = [
      _HighlightItem(
        label: 'Bán hàng',
        description: 'Xử lý đơn trong vài giây',
        icon: Icons.bolt_rounded,
      ),
      _HighlightItem(
        label: 'Kho hàng',
        description: 'Tồn kho luôn cập nhật',
        icon: Icons.inventory_rounded,
      ),
      _HighlightItem(
        label: 'Công nợ',
        description: 'Theo dõi thu chi rõ ràng',
        icon: Icons.receipt_long_rounded,
      ),
    ];

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children:
          items.map((item) => _HighlightChip(item: item, scheme: scheme)).toList(),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.item, required this.scheme});

  final _HighlightItem item;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: scheme.primary),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});

  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: EdgeInsets.all(22.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: item.color, size: 30.sp),
              ),
              SizedBox(height: 18.h),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 8.h),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Mở tính năng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.color,
                        ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.arrow_forward_rounded, color: item.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _KpiItem {
  const _KpiItem({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22.sp),
                ),
                const Spacer(),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.change,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            SizedBox(height: 6.h),
            Text(
              item.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: scheme.primary),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Text(
          item.time,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _HighlightItem {
  const _HighlightItem({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}
