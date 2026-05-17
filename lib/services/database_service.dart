// lib/services/database_service.dart
//
// SQLite schema for Safe-Net Auditor
// ───────────────────────────────────────────────────────────────────────────────
// Tables
//   snapshots        – one row per 1-second JSON payload from the ESP32
//   networks         – deduplicated AP catalogue (ssid + bssid)
//   rssi_history     – RSSI readings tied to a specific (bssid, snapshot)
//   channel_history  – per-channel packet counts per snapshot
//   incidents        – deauth spikes & evil-twin flags
// ───────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  // ── Open / create ──────────────────────────────────────────────────────────
  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'safenet_auditor.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trusted_networks (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        mac        TEXT    NOT NULL UNIQUE,
        label      TEXT    NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO settings (key, value) VALUES ('deauth_threshold', '50')
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO settings (key, value) VALUES ('packet_threshold', '1024')
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO settings (key, value) VALUES ('audit_logging', 'true')
    ''');
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE snapshots (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        ts              INTEGER NOT NULL,   -- ESP32 millis/1000
        wall_ms         INTEGER NOT NULL,   -- phone epoch ms
        packets_per_sec INTEGER DEFAULT 0,
        deauths         INTEGER DEFAULT 0,
        disassocs       INTEGER DEFAULT 0,
        probe_reqs      INTEGER DEFAULT 0,
        trust_score     INTEGER DEFAULT 100
      )
    ''');

    await db.execute('''
      CREATE TABLE networks (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        ssid       TEXT    NOT NULL,
        bssid      TEXT    NOT NULL UNIQUE,
        oui_vendor TEXT    DEFAULT 'Unknown',
        first_seen INTEGER NOT NULL,
        last_seen  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rssi_history (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_id INTEGER NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
        bssid       TEXT    NOT NULL,
        rssi        INTEGER NOT NULL,
        channel     INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE channel_history (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_id INTEGER NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
        channel     INTEGER NOT NULL,   -- 1-13
        pkt_count   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE incidents (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        wall_ms     INTEGER NOT NULL,
        type        TEXT    NOT NULL,   -- 'DEAUTH_SPIKE' | 'EVIL_TWIN'
        detail      TEXT    DEFAULT '',
        bssid       TEXT    DEFAULT ''
      )
    ''');

    // Indexes for fast queries
    await db.execute('CREATE INDEX idx_snap_wall ON snapshots(wall_ms)');
    await db.execute('CREATE INDEX idx_rssi_bssid ON rssi_history(bssid)');
    await db.execute('CREATE INDEX idx_inc_wall  ON incidents(wall_ms)');

    // V2 tables (created for fresh installs too)
    await _createV2Tables(db);
  }

  // ── Trusted Networks CRUD ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTrustedNetworks() async {
    final d = await db;
    return d.query('trusted_networks', orderBy: 'created_at ASC');
  }

  Future<void> addTrustedNetwork(String mac, String label) async {
    final d = await db;
    await d.insert('trusted_networks', {
      'mac'       : mac.toUpperCase(),
      'label'     : label,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeTrustedNetwork(String mac) async {
    final d = await db;
    await d.delete('trusted_networks', where: 'mac = ?', whereArgs: [mac.toUpperCase()]);
  }

  // ── Settings CRUD ──────────────────────────────────────────────────────
  Future<Map<String, String>> getSettings() async {
    final d = await db;
    final rows = await d.query('settings');
    final map = <String, String>{};
    for (final r in rows) {
      map[r['key'] as String] = r['value'] as String;
    }
    return map;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.rawInsert('''
      INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)
    ''', [key, value]);
  }

  // ── Insert a full ESP32 snapshot ──────────────────────────────────────────
  Future<void> insertSnapshot({
    required int esp32Ts,
    required int packetsPerSec,
    required int deauths,
    required int disassocs,
    required int probeReqs,
    required int trustScore,
    required List<int> channelCongestion,   // 13 elements
    required List<Map<String, dynamic>> networks,
  }) async {
    final d = await db;
    final wallMs = DateTime.now().millisecondsSinceEpoch;

    await d.transaction((txn) async {
      // 1 – snapshots row
      final snapId = await txn.insert('snapshots', {
        'ts'             : esp32Ts,
        'wall_ms'        : wallMs,
        'packets_per_sec': packetsPerSec,
        'deauths'        : deauths,
        'disassocs'      : disassocs,
        'probe_reqs'     : probeReqs,
        'trust_score'    : trustScore,
      });

      // 2 – channel_history (13 rows)
      for (int ch = 0; ch < channelCongestion.length && ch < 13; ch++) {
        await txn.insert('channel_history', {
          'snapshot_id': snapId,
          'channel'    : ch + 1,
          'pkt_count'  : channelCongestion[ch],
        });
      }

      // 3 – networks + rssi_history
      for (final net in networks) {
        final ssid      = net['ssid']       as String? ?? '';
        final bssid     = net['bssid']      as String? ?? '';
        final rssi      = net['rssi']       as int?    ?? -99;
        final channel   = net['channel']    as int?    ?? 0;
        final vendor    = net['oui_vendor'] as String? ?? 'Unknown';

        // Upsert network catalogue
        await txn.rawInsert('''
          INSERT INTO networks (ssid, bssid, oui_vendor, first_seen, last_seen)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(bssid) DO UPDATE
            SET ssid      = excluded.ssid,
                oui_vendor= excluded.oui_vendor,
                last_seen = excluded.last_seen
        ''', [ssid, bssid, vendor, wallMs, wallMs]);

        // RSSI reading
        await txn.insert('rssi_history', {
          'snapshot_id': snapId,
          'bssid'      : bssid,
          'rssi'       : rssi,
          'channel'    : channel,
        });
      }

      // 4 – auto-log deauth spike incident
      if (deauths > 20) {
        await txn.insert('incidents', {
          'wall_ms': wallMs,
          'type'   : 'DEAUTH_SPIKE',
          'detail' : 'Deauth count: $deauths in 1s',
        });
      }
    });
  }

  // ── Log an evil-twin incident ─────────────────────────────────────────────
  Future<void> logEvilTwin(String ssid, String bssid1, String bssid2) async {
    final d = await db;
    await d.insert('incidents', {
      'wall_ms': DateTime.now().millisecondsSinceEpoch,
      'type'   : 'EVIL_TWIN',
      'detail' : 'SSID: $ssid  BSSID-A: $bssid1  BSSID-B: $bssid2',
      'bssid'  : bssid1,
    });
  }

  // ── RSSI history for a specific BSSID (last N points) ────────────────────
  Future<List<int>> getRssiHistory(String bssid, {int limit = 60}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT r.rssi
      FROM   rssi_history r
      JOIN   snapshots s ON s.id = r.snapshot_id
      WHERE  r.bssid = ?
      ORDER  BY s.wall_ms DESC
      LIMIT  ?
    ''', [bssid, limit]);
    final vals = rows.map((r) => r['rssi'] as int).toList().reversed.toList();
    return vals;
  }

  // ── Packet-per-sec history for a specific BSSID (last N points) ──────────
  // We proxy this: filter snapshots that saw the BSSID & return packets_per_sec
  Future<List<int>> getPacketHistory(String bssid, {int limit = 40}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT s.packets_per_sec
      FROM   snapshots    s
      JOIN   rssi_history r ON r.snapshot_id = s.id
      WHERE  r.bssid = ?
      ORDER  BY s.wall_ms DESC
      LIMIT  ?
    ''', [bssid, limit]);
    final vals = rows.map((r) => r['packets_per_sec'] as int).toList().reversed.toList();
    return vals;
  }

  // ── Incident calendar: incidents per day for past N days ─────────────────
  Future<List<int>> getIncidentCalendar({int days = 90}) async {
    final d    = await db;
    final now  = DateTime.now();
    final List<int> result = [];

    for (int i = days - 1; i >= 0; i--) {
      final day   = now.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end   = start + 86400000;
      final row   = await d.rawQuery(
        'SELECT COUNT(*) as c FROM incidents WHERE wall_ms >= ? AND wall_ms < ?',
        [start, end],
      );
      result.add((row.first['c'] as int?) ?? 0);
    }
    return result;
  }

  // ── Hourly trend: average packets_per_sec per hour for past 24h ──────────
  Future<List<double>> getHourlyTrend() async {
    final d   = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final yesterday = now - 86400000;

    final rows = await d.rawQuery('''
      SELECT
        CAST((wall_ms - ?) / 3600000 AS INTEGER) AS hour_bucket,
        AVG(packets_per_sec) AS avg_pps
      FROM snapshots
      WHERE wall_ms >= ?
      GROUP BY hour_bucket
      ORDER BY hour_bucket ASC
    ''', [yesterday, yesterday]);

    final List<double> trend = List.filled(24, 0.0);
    for (final r in rows) {
      final bucket = (r['hour_bucket'] as int?) ?? 0;
      if (bucket >= 0 && bucket < 24) {
        trend[bucket] = (r['avg_pps'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return trend;
  }

  // ── All-time known networks (for AP selector) ─────────────────────────────
  Future<List<Map<String, dynamic>>> getKnownNetworks() async {
    final d = await db;
    return d.query(
      'networks',
      orderBy: 'last_seen DESC',
    );
  }

  // ── Purge data older than N days ──────────────────────────────────────────
  Future<void> purgeOlderThan({int days = 30}) async {
    final d         = await db;
    final cutoff    = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    await d.delete('snapshots', where: 'wall_ms < ?', whereArgs: [cutoff]);
    await d.delete('incidents', where: 'wall_ms < ?', whereArgs: [cutoff]);
  }

  // ── Row counts (for Settings info panel) ─────────────────────────────────
  Future<Map<String, int>> getStats() async {
    final d = await db;
    Future<int> count(String table) async {
      final r = await d.rawQuery('SELECT COUNT(*) as c FROM $table');
      return (r.first['c'] as int?) ?? 0;
    }
    return {
      'snapshots' : await count('snapshots'),
      'networks'  : await count('networks'),
      'incidents' : await count('incidents'),
    };
  }

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('rssi_history');
    await d.delete('channel_history');
    await d.delete('snapshots');
    await d.delete('incidents');
  }

  // ── Bulk export queries ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllSnapshots({int? limit}) async {
    final d = await db;
    return d.query('snapshots',
      orderBy: 'wall_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getAllNetworks() async {
    final d = await db;
    return d.query('networks', orderBy: 'last_seen DESC');
  }

  Future<List<Map<String, dynamic>>> getAllIncidents({int? limit}) async {
    final d = await db;
    return d.query('incidents',
      orderBy: 'wall_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getAllRssiHistory({int? limit}) async {
    final d = await db;
    return d.rawQuery('''
      SELECT r.id, r.snapshot_id, r.bssid, r.rssi, r.channel, s.wall_ms
      FROM rssi_history r
      JOIN snapshots s ON s.id = r.snapshot_id
      ORDER BY s.wall_ms DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''');
  }

  Future<List<Map<String, dynamic>>> getAllChannelHistory({int? limit}) async {
    final d = await db;
    return d.rawQuery('''
      SELECT c.id, c.snapshot_id, c.channel, c.pkt_count, s.wall_ms
      FROM channel_history c
      JOIN snapshots s ON s.id = c.snapshot_id
      ORDER BY s.wall_ms DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''');
  }

  Future<List<Map<String, dynamic>>> getTopDeauthSnapshots(int limit) async {
    final d = await db;
    return d.query('snapshots',
      where: 'deauths > 0',
      orderBy: 'deauths DESC',
      limit: limit,
    );
  }

  Future<int> getTotalPackets() async {
    final d = await db;
    final r = await d.rawQuery('SELECT SUM(packets_per_sec) as total FROM snapshots');
    return (r.first['total'] as int?) ?? 0;
  }

  Future<double> getAvgTrustScore() async {
    final d = await db;
    final r = await d.rawQuery('SELECT AVG(trust_score) as avg FROM snapshots');
    return (r.first['avg'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTotalDeauths() async {
    final d = await db;
    final r = await d.rawQuery('SELECT SUM(deauths) as total FROM snapshots');
    return (r.first['total'] as int?) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
