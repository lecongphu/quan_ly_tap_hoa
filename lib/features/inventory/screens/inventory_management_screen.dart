import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'tabs/stock_list_tab.dart';
import 'tabs/purchase_orders_tab.dart';
import 'tabs/alerts_tab.dart';
import 'tabs/suppliers_tab.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    _InventoryTabItem(
      icon: Icons.inventory_2_rounded,
      label: 'Tồn kho',
      description: 'Theo dõi số lượng hiện có',
    ),
    _InventoryTabItem(
      icon: Icons.shopping_cart_rounded,
      label: 'Đơn nhập hàng',
      description: 'Quản lý phiếu nhập & NCC',
    ),
    _InventoryTabItem(
      icon: Icons.local_shipping_rounded,
      label: 'Nhà cung cấp',
      description: 'Danh bạ đối tác & thông tin liên hệ',
    ),
    _InventoryTabItem(
      icon: Icons.warning_amber_rounded,
      label: 'Cảnh báo',
      description: 'Sắp hết hàng & bất thường',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Kho')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;
            final isCompact = constraints.maxWidth < 1024;
            final horizontalPadding =
                constraints.maxWidth > 1400 ? 72.w : isMobile ? 16.w : 28.w;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMobile ? 16.h : 22.h,
                    horizontalPadding,
                    isMobile ? 12.h : 16.h,
                  ),
                  child: _InventoryHeader(
                    tabController: _tabController,
                    tabs: _tabs,
                    isCompact: isCompact,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _InventoryTabBar(
                    controller: _tabController,
                    tabs: _tabs,
                    scheme: scheme,
                    isCompact: isCompact,
                    isScrollable: isMobile,
                  ),
                ),
                SizedBox(height: isMobile ? 10.h : 14.h),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      StockListTab(),
                      PurchaseOrdersTab(),
                      SuppliersTab(),
                      AlertsTab(),
                    ],
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

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.tabController,
    required this.tabs,
    required this.isCompact,
  });

  final TabController tabController;
  final List<_InventoryTabItem> tabs;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final index = tabController.index.clamp(0, tabs.length - 1);
        final tab = tabs[index];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 18.w : 24.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.9),
                scheme.secondaryContainer.withValues(alpha: 0.8),
                scheme.tertiaryContainer.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
            spacing: 16.w,
            runSpacing: 16.h,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 760.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.label,
                      style: (isCompact
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      tab.description,
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: (isCompact
                              ? Theme.of(context).textTheme.bodyMedium
                              : Theme.of(context).textTheme.titleMedium)
                          ?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompact)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            Icon(tab.icon, color: scheme.primary, size: 24.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Không gian làm việc',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Kho hàng',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, color: scheme.primary, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Kho hàng',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryTabBar extends StatelessWidget {
  const _InventoryTabBar({
    required this.controller,
    required this.tabs,
    required this.scheme,
    required this.isCompact,
    required this.isScrollable,
  });

  final TabController controller;
  final List<_InventoryTabItem> tabs;
  final ColorScheme scheme;
  final bool isCompact;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 2.w : 4.w,
        horizontal: isCompact ? 4.w : 6.w,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isCompact ? 13.sp : 15.sp,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: isCompact ? 12.sp : 14.sp,
        ),
        labelPadding: isScrollable
            ? EdgeInsets.symmetric(horizontal: 12.w)
            : EdgeInsets.zero,
        tabs: tabs
            .map(
              (tab) => Tab(
                height: isCompact ? 48.h : 64.h,
                iconMargin: isCompact ? EdgeInsets.zero : EdgeInsets.only(bottom: 6.h),
                icon: Icon(tab.icon, size: isCompact ? 20.sp : 22.sp),
                text: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InventoryTabItem {
  const _InventoryTabItem({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;
}
