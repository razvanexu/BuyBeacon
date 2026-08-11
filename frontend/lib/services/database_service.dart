import 'package:buy_beacon/models/product.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  //initializes DB first time
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '${dbPath}buybeacon.db';
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  //creates DB
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL)
    ''');
  }

  //Create / insert product
  Future<int> addProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  //read all products
  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');

    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id =?', whereArgs: [id]);
  }
}
