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
        return MaterialApp(
          title: 'Quản lý Tạp hóa',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tạp hóa'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                authState.user?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const POSScreen()),
                );
              },
              icon: const Icon(Icons.point_of_sale, size: 32),
              label: const Text('Bán hàng (POS)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                minimumSize: const Size(200, 80),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.category, size: 32),
              label: const Text('Quản lý Sản phẩm'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                minimumSize: const Size(200, 80),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventoryManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.inventory, size: 32),
              label: const Text('Quản lý Kho'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                minimumSize: const Size(200, 80),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebtManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet, size: 32),
              label: const Text('Quản lý Công nợ'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                minimumSize: const Size(200, 80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
