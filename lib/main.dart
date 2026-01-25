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
            scaffoldBackgroundColor: const Color(0xFFF4F6FA),
            useMaterial3: true,
            fontFamily: 'Roboto',
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: baseScheme.onSurface,
              ),
            ),
            dividerTheme: DividerThemeData(
              color: const Color(0xFFE2E8F0),
              thickness: 1,
              space: 1,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            navigationRailTheme: NavigationRailThemeData(
              backgroundColor: Colors.white,
              indicatorColor: baseScheme.primary.withOpacity(0.12),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              selectedIconTheme: IconThemeData(color: baseScheme.primary),
              selectedLabelTextStyle: TextStyle(
                color: baseScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedIconTheme: IconThemeData(
                color: baseScheme.onSurfaceVariant,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: baseScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
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

    final statItems = [
      _StatItem(
        label: 'Doanh thu hôm nay',
        value: '12,4 triệu',
        change: '+8.2%',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF16A34A),
      ),
      _StatItem(
        label: 'Đơn hàng',
        value: '86 đơn',
        change: '+12 đơn',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF2563EB),
      ),
      _StatItem(
        label: 'Hàng sắp hết',
        value: '14 sản phẩm',
        change: 'Cần nhập thêm',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFF97316),
      ),
      _StatItem(
        label: 'Công nợ',
        value: '4,8 triệu',
        change: '3 khoản đến hạn',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF7C3AED),
      ),
    ];

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
            final showRail = constraints.maxWidth >= 1200;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showRail)
                  _SideNavigation(
                    onNavigate: (index) {
                      switch (index) {
                        case 0:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const POSScreen(),
                            ),
                          );
                          break;
                        case 1:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProductManagementScreen(),
                            ),
                          );
                          break;
                        case 2:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const InventoryManagementScreen(),
                            ),
                          );
                          break;
                        case 3:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DebtManagementScreen(),
                            ),
                          );
                          break;
                      }
                    },
                  ),
                Expanded(
                  child: SingleChildScrollView(
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
                        SizedBox(height: 24.h),
                        Text(
                          'Tổng quan hôm nay',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 16.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: statItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columnCount,
                            crossAxisSpacing: 18.w,
                            mainAxisSpacing: 18.h,
                            childAspectRatio: columnCount == 1 ? 1.8 : 1.35,
                          ),
                          itemBuilder: (context, index) {
                            return _StatCard(item: statItems[index]);
                          },
                        ),
                        SizedBox(height: 28.h),
                        Text(
                          'Truy cập nhanh',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Các tính năng chính được sắp xếp theo luồng vận hành cửa hàng.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        SizedBox(height: 20.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: quickActions.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                        LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final secondaryColumns =
                                innerConstraints.maxWidth >= 1100 ? 2 : 1;
                            return GridView.count(
                              crossAxisCount: secondaryColumns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 18.w,
                              mainAxisSpacing: 18.h,
                              childAspectRatio: secondaryColumns == 1 ? 2.2 : 2.6,
                              children: const [
                                _SectionCard(
                                  title: 'Công việc cần chú ý',
                                  subtitle: 'Nhắc việc ưu tiên trong ngày',
                                  items: [
                                    _SectionItem(
                                      title: 'Nhập thêm 14 mặt hàng sắp hết',
                                      description:
                                          'Sữa, mì gói, nước giải khát đang giảm nhanh',
                                    ),
                                    _SectionItem(
                                      title: 'Đối soát công nợ cuối ngày',
                                      description:
                                          '3 khoản sắp đến hạn cần liên hệ',
                                    ),
                                    _SectionItem(
                                      title: 'Tạo chương trình khuyến mãi cuối tuần',
                                      description:
                                          'Ưu tiên nhóm hàng tồn kho cao',
                                    ),
                                  ],
                                ),
                                _SectionCard(
                                  title: 'Hoạt động gần đây',
                                  subtitle: 'Những thay đổi mới nhất',
                                  items: [
                                    _SectionItem(
                                      title: 'POS #A1024 đã thanh toán',
                                      description: 'Giá trị: 1.240.000đ',
                                    ),
                                    _SectionItem(
                                      title: 'Nhập kho từ NCC Minh Phát',
                                      description: '36 sản phẩm • 9.600.000đ',
                                    ),
                                    _SectionItem(
                                      title: 'Cập nhật giá 12 mặt hàng',
                                      description:
                                          'Áp dụng từ 08:00 sáng mai',
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $greetingName 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Tổng quan nhanh về vận hành cửa hàng và các tác vụ ưu tiên trong ngày.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                SizedBox(height: 20.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const POSScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: const Text('Mở POS ngay'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const InventoryManagementScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Tạo phiếu nhập'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 20.w),
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
        color: scheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240.w,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.white,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ERP Mini',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Bảng điều khiển',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Expanded(
            child: NavigationRail(
              selectedIndex: 0,
              onDestinationSelected: onNavigate,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale),
                  label: Text('Bán hàng'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category_rounded),
                  label: Text('Sản phẩm'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_rounded),
                  label: Text('Kho hàng'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: Text('Công nợ'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Hỗ trợ nhanh'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(item.icon, color: item.color, size: 24.sp),
                ),
                const Spacer(),
                Text(
                  item.change,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: 8.h),
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_SectionItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(22.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: 16.h),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10.w,
                      height: 10.w,
                      margin: EdgeInsets.only(top: 6.h),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            item.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
}

class _SectionItem {
  const _SectionItem({required this.title, required this.description});

  final String title;
  final String description;
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
