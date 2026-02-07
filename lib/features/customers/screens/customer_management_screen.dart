import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../debt/models/customer_model.dart';
import '../../debt/providers/debt_provider.dart';

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  _CustomerStatusFilter _statusFilter = _CustomerStatusFilter.all;
  bool _isLoading = false;
  String? _error;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(debtServiceProvider);
      final data = await service.getCustomers(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _customers = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Customer> get _filteredCustomers {
    final query = _searchController.text.toLowerCase().trim();
    return _customers.where((customer) {
      final matchesQuery =
          query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          (customer.phone?.contains(query) ?? false);
      final matchesStatus = switch (_statusFilter) {
        _CustomerStatusFilter.all => true,
        _CustomerStatusFilter.active => customer.isActive == true,
        _CustomerStatusFilter.inactive => customer.isActive == false,
      };
      return matchesQuery && matchesStatus;
    }).toList();
  }

  int get _activeCount =>
      _customers.where((customer) => customer.isActive).length;

  int get _inactiveCount =>
      _customers.where((customer) => !customer.isActive).length;

  Future<void> _openForm({Customer? customer}) async {
    final result = await showDialog<_CustomerFormResult>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    );

    if (result == null) return;

    final service = ref.read(debtServiceProvider);
    try {
      if (customer == null) {
        await service.addCustomer(
          name: result.name,
          phone: result.phone,
          address: result.address,
        );
      } else {
        await service.updateCustomer(
          customerId: customer.id,
          name: result.name,
          phone: result.phone,
          address: result.address,
          isActive: result.isActive,
        );
      }
      await _loadCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu khách hàng: $e')));
      }
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa khách hàng "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(debtServiceProvider);
      await service.deleteCustomer(customer.id);
      await _loadCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa khách hàng: $e')));
      }
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Khách hàng'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Trang chủ',
            icon: const Icon(Icons.home),
            onPressed: _goHome,
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
          if (isMobile)
            IconButton.filledTonal(
              tooltip: 'Thêm khách hàng',
              icon: const Icon(Icons.person_add),
              onPressed: () => _openForm(),
            )
          else
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: FilledButton.tonalIcon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.person_add),
                label: const Text('Thêm khách hàng'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            final horizontalPadding = constraints.maxWidth > 1400
                ? 72.w
                : isMobile
                ? 16.w
                : 24.w;

            return RefreshIndicator(
              onRefresh: _loadCustomers,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20.h,
                      horizontalPadding,
                      12.h,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CustomerHeader(
                            total: _customers.length,
                            active: _activeCount,
                            inactive: _inactiveCount,
                            isCompact: isCompact,
                          ),
                          SizedBox(height: 18.h),
                          _buildFilterBar(isMobile: isMobile),
                          SizedBox(height: 16.h),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _CustomerErrorState(message: _error!),
                    )
                  else if (_filteredCustomers.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _CustomerEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        32.h,
                      ),
                      sliver: SliverList.separated(
                        itemCount: _filteredCustomers.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return _CustomerCard(
                            customer: customer,
                            currency: currency,
                            onEdit: () => _openForm(customer: customer),
                            onDelete: () => _deleteCustomer(customer),
                          );
                        },
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

  Widget _buildFilterBar({required bool isMobile}) {
    final scheme = Theme.of(context).colorScheme;

    final filterChips = [
      _StatusFilterChip(
        label: 'Tất cả',
        selected: _statusFilter == _CustomerStatusFilter.all,
        onSelected: () =>
            setState(() => _statusFilter = _CustomerStatusFilter.all),
      ),
      _StatusFilterChip(
        label: 'Đang hoạt động',
        selected: _statusFilter == _CustomerStatusFilter.active,
        onSelected: () =>
            setState(() => _statusFilter = _CustomerStatusFilter.active),
      ),
      _StatusFilterChip(
        label: 'Ngừng hoạt động',
        selected: _statusFilter == _CustomerStatusFilter.inactive,
        onSelected: () =>
            setState(() => _statusFilter = _CustomerStatusFilter.inactive),
      ),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            if (isMobile)
              Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm khách hàng...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Áp dụng'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _loadCustomers();
                          setState(() {});
                        },
                        tooltip: 'Làm mới',
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm khách hàng...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Lọc'),
                  ),
                  SizedBox(width: 8.w),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _loadCustomers();
                      setState(() {});
                    },
                    tooltip: 'Làm mới',
                  ),
                ],
              ),
            SizedBox(height: 12.h),
            if (isMobile)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in filterChips)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: chip,
                      ),
                  ],
                ),
              )
            else
              Wrap(spacing: 8.w, runSpacing: 8.h, children: filterChips),
          ],
        ),
      ),
    );
  }
}

enum _CustomerStatusFilter { all, active, inactive }

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = customer.isActive;
    final scheme = Theme.of(context).colorScheme;
    final debtColor = customer.currentDebt > 0
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive
                      ? Colors.blue.shade100
                      : Colors.grey.shade300,
                  child: Icon(
                    Icons.person,
                    color: isActive ? Colors.blue : Colors.grey,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (customer.phone != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          customer.phone!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(isActive: isActive),
              ],
            ),
            if (customer.address != null) ...[
              SizedBox(height: 8.h),
              Text(
                customer.address!,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 12.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 8.h,
              children: [
                _MetricPill(
                  label: 'Nợ hiện tại',
                  value: currency.format(customer.currentDebt),
                  color: debtColor,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete, color: scheme.error),
                  label: Text('Xóa', style: TextStyle(color: scheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16.sp, color: color),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.14),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.total,
    required this.active,
    required this.inactive,
    required this.isCompact,
  });

  final int total;
  final int active;
  final int inactive;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18.w : 22.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh sách khách hàng',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Theo dõi công nợ và trạng thái hoạt động của khách hàng.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HeaderMetric(
                  label: 'Tổng',
                  value: '$total',
                  icon: Icons.groups_rounded,
                  color: Colors.white,
                  foreground: scheme.primary,
                  compact: isCompact,
                ),
                SizedBox(width: 10.w),
                _HeaderMetric(
                  label: 'Đang hoạt động',
                  value: '$active',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFFDCFCE7),
                  foreground: const Color(0xFF166534),
                  compact: isCompact,
                ),
                SizedBox(width: 10.w),
                _HeaderMetric(
                  label: 'Ngừng',
                  value: '$inactive',
                  icon: Icons.pause_circle_rounded,
                  color: const Color(0xFFFFEDD5),
                  foreground: const Color(0xFF9A3412),
                  compact: isCompact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.compact,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.w : 16.w,
        vertical: compact ? 10.h : 12.h,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 6.w : 8.w),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: foreground, size: compact ? 18.sp : 20.sp),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12.sp : null,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 18.sp : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerEmptyState extends StatelessWidget {
  const _CustomerEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 46.sp,
                color: scheme.primary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Chưa có khách hàng',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6.h),
            Text(
              'Thêm khách hàng để bắt đầu quản lý công nợ và bán hàng hiệu quả.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerErrorState extends StatelessWidget {
  const _CustomerErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 42.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Đã xảy ra lỗi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
    _isActive = widget.customer?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _CustomerFormResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Thêm khách hàng' : 'Chỉnh sửa khách hàng',
      ),
      content: SizedBox(
        width: 420.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên khách hàng',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên'
                      : null,
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                ),
                SizedBox(height: 12.h),
                SwitchListTile.adaptive(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Đang hoạt động'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}

class _CustomerFormResult {
  final String name;
  final String? phone;
  final String? address;
  final bool isActive;

  const _CustomerFormResult({
    required this.name,
    this.phone,
    this.address,
    required this.isActive,
  });
}
