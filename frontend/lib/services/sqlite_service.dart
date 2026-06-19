import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/reminder.dart';

class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  factory SQLiteService() => _instance;
  SQLiteService._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'reminders.db');
    return openDatabase(path, version: 7, onCreate: (db, v) async {
      await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        userId TEXT,
        title TEXT,
        description TEXT,
        type TEXT,
        startTime TEXT,
        endTime TEXT,
        activeDateZone TEXT,
        selectedDays TEXT,
        priority TEXT,
        category TEXT,
        notificationMode TEXT DEFAULT 'ringtone',
        notificationSound TEXT DEFAULT 'alarm',
        maxSnoozeCount INTEGER,
        currentSnoozeCount INTEGER,
        snoozeIntervalMinutes INTEGER,
        status TEXT,
        reminderTime TEXT,
        completed INTEGER,
        createdAt TEXT,
        updatedAt TEXT,
        repeatEveryMinutes INTEGER,
        dayOfMonth INTEGER,
        lastDayOfMonth INTEGER,
        fullCount INTEGER DEFAULT 1,
        currentCount INTEGER DEFAULT 0,
        balanceCount INTEGER DEFAULT 1,
        vmStatus TEXT DEFAULT 'not yet started'
      )''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE reminders ADD COLUMN userId TEXT');
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE reminders ADD COLUMN startTime TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN endTime TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN activeDateZone TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN selectedDays TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN priority TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN category TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN notificationSound TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN maxSnoozeCount INTEGER');
        await db.execute('ALTER TABLE reminders ADD COLUMN currentSnoozeCount INTEGER');
        await db.execute('ALTER TABLE reminders ADD COLUMN snoozeIntervalMinutes INTEGER');
        await db.execute('ALTER TABLE reminders ADD COLUMN status TEXT');
        await db.execute('ALTER TABLE reminders ADD COLUMN updatedAt TEXT');
      }
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE reminders ADD COLUMN repeatEveryMinutes INTEGER DEFAULT 60');
        await db.execute('ALTER TABLE reminders ADD COLUMN dayOfMonth INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE reminders ADD COLUMN lastDayOfMonth INTEGER DEFAULT 0');
      }
      if (oldVersion < 5) {
        await db.execute('ALTER TABLE reminders ADD COLUMN fullCount INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE reminders ADD COLUMN currentCount INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE reminders ADD COLUMN balanceCount INTEGER DEFAULT 1');
      }
      if (oldVersion < 6) {
        await db.execute("ALTER TABLE reminders ADD COLUMN vmStatus TEXT DEFAULT 'not yet started'");
      }
      if (oldVersion < 7) {
        // New: notificationMode column
        await db.execute("ALTER TABLE reminders ADD COLUMN notificationMode TEXT DEFAULT 'ringtone'");
      }
    });
  }

  Future<void> upsertReminder(Reminder r) async {
    final database = await db;
    await database.insert('reminders', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Reminder>> getAllReminders({String? userId}) async {
    final database = await db;
    final rows = userId == null
        ? await database.query('reminders')
        : await database.query('reminders',
            where: 'userId = ?', whereArgs: [userId]);
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  Future<void> deleteReminder(String id) async {
    final database = await db;
    await database.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
}