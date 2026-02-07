import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../providers/debt_provider.dart';
import '../services/debt_service.dart';

class DebtManagementScreen extends ConsumerStatefulWidget {
  const DebtManagementScreen({super.key});

  @override
  ConsumerState<DebtManagementScreen> createState() =>
      _DebtManagementScreenState();
}

class _DebtManagementScreenState extends ConsumerState<DebtManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyDebt = false;
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
      final data = _showOnlyDebt
          ? await service.getCustomersWithDebt()
          : await service.getCustomers();
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

  void _setTab(bool showOnlyDebt) {
    if (_showOnlyDebt == showOnlyDebt) return;
    setState(() {
      _showOnlyDebt = showOnlyDebt;
    });
    _loadCustomers();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  List<Customer> get _filteredCustomers {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _customers.where((customer) {
      final matchesQuery =
          query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          (customer.phone?.contains(query) ?? false);
      if (_showOnlyDebt) {
        return matchesQuery && customer.currentDebt > 0;
      }
      return matchesQuery;
    }).toList();

    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  int get _totalCustomers => _filteredCustomers.length;

  int get _customersWithDebt =>
      _filteredCustomers.where((customer) => customer.currentDebt > 0).length;

  double get _totalDebt =>
      _filteredCustomers.fold(0, (sum, customer) => sum + customer.currentDebt);

  Future<void> _openPaymentDialog(
    Customer customer, {
    DebtPayment? payment,
  }) async {
    final service = ref.read(debtServiceProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DebtPaymentDialog(
        customer: customer,
        service: service,
        payment: payment,
      ),
    );

    if (result == true) {
      await _loadCustomers();
    }
  }

  Future<void> _openDebtLineDialog(Customer customer, {DebtLine? line}) async {
    final service = ref.read(debtServiceProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          DebtLineDialog(customer: customer, service: service, line: line),
    );

    if (result == true) {
      await _loadCustomers();
    }
  }

  Future<void> _openDetail(Customer customer) async {
    final service = ref.read(debtServiceProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => DebtDetailDialog(
        customer: customer,
        service: service,
        onRefreshCustomers: _loadCustomers,
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Công nợ'),
        actions: [
          IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
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
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              _DebtOverviewCard(
                totalCustomers: _totalCustomers,
                customersWithDebt: _customersWithDebt,
                totalDebt: _totalDebt,
                currency: currency,
              ),
              SizedBox(height: 12.h),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      _DebtTabBar(
                        showOnlyDebt: _showOnlyDebt,
                        onTabChanged: _setTab,
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm khách hàng...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Xoá tìm kiếm',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tìm thấy $_totalCustomers khách hàng',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text('Lỗi: $_error'))
                    : _filteredCustomers.isEmpty
                    ? const Center(child: Text('Không tìm thấy khách hàng.'))
                    : ListView.separated(
                        itemCount: _filteredCustomers.length,
                        separatorBuilder: (_, index) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return DebtCustomerCard(
                            customer: customer,
                            currency: currency,
                            showAddDebt: _showOnlyDebt,
                            onAddDebt: () => _openDebtLineDialog(customer),
                            onCollect: () => _openPaymentDialog(customer),
                            onDetail: () => _openDetail(customer),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtTabBar extends StatelessWidget {
  final bool showOnlyDebt;
  final ValueChanged<bool> onTabChanged;

  const _DebtTabBar({required this.showOnlyDebt, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              selected: !showOnlyDebt,
              label: 'Tất cả',
              icon: Icons.groups,
              onTap: () => onTabChanged(false),
            ),
          ),
          Expanded(
            child: _TabButton(
              selected: showOnlyDebt,
              label: 'Công nợ',
              icon: Icons.account_balance_wallet,
              onTap: () => onTabChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TabButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtOverviewCard extends StatelessWidget {
  final int totalCustomers;
  final int customersWithDebt;
  final double totalDebt;
  final NumberFormat currency;

  const _DebtOverviewCard({
    required this.totalCustomers,
    required this.customersWithDebt,
    required this.totalDebt,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countFormat = NumberFormat.decimalPattern('vi_VN');
    final hasDebt = totalDebt > 0;
    final debtColor = hasDebt ? scheme.error : scheme.onSurfaceVariant;
    final debtBackground = hasDebt
        ? scheme.errorContainer.withValues(alpha: 0.6)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final tiles = [
      _DebtOverviewTile(
        label: 'Tổng khách',
        value: countFormat.format(totalCustomers),
        icon: Icons.groups_rounded,
        color: scheme.primary,
        background: scheme.primaryContainer.withValues(alpha: 0.6),
      ),
      _DebtOverviewTile(
        label: 'Đang nợ',
        value: countFormat.format(customersWithDebt),
        icon: Icons.account_balance_wallet_rounded,
        color: scheme.tertiary,
        background: scheme.tertiaryContainer.withValues(alpha: 0.6),
      ),
      _DebtOverviewTile(
        label: 'Tổng công nợ',
        value: currency.format(totalDebt),
        icon: Icons.payments_rounded,
        color: debtColor,
        background: debtBackground,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          if (isNarrow) {
            return Column(
              children: [
                tiles[0],
                SizedBox(height: 10.h),
                tiles[1],
                SizedBox(height: 10.h),
                tiles[2],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: tiles[0]),
              SizedBox(width: 12.w),
              Expanded(child: tiles[1]),
              SizedBox(width: 12.w),
              Expanded(child: tiles[2]),
            ],
          );
        },
      ),
    );
  }
}

class _DebtOverviewTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  const _DebtOverviewTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DebtCustomerCard extends StatelessWidget {
  final Customer customer;
  final NumberFormat currency;
  final bool showAddDebt;
  final VoidCallback onAddDebt;
  final VoidCallback onCollect;
  final VoidCallback onDetail;

  const DebtCustomerCard({
    super.key,
    required this.customer,
    required this.currency,
    required this.showAddDebt,
    required this.onAddDebt,
    required this.onCollect,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDebt = customer.currentDebt > 0;
    final statusColor = hasDebt ? scheme.error : scheme.primary;
    final badgeBackground = statusColor.withValues(alpha: 0.12);
    final statusText = hasDebt ? 'Đang nợ' : 'Không nợ';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: badgeBackground,
                  child: Icon(Icons.person, color: statusColor),
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (customer.address != null) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      customer.address!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 12.h),
            Divider(height: 1.h),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _DebtMetric(
                    label: 'Nợ hiện tại',
                    value: currency.format(customer.currentDebt),
                    valueColor: hasDebt ? scheme.error : Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                if (showAddDebt)
                  FilledButton.icon(
                    onPressed: onAddDebt,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Thêm nợ'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: onCollect,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Thu nợ'),
                ),
                OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Chi tiết'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final Color? valueColor;

  const _DebtMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class DebtDetailDialog extends StatefulWidget {
  final Customer customer;
  final DebtService service;
  final VoidCallback onRefreshCustomers;

  const DebtDetailDialog({
    super.key,
    required this.customer,
    required this.service,
    required this.onRefreshCustomers,
  });

  @override
  State<DebtDetailDialog> createState() => _DebtDetailDialogState();
}

class _DebtDetailDialogState extends State<DebtDetailDialog> {
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  String? _error;
  List<DebtLine> _lines = [];
  List<CustomerSale> _sales = [];
  List<DebtPayment> _payments = [];
  bool _showDuplicateOnly = false;
  int? _selectedYear;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await widget.service.getCustomerHistory(
        widget.customer.id,
        year: _selectedYear,
      );
      final lines = _showDuplicateOnly
          ? await widget.service.getDuplicateDebtLines(
              widget.customer.id,
              year: _selectedYear,
            )
          : await widget.service.getDebtLines(
              widget.customer.id,
              year: _selectedYear,
            );
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _sales = history.sales;
        _payments = history.payments;
        _updateAvailableYears();
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

  Future<void> _toggleDuplicateFilter(bool value) async {
    if (_showDuplicateOnly == value) return;
    setState(() {
      _showDuplicateOnly = value;
    });
    await _loadData();
  }

  List<DebtLine> get _filteredLines =>
      _filterByYear(_lines, (line) => line.createdAt);

  List<CustomerSale> get _filteredSales =>
      _filterByYear(_sales, (sale) => sale.createdAt);

  List<DebtPayment> get _filteredPayments =>
      _filterByYear(_payments, (payment) => payment.createdAt);

  List<T> _filterByYear<T>(List<T> items, DateTime? Function(T) getDate) {
    if (_selectedYear == null) return items;
    return items.where((item) => getDate(item)?.year == _selectedYear).toList();
  }

  void _updateAvailableYears() {
    if (_selectedYear != null && _availableYears.isNotEmpty) return;
    final years = <int>{};
    for (final line in _lines) {
      final year = line.createdAt?.year;
      if (year != null) years.add(year);
    }
    for (final sale in _sales) {
      final year = sale.createdAt?.year;
      if (year != null) years.add(year);
    }
    for (final payment in _payments) {
      final year = payment.createdAt?.year;
      if (year != null) years.add(year);
    }
    final sorted = years.toList()..sort((a, b) => b - a);
    _availableYears = sorted;
    if (_selectedYear != null && !_availableYears.contains(_selectedYear)) {
      _selectedYear = null;
    }
  }

  Future<void> _openPaymentDialog({DebtPayment? payment}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DebtPaymentDialog(
        customer: widget.customer,
        service: widget.service,
        payment: payment,
      ),
    );

    if (result == true) {
      await _loadData();
      widget.onRefreshCustomers();
    }
  }

  Future<void> _openDebtLineDialog({DebtLine? line}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DebtLineDialog(
        customer: widget.customer,
        service: widget.service,
        line: line,
      ),
    );

    if (result == true) {
      await _loadData();
      widget.onRefreshCustomers();
    }
  }

  Future<void> _deleteDebtLine(DebtLine line) async {
    if (line.items.isNotEmpty) return;
    final confirmed = await _confirm(
      'Xóa dòng nợ',
      'Bạn có chắc muốn xóa dòng nợ này không?',
    );
    if (!confirmed) return;

    try {
      await widget.service.deleteDebtLine(line.id);
      await _loadData();
      widget.onRefreshCustomers();
    } catch (e) {
      _showMessage('Không thể xóa dòng nợ: $e', isError: true);
    }
  }

  Future<void> _deletePayment(DebtPayment payment) async {
    final confirmed = await _confirm(
      'Xóa thanh toán',
      'Bạn có chắc muốn xóa phiếu thanh toán này không?',
    );
    if (!confirmed) return;

    try {
      await widget.service.deletePayment(payment.id!);
      await _loadData();
      widget.onRefreshCustomers();
    } catch (e) {
      _showMessage('Không thể xóa thanh toán: $e', isError: true);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'transfer':
        return 'Chuyển khoản';
      case 'debt':
        return 'Ghi nợ';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: EdgeInsets.all(18.w),
      child: SizedBox(
        width: 980.w,
        height: 640.h,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chi tiết khách hàng - ${widget.customer.name}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        label: 'Nợ hiện tại',
                        value: _currency.format(widget.customer.currentDebt),
                      ),
                    ),
                  ],
                ),
              ),
              if (_availableYears.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Text(
                        'Năm',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tất cả'),
                            ),
                            ..._availableYears.map(
                              (year) => DropdownMenuItem<int?>(
                                value: year,
                                child: Text('$year'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                            });
                            _loadData();
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: scheme.surface,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h,
                              horizontal: 12.w,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(
                                color: scheme.outline.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              const TabBar(
                tabs: [
                  Tab(text: 'Dòng nợ'),
                  Tab(text: 'Hóa đơn'),
                  Tab(text: 'Thanh toán nợ'),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text('Lỗi: $_error'))
                    : TabBarView(
                        children: [
                          _buildDebtLinesTab(),
                          _buildSalesTab(),
                          _buildPaymentsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtLinesTab() {
    final sortedLines = [..._filteredLines]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = bDate.compareTo(aDate);
        if (byDate != 0) return byDate;
        return b.invoiceNumber.compareTo(a.invoiceNumber);
      });
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12.w,
                runSpacing: 8.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openDebtLineDialog(),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Thêm nợ'),
                  ),
                  FilterChip(
                    label: const Text('Chỉ ngày trùng'),
                    selected: _showDuplicateOnly,
                    onSelected: _toggleDuplicateFilter,
                  ),
                  if (_showDuplicateOnly)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Đang lọc ngày mua trùng',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                'Chỉ áp dụng cho nợ nhập tay.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: _filteredLines.isEmpty
                ? Center(
                    child: Text(
                      _showDuplicateOnly
                          ? 'Không có dòng nợ trùng ngày.'
                          : 'Chưa có dòng nợ.',
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          scheme.surfaceContainerHighest,
                        ),
                        columnSpacing: 20.w,
                        dataRowMinHeight: 48.h,
                        dataRowMaxHeight: 160.h,
                        columns: const [
                          DataColumn(label: Text('STT')),
                          DataColumn(label: Text('Mã hóa đơn')),
                          DataColumn(label: Text('Ngày mua')),
                          DataColumn(label: Text('Hẹn trả')),
                          DataColumn(label: Text('Loại')),
                          DataColumn(label: Text('Số tiền')),
                          DataColumn(label: Text('Ghi chú')),
                          DataColumn(label: Text('Sản phẩm')),
                          DataColumn(label: Text('Thao tác')),
                        ],
                        rows: sortedLines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          final canEdit = line.items.isEmpty;
                          return DataRow(
                            color: MaterialStateProperty.all(
                              index.isEven
                                  ? scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.25,
                                    )
                                  : null,
                            ),
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(line.invoiceNumber)),
                              DataCell(
                                Text(
                                  line.createdAt != null
                                      ? _dateTimeFormat.format(line.createdAt!)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  line.dueDate != null
                                      ? _dateFormat.format(line.dueDate!)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(canEdit ? 'Nợ nhập tay' : 'Hóa đơn'),
                              ),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _currency.format(line.finalAmount),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  line.notes?.isNotEmpty == true
                                      ? line.notes!
                                      : '-',
                                ),
                              ),
                              DataCell(
                                line.items.isEmpty
                                    ? const Text('-')
                                    : SizedBox(
                                        width: 260.w,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: line.items
                                              .map(
                                                (item) => Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 4.h,
                                                  ),
                                                  child: Text(
                                                    '${item.productName} (${item.quantity.toStringAsFixed(0)} ${item.unit}) · ${_currency.format(item.subtotal)}',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                              ),
                              DataCell(
                                canEdit
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Sửa',
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                _openDebtLineDialog(line: line),
                                          ),
                                          IconButton(
                                            tooltip: 'Xóa',
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _deleteDebtLine(line),
                                          ),
                                        ],
                                      )
                                    : const Text('-'),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: _filteredSales.isEmpty
          ? const Center(
              child: Text('Ch\u01b0a c\u00f3 h\u00f3a \u0111\u01a1n.'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    scheme.surfaceContainerHighest,
                  ),
                  columnSpacing: 20.w,
                  dataRowMinHeight: 48.h,
                  dataRowMaxHeight: 64.h,
                  columns: const [
                    DataColumn(label: Text('STT')),
                    DataColumn(label: Text('M\u00e3 h\u00f3a \u0111\u01a1n')),
                    DataColumn(label: Text('Ng\u00e0y')),
                    DataColumn(label: Text('T\u1ed5ng')),
                    DataColumn(label: Text('Gi\u1ea3m gi\u00e1')),
                    DataColumn(label: Text('Th\u00e0nh ti\u1ec1n')),
                    DataColumn(label: Text('H\u1eb9n tr\u1ea3')),
                    DataColumn(label: Text('Thanh to\u00e1n')),
                  ],
                  rows: _filteredSales.asMap().entries.map((entry) {
                    final index = entry.key;
                    final sale = entry.value;
                    return DataRow(
                      color: MaterialStateProperty.all(
                        index.isEven
                            ? scheme.surfaceContainerHighest.withValues(
                                alpha: 0.25,
                              )
                            : null,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(sale.invoiceNumber)),
                        DataCell(
                          Text(
                            sale.createdAt != null
                                ? _dateTimeFormat.format(sale.createdAt!)
                                : '-',
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_currency.format(sale.totalAmount)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_currency.format(sale.discountAmount)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_currency.format(sale.finalAmount)),
                          ),
                        ),
                        DataCell(
                          Text(
                            sale.dueDate != null
                                ? _dateFormat.format(sale.dueDate!)
                                : '-',
                          ),
                        ),
                        DataCell(Text(_paymentMethodLabel(sale.paymentMethod))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentsTab() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: _filteredPayments.isEmpty
          ? const Center(child: Text('Ch\u01b0a c\u00f3 thanh to\u00e1n.'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    scheme.surfaceContainerHighest,
                  ),
                  columnSpacing: 20.w,
                  dataRowMinHeight: 48.h,
                  dataRowMaxHeight: 64.h,
                  columns: const [
                    DataColumn(label: Text('STT')),
                    DataColumn(label: Text('Ng\u00e0y')),
                    DataColumn(label: Text('S\u1ed1 ti\u1ec1n')),
                    DataColumn(label: Text('Ph\u01b0\u01a1ng th\u1ee9c')),
                    DataColumn(label: Text('Ghi ch\u00fa')),
                    DataColumn(label: Text('Thao t\u00e1c')),
                  ],
                  rows: _filteredPayments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final payment = entry.value;
                    return DataRow(
                      color: MaterialStateProperty.all(
                        index.isEven
                            ? scheme.surfaceContainerHighest.withValues(
                                alpha: 0.25,
                              )
                            : null,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          Text(
                            payment.createdAt != null
                                ? _dateTimeFormat.format(payment.createdAt!)
                                : '-',
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_currency.format(payment.amount)),
                          ),
                        ),
                        DataCell(
                          Text(_paymentMethodLabel(payment.paymentMethod)),
                        ),
                        DataCell(Text(payment.notes ?? '-')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'S\u1eeda',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _openPaymentDialog(payment: payment),
                              ),
                              IconButton(
                                tooltip: 'X\u00f3a',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deletePayment(payment),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class DebtPaymentDialog extends StatefulWidget {
  final Customer customer;
  final DebtService service;
  final DebtPayment? payment;

  const DebtPaymentDialog({
    super.key,
    required this.customer,
    required this.service,
    this.payment,
  });

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.payment != null ? widget.payment!.amount.toString() : '',
    );
    _notesController = TextEditingController(text: widget.payment?.notes ?? '');
    _paymentMethod = widget.payment?.paymentMethod ?? 'cash';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _availableDebt {
    final current = widget.customer.currentDebt;
    final editing = widget.payment?.amount ?? 0;
    return current + editing;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      if (widget.payment != null) {
        await widget.service.updatePayment(
          paymentId: widget.payment!.id!,
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        await widget.service.recordPayment(
          customerId: widget.customer.id,
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu thanh toán: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final scheme = Theme.of(context).colorScheme;
    final maxAmount = _availableDebt;
    final isEditing = widget.payment != null;

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa thu nợ' : 'Thu nợ'),
      content: SizedBox(
        width: 440.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(Icons.person, color: scheme.primary),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              widget.customer.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'Nợ hiện tại',
                              value: currency.format(
                                widget.customer.currentDebt,
                              ),
                              valueColor: scheme.error,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      _InfoTile(
                        label: 'Có thể thu',
                        value: currency.format(maxAmount),
                        valueColor: scheme.primary,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Số tiền thu',
                    helperText: 'Tối đa: ${currency.format(maxAmount)}',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₫',
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số tiền';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Số tiền không hợp lệ';
                    }
                    if (amount > _availableDebt) {
                      return 'Số tiền vượt quá nợ hiện tại';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                Text(
                  'Phương thức',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'cash',
                        label: Text('Tiền mặt'),
                        icon: Icon(Icons.payments_rounded),
                      ),
                      ButtonSegment(
                        value: 'transfer',
                        label: Text('Chuyển khoản'),
                        icon: Icon(Icons.account_balance_rounded),
                      ),
                    ],
                    selected: {_paymentMethod},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      if (value.isEmpty) return;
                      setState(() => _paymentMethod = value.first);
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    filled: true,
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Số tiền nhanh:',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _QuickAmountChip(
                      label: '50%',
                      amount: maxAmount / 2,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '100%',
                      amount: maxAmount,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '100K',
                      amount: 100000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '500K',
                      amount: 500000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '1M',
                      amount: 1000000,
                      onSelected: _setQuickAmount,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final Color? valueColor;

  const _InfoTile({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final double amount;
  final ValueChanged<double> onSelected;

  const _QuickAmountChip({
    required this.label,
    required this.amount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = amount <= 0;
    return ActionChip(
      label: Text(label),
      onPressed: isDisabled ? null : () => onSelected(amount),
    );
  }
}

class DebtLineDialog extends StatefulWidget {
  final Customer customer;
  final DebtService service;
  final DebtLine? line;

  const DebtLineDialog({
    super.key,
    required this.customer,
    required this.service,
    this.line,
  });

  @override
  State<DebtLineDialog> createState() => _DebtLineDialogState();
}

class _DebtLineDialogState extends State<DebtLineDialog> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _inputDateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _storageDateFormat = DateFormat('yyyy-MM-dd');
  late final TextEditingController _amountController;
  late final TextEditingController _purchaseDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.line != null ? widget.line!.finalAmount.toString() : '',
    );
    _purchaseDateController = TextEditingController(
      text: widget.line?.createdAt != null
          ? _inputDateFormat.format(widget.line!.createdAt!)
          : '',
    );
    _dueDateController = TextEditingController(
      text: widget.line?.dueDate != null
          ? _inputDateFormat.format(widget.line!.dueDate!)
          : '',
    );
    _notesController = TextEditingController(text: widget.line?.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purchaseDateController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initialDate = now;
    if (controller.text.trim().isNotEmpty) {
      try {
        initialDate = _inputDateFormat.parseStrict(controller.text.trim());
      } catch (_) {
        initialDate = now;
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = _inputDateFormat.format(picked);
    }
  }

  String? _toStorageDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final parsed = _inputDateFormat.parseStrict(text);
      return _storageDateFormat.format(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final purchaseDate = _toStorageDate(_purchaseDateController.text);
      final dueDate = _toStorageDate(_dueDateController.text);
      final notes = _notesController.text.trim();

      if (widget.line != null) {
        await widget.service.updateDebtLine(
          debtLineId: widget.line!.id,
          amount: amount,
          purchaseDate: purchaseDate,
          dueDate: dueDate,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.service.createDebtLine(
          customerId: widget.customer.id,
          amount: amount,
          purchaseDate: purchaseDate,
          dueDate: dueDate,
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu dòng nợ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.line != null;

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa nợ' : 'Thêm nợ'),
      content: SizedBox(
        width: 440.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(Icons.person, color: scheme.primary),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              widget.customer.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'Nợ hiện tại',
                              value: currency.format(
                                widget.customer.currentDebt,
                              ),
                              valueColor: scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền nợ',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: '₫',
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số tiền';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Số tiền không hợp lệ';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                Text(
                  'Số tiền gợi ý:',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _QuickAmountChip(
                      label: '100K',
                      amount: 100000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '200K',
                      amount: 200000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '500K',
                      amount: 500000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '1M',
                      amount: 1000000,
                      onSelected: _setQuickAmount,
                    ),
                    _QuickAmountChip(
                      label: '2M',
                      amount: 2000000,
                      onSelected: _setQuickAmount,
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _purchaseDateController,
                  decoration: InputDecoration(
                    labelText: 'Ngày mua (dd/MM/yyyy)',
                    hintText: 'VD: 05/02/2026',
                    suffixIcon: IconButton(
                      tooltip: 'Chọn ngày',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () => _pickDate(_purchaseDateController),
                    ),
                    filled: true,
                  ),
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    try {
                      _inputDateFormat.parseStrict(value.trim());
                    } catch (_) {
                      return 'Ngày mua không hợp lệ (dd/MM/yyyy)';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _dueDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Hẹn trả',
                    suffixIcon: IconButton(
                      tooltip: 'Chọn ngày',
                      icon: const Icon(Icons.event_available_outlined),
                      onPressed: () => _pickDate(_dueDateController),
                    ),
                    filled: true,
                  ),
                  onTap: () => _pickDate(_dueDateController),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    filled: true,
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'Áp dụng cho nợ nhập tay. Hóa đơn bán hàng không chỉnh sửa ở đây.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
