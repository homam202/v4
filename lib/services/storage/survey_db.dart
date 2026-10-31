import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// surveys(id, name, created_at, rows, cols, spacing_cm, matrix_json)
class SurveyDb {
  static Future<Database> open() async => openDatabase(
        p.join(await getDatabasesPath(), 'terramag.db'),
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE surveys(
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, created_at TEXT,
            rows INTEGER, cols INTEGER, spacing_cm INTEGER, matrix_json TEXT)'''),
      );

  static Future<int> save(String name, List<List<double>> m, int spacingCm) async {
    final db = await open();
    return db.insert('surveys', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'rows': m.length, 'cols': m.first.length, 'spacing_cm': spacingCm,
      // NaN is not valid JSON -> store unmeasured cells as null
      'matrix_json': jsonEncode(m.map((r) => r.map((v) => v.isNaN ? null : v).toList()).toList()),
    });
  }
}
