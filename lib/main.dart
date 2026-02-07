import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/accessibility_binding.dart';
import 'core/services/local_db_service.dart';
import 'core/services/supabase_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/pos/screens/pos_screen.dart';
import 'features/inventory/screens/inventory_management_screen.dart';
import 'features/product/screens/product_management_screen.dart';
import 'features/customers/screens/customer_management_screen.dart';
import 'features/debt/screens/debt_management_screen.dart';
import 'features/report/screens/report_screen.dart';

void main() async {
  AccessibilityFixBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SupabaseService.initialize();
  // Initialize local database
  await LocalDbService.instance.database;

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final designSize = width >= 1200
            ? const Size(1440, 900)
            : width >= 768
            ? const Size(834, 1194)
            : const Size(390, 844);

        return ScreenUtilInit(
          designSize: designSize,
          useInheritedMediaQuery: true,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            final lightTextTheme = GoogleFonts.spaceGroteskTextTheme(
              ThemeData.light().textTheme,
            );
            final darkTextTheme = GoogleFonts.spaceGroteskTextTheme(
              ThemeData.dark().textTheme,
            );
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
                textTheme: lightTextTheme,
                appBarTheme: AppBarTheme(
                  backgroundColor: baseScheme.surface,
                  elevation: 0,
                  centerTitle: false,
                  titleTextStyle: lightTextTheme.titleLarge?.copyWith(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: baseScheme.onSurface,
                    letterSpacing: -0.3,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 18.h,
                    ),
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
                textTheme: darkTextTheme,
              ),
              themeMode: ThemeMode.light,
              home: const AuthWrapper(),
            );
          },
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
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 760;
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
        title: 'Khách hàng',
        subtitle: 'Quản lý thông tin khách hàng',
        icon: Icons.groups_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerManagementScreen(),
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
          MaterialPageRoute(builder: (context) => const DebtManagementScreen()),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tạp hóa'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: isMobile
                ? IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: () async =>
                        ref.read(authProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout_rounded),
                  )
                : TextButton.icon(
                    onPressed: () async =>
                        ref.read(authProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Đăng xuất'),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.surface,
                      scheme.surfaceContainerLow,
                      scheme.surfaceContainerLowest,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90.h,
              right: -120.w,
              child: _BackgroundBlob(
                size: isMobile ? 220.w : 280.w,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              bottom: -110.h,
              left: -120.w,
              child: _BackgroundBlob(
                size: isMobile ? 210.w : 260.w,
                color: scheme.secondary.withValues(alpha: 0.12),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxContentWidth = 1280.0;
                final contentWidth = constraints.maxWidth > maxContentWidth
                    ? maxContentWidth
                    : constraints.maxWidth;
                final isCompact = contentWidth < 760;
                final horizontalPadding = isCompact ? 20.w : 28.w;
                final columnCount = contentWidth >= 1200
                    ? 4
                    : contentWidth >= 920
                    ? 3
                    : contentWidth >= 680
                    ? 2
                    : 1;
                final cardAspectRatio = columnCount >= 4
                    ? 1.25
                    : columnCount == 3
                    ? 1.15
                    : 1.05;

                final quickActionWidgets = isCompact
                    ? Column(
                        children: [
                          for (
                            var index = 0;
                            index < quickActions.length;
                            index++
                          ) ...[
                            _QuickActionTile(item: quickActions[index]),
                            if (index != quickActions.length - 1)
                              SizedBox(height: 14.h),
                          ],
                        ],
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: quickActions.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          crossAxisSpacing: 18.w,
                          mainAxisSpacing: 18.h,
                          childAspectRatio: cardAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          return _QuickActionCard(item: quickActions[index]);
                        },
                      );

                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          isCompact ? 20.h : 28.h,
                          horizontalPadding,
                          36.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Truy cập nhanh',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            SizedBox(height: isCompact ? 8.h : 12.h),
                            Text(
                              'Các tính năng chính được sắp xếp theo luồng vận hành cửa hàng.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            SizedBox(height: isCompact ? 16.h : 20.h),
                            quickActionWidgets,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
    final radius = BorderRadius.circular(20);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, scheme.surfaceContainerLowest],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.18),
            ),
            borderRadius: radius,
          ),
          child: Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(item.icon, color: item.color, size: 30.sp),
                ),
                SizedBox(height: 18.h),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8.h),
                Flexible(
                  child: Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
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
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: item.color,
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.item});

  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, scheme.surfaceContainerLowest],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.color.withValues(alpha: 0.18),
                        item.color.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.color, size: 26.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: item.color,
                    size: 18.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
