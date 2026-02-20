import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
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
  _CustomerStatusFilter _statusFilter = _CustomerStatusFilter.active;
  bool _isNearbyFilterEnabled = false;
  bool _isGettingCurrentLocation = false;
  double _nearbyRadiusKm = 3;
  Position? _currentPosition;
  Map<String, double> _customerDistanceMeters = {};
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
        if (_currentPosition != null) {
          _customerDistanceMeters = _calculateCustomerDistances(
            _currentPosition!,
            data,
          );
        }
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

  Map<String, double> _calculateCustomerDistances(
    Position currentPosition,
    List<Customer> customers,
  ) {
    final distanceMap = <String, double>{};
    for (final customer in customers) {
      final latitude = customer.latitude;
      final longitude = customer.longitude;
      if (latitude == null || longitude == null) {
        continue;
      }
      distanceMap[customer.id] = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        latitude,
        longitude,
      );
    }
    return distanceMap;
  }

  int _countNearbyCustomers(Map<String, double> distanceMap, double radiusKm) {
    final radiusInMeters = radiusKm * 1000;
    return distanceMap.values
        .where((distance) => distance <= radiusInMeters)
        .length;
  }

  String? _formatDistanceLabel(Customer customer) {
    if (!_isNearbyFilterEnabled) return null;
    final distance = _customerDistanceMeters[customer.id];
    if (distance == null) return null;
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  void _clearNearbyFilter() {
    setState(() {
      _isNearbyFilterEnabled = false;
    });
  }

  Future<void> _searchNearbyCustomers() async {
    if (_isGettingCurrentLocation) return;
    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật GPS để tìm khách hàng gần bạn.'),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ứng dụng chưa được cấp quyền truy cập vị trí.'),
          ),
        );
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      if (!mounted) return;

      final distanceMap = _calculateCustomerDistances(
        currentPosition,
        _customers,
      );
      final nearbyCount = _countNearbyCustomers(distanceMap, _nearbyRadiusKm);

      setState(() {
        _currentPosition = currentPosition;
        _customerDistanceMeters = distanceMap;
        _isNearbyFilterEnabled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tìm thấy $nearbyCount khách hàng trong bán kính ${_nearbyRadiusKm.toStringAsFixed(0)} km.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lấy vị trí hiện tại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  List<Customer> get _filteredCustomers {
    final query = _searchController.text.toLowerCase().trim();
    final radiusInMeters = _nearbyRadiusKm * 1000;
    final filtered = _customers.where((customer) {
      final matchesQuery =
          query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          (customer.phone?.contains(query) ?? false);
      final matchesStatus = switch (_statusFilter) {
        _CustomerStatusFilter.all => true,
        _CustomerStatusFilter.active => customer.isActive == true,
        _CustomerStatusFilter.inactive => customer.isActive == false,
      };
      final matchesNearby = !_isNearbyFilterEnabled
          ? true
          : (_customerDistanceMeters[customer.id] ?? double.infinity) <=
                radiusInMeters;
      return matchesQuery && matchesStatus && matchesNearby;
    }).toList();

    if (_isNearbyFilterEnabled) {
      filtered.sort((a, b) {
        final distanceA = _customerDistanceMeters[a.id] ?? double.infinity;
        final distanceB = _customerDistanceMeters[b.id] ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
    }

    return filtered;
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
          latitude: result.latitude,
          longitude: result.longitude,
        );
      } else {
        await service.updateCustomer(
          customerId: customer.id,
          name: result.name,
          phone: result.phone,
          address: result.address,
          latitude: result.latitude,
          longitude: result.longitude,
          updateLatitude: true,
          updateLongitude: true,
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

  Future<void> _openImageManager(Customer customer) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _CustomerImageManagerDialog(customer: customer),
    );

    if (changed == true && mounted) {
      await _loadCustomers();
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận ẩn'),
        content: Text('Ẩn khách hàng "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ẩn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(debtServiceProvider);
      await service.deleteCustomer(customer.id);
      await _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã ẩn khách hàng thành công.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể ẩn khách hàng: $e')));
      }
    }
  }

  Future<void> _openGoogleMap(Customer customer) async {
    final latitude = customer.latitude;
    final longitude = customer.longitude;
    final address = customer.address?.trim();

    final Uri? mapsUri;
    if (latitude != null && longitude != null) {
      mapsUri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$latitude,$longitude',
      });
    } else if (address != null && address.isNotEmpty) {
      mapsUri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có địa chỉ hoặc tọa độ để mở Google Map.'),
        ),
      );
      return;
    }

    try {
      final opened = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở Google Map.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể mở Google Map: $e')));
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
                          final avatarUrl = customer.avatarImagePath == null
                              ? null
                              : ref
                                    .read(debtServiceProvider)
                                    .getCustomerImagePublicUrl(
                                      customer.avatarImagePath!,
                                    );
                          return _CustomerCard(
                            customer: customer,
                            currency: currency,
                            avatarImageUrl: avatarUrl,
                            distanceLabel: _formatDistanceLabel(customer),
                            isMobile: isMobile,
                            onEdit: () => _openForm(customer: customer),
                            onManageImages: () => _openImageManager(customer),
                            onOpenGoogleMap: () => _openGoogleMap(customer),
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
        padding: EdgeInsets.all(isMobile ? 12 : 16.w),
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
                          _clearNearbyFilter();
                          _loadCustomers();
                          setState(() {});
                        },
                        tooltip: 'Làm mới',
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isGettingCurrentLocation
                            ? null
                            : _searchNearbyCustomers,
                        icon: _isGettingCurrentLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          _isNearbyFilterEnabled
                              ? 'Cập nhật vị trí'
                              : 'Tìm gần tôi',
                        ),
                      ),
                      if (_isNearbyFilterEnabled)
                        OutlinedButton.icon(
                          onPressed: _clearNearbyFilter,
                          icon: const Icon(Icons.location_disabled_outlined),
                          label: const Text('Bỏ lọc vị trí'),
                        ),
                    ],
                  ),
                  if (_isNearbyFilterEnabled) ...[
                    SizedBox(height: 10.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Bán kính:',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 8.w),
                          for (final radius in const [1.0, 3.0, 5.0, 10.0])
                            Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: ChoiceChip(
                                label: Text('${radius.toStringAsFixed(0)} km'),
                                selected: _nearbyRadiusKm == radius,
                                onSelected: (_) {
                                  setState(() {
                                    _nearbyRadiusKm = radius;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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
                      _clearNearbyFilter();
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final NumberFormat currency;
  final String? avatarImageUrl;
  final String? distanceLabel;
  final bool isMobile;
  final VoidCallback onEdit;
  final VoidCallback onManageImages;
  final VoidCallback onOpenGoogleMap;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.currency,
    required this.avatarImageUrl,
    required this.distanceLabel,
    required this.isMobile,
    required this.onEdit,
    required this.onManageImages,
    required this.onOpenGoogleMap,
    required this.onDelete,
  });

  void _openAvatarPreview(BuildContext context) {
    if (avatarImageUrl == null) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24.w,
          vertical: isMobile ? 24 : 40,
        ),
        child: SizedBox(
          width: isMobile ? double.infinity : 900.w,
          height: isMobile ? screenHeight * 0.72 : 620.h,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    avatarImageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Không tải được ảnh')),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final debtColor = customer.currentDebt > 0
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: avatarImageUrl == null
                      ? null
                      : () => _openAvatarPreview(context),
                  child: CircleAvatar(
                    radius: isMobile ? 22 : 24,
                    backgroundColor: customer.isActive
                        ? scheme.primary.withValues(alpha: 0.15)
                        : scheme.surfaceContainerHighest,
                    backgroundImage: avatarImageUrl == null
                        ? null
                        : NetworkImage(avatarImageUrl!),
                    child: avatarImageUrl == null
                        ? Icon(
                            Icons.person,
                            color: customer.isActive
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (customer.phone != null &&
                          customer.phone!.trim().isNotEmpty)
                        Text(
                          customer.phone!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    color: customer.isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFE2E8F0),
                  ),
                  child: Text(
                    customer.isActive ? 'Hoạt động' : 'Ngừng',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: customer.isActive
                          ? const Color(0xFF166534)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            if (customer.address != null && customer.address!.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  customer.address!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: debtColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Nợ: ${currency.format(customer.currentDebt)}',
                    style: TextStyle(
                      color: debtColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                if (distanceLabel != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      distanceLabel!,
                      style: TextStyle(
                        color: const Color(0xFF115E59),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa'),
                ),
                OutlinedButton.icon(
                  onPressed: onManageImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Ảnh'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenGoogleMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Bản đồ'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.hide_source_outlined, color: scheme.error),
                  label: Text('Ẩn', style: TextStyle(color: scheme.error)),
                ),
              ],
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
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isActive = true;
  bool _isFetchingLocation = false;
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
    _latitudeController = TextEditingController(
      text: widget.customer?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.customer?.longitude?.toString() ?? '',
    );
    _isActive = widget.customer?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  double? _parseCoordinate(String text) {
    final normalized = text.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _setCoordinates(double latitude, double longitude) {
    _latitudeController.text = latitude.toStringAsFixed(6);
    _longitudeController.text = longitude.toStringAsFixed(6);
  }

  Future<void> _fillLocationFromGps() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng bật GPS để lấy vị trí.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ứng dụng chưa được cấp quyền truy cập vị trí.'),
          ),
        );
        return;
      }

      const settings = LocationSettings(accuracy: LocationAccuracy.high);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      if (!mounted) return;
      _setCoordinates(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lấy vị trí GPS: $e')));
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final latitude = _parseCoordinate(_latitudeController.text);
    final longitude = _parseCoordinate(_longitudeController.text);

    final selectedPoint = await showDialog<LatLng>(
      context: context,
      builder: (context) => _CustomerLocationPickerDialog(
        initialLatitude: latitude,
        initialLongitude: longitude,
      ),
    );

    if (selectedPoint == null || !mounted) return;
    _setCoordinates(selectedPoint.latitude, selectedPoint.longitude);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();

    Navigator.of(context).pop(
      _CustomerFormResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        latitude: latitudeText.isEmpty ? null : _parseCoordinate(latitudeText),
        longitude: longitudeText.isEmpty
            ? null
            : _parseCoordinate(longitudeText),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Thêm khách hàng' : 'Sửa khách hàng',
      ),
      content: SizedBox(
        width: isMobile ? double.infinity : 420.w,
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Vĩ độ (latitude)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final parsed = _parseCoordinate(text);
                          if (parsed == null) return 'Không hợp lệ';
                          if (parsed < -90 || parsed > 90) return '-90 đến 90';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Kinh độ (longitude)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final parsed = _parseCoordinate(text);
                          if (parsed == null) return 'Không hợp lệ';
                          if (parsed < -180 || parsed > 180) {
                            return '-180 đến 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Để trống nếu chưa có vị trí.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                if (isMobile)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isFetchingLocation
                              ? null
                              : _fillLocationFromGps,
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            _isFetchingLocation
                                ? 'Đang lấy GPS...'
                                : 'Lấy vị trí GPS',
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickLocationOnMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Chọn trên bản đồ'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isFetchingLocation
                              ? null
                              : _fillLocationFromGps,
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            _isFetchingLocation
                                ? 'Đang lấy GPS...'
                                : 'Lấy vị trí GPS',
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickLocationOnMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Chọn trên bản đồ'),
                        ),
                      ),
                    ],
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
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const _CustomerFormResult({
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    required this.isActive,
  });
}

class _CustomerLocationPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const _CustomerLocationPickerDialog({
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<_CustomerLocationPickerDialog> createState() =>
      _CustomerLocationPickerDialogState();
}

class _CustomerLocationPickerDialogState
    extends State<_CustomerLocationPickerDialog> {
  late LatLng _selectedPoint;
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint =
        widget.initialLatitude != null && widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : const LatLng(21.027764, 105.834160);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final horizontalInset = _isMapExpanded
        ? (isMobile ? 6.0 : 24.0)
        : (isMobile ? 12.0 : 40.0);
    final verticalInset = _isMapExpanded ? 8.0 : 24.0;
    final dialogWidth = isMobile
        ? double.infinity
        : (_isMapExpanded ? screenWidth * 0.82 : 560.w);
    final mapHeight = _isMapExpanded
        ? screenHeight * (isMobile ? 0.82 : 0.76)
        : (isMobile ? screenHeight * 0.52 : 480.h);

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Chọn vị trí trên bản đồ')),
          IconButton(
            tooltip: _isMapExpanded ? 'Thu gọn bản đồ' : 'Mở rộng bản đồ',
            onPressed: () {
              setState(() => _isMapExpanded = !_isMapExpanded);
            },
            icon: Icon(
              _isMapExpanded ? Icons.close_fullscreen : Icons.open_in_full,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: mapHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedPoint,
                    initialZoom: 16,
                    onTap: (_, point) {
                      setState(() {
                        _selectedPoint = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.quan_ly_tap_hoa',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPoint,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            Text(
              'Chạm vào bản đồ để đặt vị trí khách hàng.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedPoint),
          child: const Text('Chọn vị trí'),
        ),
      ],
    );
  }
}

class _CustomerImageManagerDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const _CustomerImageManagerDialog({required this.customer});

  @override
  ConsumerState<_CustomerImageManagerDialog> createState() =>
      _CustomerImageManagerDialogState();
}

class _CustomerImageManagerDialogState
    extends ConsumerState<_CustomerImageManagerDialog> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isUpdatingAvatar = false;
  bool _hasChanges = false;
  String? _avatarImagePath;
  String? _error;
  List<CustomerImage> _images = [];

  @override
  void initState() {
    super.initState();
    _avatarImagePath = widget.customer.avatarImagePath;
    _loadImages();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String? _resolveContentType(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.heic')) return 'image/heic';
    if (normalized.endsWith('.heif')) return 'image/heif';
    return null;
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = ref.read(debtServiceProvider);
      final data = await service.getCustomerImages(widget.customer.id);
      if (!mounted) return;
      setState(() {
        _images = data;
        if (_avatarImagePath != null &&
            !_images.any((item) => item.imagePath == _avatarImagePath)) {
          _avatarImagePath = null;
        }
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

  Future<void> _pickAndUploadImages() async {
    if (_isUploading) return;
    final remainingSlots = AppConstants.maxCustomerImages - _images.length;
    if (remainingSlots <= 0) {
      _showMessage(
        'Khách hàng đã đạt tối đa ${AppConstants.maxCustomerImages} ảnh.',
        isError: true,
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return;
    final selectedFiles = picked.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .toList();
    if (selectedFiles.isEmpty) {
      _showMessage('Không có dữ liệu ảnh hợp lệ để tải lên.', isError: true);
      return;
    }
    final uploadQueue = selectedFiles.take(remainingSlots).toList();
    final skippedByLimit = selectedFiles.length - uploadQueue.length;

    setState(() => _isUploading = true);
    try {
      final service = ref.read(debtServiceProvider);
      var uploadedCount = 0;
      var failedCount = 0;
      for (final file in uploadQueue) {
        final Uint8List? bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          failedCount++;
          continue;
        }
        try {
          await service.uploadCustomerImage(
            customerId: widget.customer.id,
            bytes: bytes,
            fileName: file.name,
            contentType: _resolveContentType(file.name),
          );
          uploadedCount++;
        } catch (_) {
          failedCount++;
        }
      }

      if (uploadedCount > 0) {
        _hasChanges = true;
        await _loadImages();
        _showMessage('Đã tải lên $uploadedCount ảnh.');
      }
      if (skippedByLimit > 0) {
        _showMessage(
          'Đã bỏ qua $skippedByLimit ảnh vì vượt giới hạn ${AppConstants.maxCustomerImages} ảnh/khách hàng.',
          isError: true,
        );
      }
      if (failedCount > 0) {
        _showMessage('Có $failedCount ảnh tải lên thất bại.', isError: true);
      }
      if (uploadedCount == 0 && failedCount == 0) {
        _showMessage('Không có dữ liệu ảnh hợp lệ để tải lên.', isError: true);
      }
    } catch (error) {
      _showMessage('Không thể tải ảnh lên: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _setAsAvatar(CustomerImage image) async {
    if (_isUpdatingAvatar) return;
    setState(() => _isUpdatingAvatar = true);
    try {
      final service = ref.read(debtServiceProvider);
      await service.setCustomerAvatar(
        customerId: widget.customer.id,
        imagePath: image.imagePath,
      );
      if (!mounted) return;
      setState(() {
        _avatarImagePath = image.imagePath;
        _hasChanges = true;
      });
      _showMessage('Đã đặt ảnh đại diện.');
    } catch (error) {
      _showMessage('Không thể đặt ảnh đại diện: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
      }
    }
  }

  Future<void> _clearAvatar() async {
    if (_isUpdatingAvatar || _avatarImagePath == null) return;
    setState(() => _isUpdatingAvatar = true);
    try {
      final service = ref.read(debtServiceProvider);
      await service.setCustomerAvatar(
        customerId: widget.customer.id,
        imagePath: null,
      );
      if (!mounted) return;
      setState(() {
        _avatarImagePath = null;
        _hasChanges = true;
      });
      _showMessage('Đã gỡ ảnh đại diện.');
    } catch (error) {
      _showMessage('Không thể gỡ ảnh đại diện: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
      }
    }
  }

  Future<void> _deleteImage(CustomerImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa ảnh'),
        content: const Text('Bạn có chắc muốn xóa ảnh này?'),
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
      await service.deleteCustomerImage(image.id);
      if (!mounted) return;
      setState(() {
        if (_avatarImagePath == image.imagePath) {
          _avatarImagePath = null;
        }
        _hasChanges = true;
      });
      await _loadImages();
      _showMessage('Đã xóa ảnh.');
    } catch (e) {
      _showMessage('Không thể xóa ảnh: $e', isError: true);
    }
  }

  void _openPreview(String imageUrl) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobilePreview = screenWidth < 600;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobilePreview ? 12 : 24.w,
          vertical: isMobilePreview ? 24 : 40,
        ),
        child: SizedBox(
          width: isMobilePreview ? double.infinity : 900.w,
          height: isMobilePreview ? screenHeight * 0.7 : 620.h,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Không tải được ảnh')),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(debtServiceProvider);
    final isLimitReached = _images.length >= AppConstants.maxCustomerImages;
    final remainingSlots = (AppConstants.maxCustomerImages - _images.length)
        .clamp(0, AppConstants.maxCustomerImages);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobileImg = screenWidth < 600;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobileImg ? 12 : 40,
        vertical: 24,
      ),
      child: SizedBox(
        width: isMobileImg ? double.infinity : 780.w,
        height: isMobileImg ? screenHeight * 0.7 : 560.h,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ảnh khách hàng - ${widget.customer.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: isMobileImg ? 16 : null,
                ),
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 8.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _isUploading || isLimitReached
                        ? null
                        : _pickAndUploadImages,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_isUploading ? 'Đang tải...' : 'Thêm ảnh'),
                  ),
                  Text(
                    '${_images.length}/${AppConstants.maxCustomerImages} ảnh',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _avatarImagePath == null
                        ? null
                        : () => _openPreview(
                            service.getCustomerImagePublicUrl(
                              _avatarImagePath!,
                            ),
                          ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Xem avatar'),
                  ),
                  TextButton.icon(
                    onPressed: _isUpdatingAvatar || _avatarImagePath == null
                        ? null
                        : _clearAvatar,
                    icon: _isUpdatingAvatar
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_remove_alt_1_outlined),
                    label: const Text('Gỡ avatar'),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                isLimitReached
                    ? 'Đã đạt giới hạn ảnh cho khách hàng này.'
                    : 'Còn trống $remainingSlots vị trí ảnh. Ảnh được tự động nén trước khi tải lên.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _avatarImagePath == null
                    ? 'Chưa đặt avatar.'
                    : 'Đã đặt avatar cho khách hàng.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    : _images.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 40.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Chưa có ảnh cho khách hàng này.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final dialogWidth = isMobileImg
                              ? screenWidth - 24
                              : 780.w.toDouble();
                          final crossAxisCount = dialogWidth > 920
                              ? 4
                              : dialogWidth > 620
                              ? 3
                              : 2;
                          return GridView.builder(
                            itemCount: _images.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 10.h,
                                  crossAxisSpacing: 10.w,
                                  childAspectRatio: 0.95,
                                ),
                            itemBuilder: (context, index) {
                              final image = _images[index];
                              final imageUrl = service
                                  .getCustomerImagePublicUrl(image.imagePath);
                              final isAvatar =
                                  _avatarImagePath == image.imagePath;
                              return _CustomerImageTile(
                                imageUrl: imageUrl,
                                subtitle: _dateFormat.format(image.createdAt),
                                isAvatar: isAvatar,
                                onTap: () => _openPreview(imageUrl),
                                onSetAvatar: () => _setAsAvatar(image),
                                onDelete: () => _deleteImage(image),
                              );
                            },
                          );
                        },
                      ),
              ),
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_hasChanges),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerImageTile extends StatelessWidget {
  final String imageUrl;
  final String subtitle;
  final bool isAvatar;
  final VoidCallback onTap;
  final VoidCallback onSetAvatar;
  final VoidCallback onDelete;

  const _CustomerImageTile({
    required this.imageUrl,
    required this.subtitle,
    required this.isAvatar,
    required this.onTap,
    required this.onSetAvatar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 30.sp,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filled(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      iconSize: 18.sp,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.58),
                        foregroundColor: Colors.white,
                        minimumSize: Size(34.w, 34.h),
                      ),
                      tooltip: 'Xóa ảnh',
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IconButton.filled(
                      onPressed: isAvatar ? null : onSetAvatar,
                      icon: Icon(
                        isAvatar ? Icons.star : Icons.star_border,
                        color: isAvatar ? Colors.amberAccent : Colors.white,
                      ),
                      iconSize: 18.sp,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.58),
                        minimumSize: Size(34.w, 34.h),
                      ),
                      tooltip: isAvatar ? 'Ảnh đại diện' : 'Đặt làm avatar',
                    ),
                  ),
                  if (isAvatar)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Avatar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14.sp,
                    color: scheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
