import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Local SQLite database service for offline support
class LocalDbService {
  static LocalDbService? _instance;
  static Database? _database;

  LocalDbService._();

  /// Get singleton instance
  static LocalDbService get instance {
    _instance ??= LocalDbService._();
    return _instance!;
  }

  /// Initialize local database
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize FFI for Windows/Linux desktop
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String path = join(appDocDir.path, 'tap_hoa_local.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables for offline queue
  Future<void> _onCreate(Database db, int version) async {
    // Offline queue for pending transactions
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Cached products for offline POS
    await db.execute('''
      CREATE TABLE cached_products (
        id TEXT PRIMARY KEY,
        barcode TEXT,
        name TEXT NOT NULL,
        category_id TEXT,
        unit TEXT NOT NULL,
        current_stock REAL,
        avg_cost_price REAL,
        synced_at INTEGER NOT NULL
      )
    ''');

    // Cached customers for offline debt tracking
    await db.execute('''
      CREATE TABLE cached_customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        current_debt REAL,
        synced_at INTEGER NOT NULL
      )
    ''');

    // Offline sales (pending sync)
    await db.execute('''
      CREATE TABLE offline_sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        customer_id TEXT,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        items TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(cached_customers)',
      );
      final hasDebtLimit = tableInfo.any(
        (column) => column['name'] == 'debt_limit',
      );
      if (hasDebtLimit) {
        await db.execute('DROP TABLE IF EXISTS cached_customers_new');
        await db.execute('''
          CREATE TABLE cached_customers_new (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            current_debt REAL,
            synced_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          INSERT INTO cached_customers_new (
            id,
            name,
            phone,
            current_debt,
            synced_at
          )
          SELECT id, name, phone, current_debt, synced_at
          FROM cached_customers
        ''');
        await db.execute('DROP TABLE cached_customers');
        await db.execute(
          'ALTER TABLE cached_customers_new RENAME TO cached_customers',
        );
      }
    }
  }

  /// Add to offline queue
  Future<int> addToQueue({
    required String tableName,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    return await db.insert('offline_queue', {
      'table_name': tableName,
      'operation': operation,
      'data': data.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get pending queue items
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await database;
    return await db.query('offline_queue', orderBy: 'created_at ASC');
  }

  /// Remove from queue
  Future<void> removeFromQueue(int id) async {
    final db = await database;
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Update retry count
  Future<void> updateRetryCount(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE offline_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  /// Cache products
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert('cached_products', {
        ...product,
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Get cached products
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    final db = await database;
    return await db.query('cached_products');
  }

  /// Clear all caches
  Future<void> clearCaches() async {
    final db = await database;
    await db.delete('cached_products');
    await db.delete('cached_customers');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
