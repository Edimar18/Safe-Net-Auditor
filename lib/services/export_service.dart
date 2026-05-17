// lib/services/export_service.dart
//
// CSV and PDF export generators.
// • CSV — raw snapshot telemetry table for Excel / expert analysis
// • PDF — comprehensive human-readable report with stats, trends, and tabular data
// ───────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';

class ExportService {
  static final DatabaseService _db = DatabaseService.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // CSV EXPORT — raw snapshot telemetry
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File> generateCsv() async {
    final snapshots = await _db.getAllSnapshots();

    final rows = <List<String>>[];

    // Header
    rows.add([
      'snapshot_id',
      'esp32_ts',
      'wall_time_utc',
      'wall_ms',
      'packets_per_sec',
      'deauths',
      'disassocs',
      'probe_reqs',
      'trust_score',
    ]);

    // Data
    for (final s in snapshots) {
      final wallMs = s['wall_ms'] as int? ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(wallMs).toUtc();
      rows.add([
        (s['id'] as int?)?.toString() ?? '',
        (s['ts'] as int?)?.toString() ?? '',
        dt.toIso8601String().replaceAll('T', ' ').substring(0, 19),
        wallMs.toString(),
        (s['packets_per_sec'] as int?)?.toString() ?? '0',
        (s['deauths'] as int?)?.toString() ?? '0',
        (s['disassocs'] as int?)?.toString() ?? '0',
        (s['probe_reqs'] as int?)?.toString() ?? '0',
        (s['trust_score'] as int?)?.toString() ?? '100',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/safenet_snapshots.csv');
    await file.writeAsString(csv);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT — comprehensive report
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File> generatePdf() async {
    final pdf = pw.Document();

    // Fetch all data in parallel
    final futures = await Future.wait([
      _db.getAllSnapshots(),
      _db.getAllNetworks(),
      _db.getAllIncidents(),
      _db.getTrustedNetworks(),
      _db.getSettings(),
      _db.getStats(),
      _db.getIncidentCalendar(),
      _db.getHourlyTrend(),
      _db.getTotalPackets(),
      _db.getAvgTrustScore(),
      _db.getTotalDeauths(),
      _db.getTopDeauthSnapshots(10),
    ]);

    final snapshots      = futures[0]  as List<Map<String, dynamic>>;
    final networks       = futures[1]  as List<Map<String, dynamic>>;
    final incidents      = futures[2]  as List<Map<String, dynamic>>;
    final trustedNets    = futures[3]  as List<Map<String, dynamic>>;
    final settings       = futures[4]  as Map<String, String>;
    final stats          = futures[5]  as Map<String, int>;
    final incidentCal    = futures[6]  as List<int>;
    final hourlyTrend    = futures[7]  as List<double>;
    final totalPackets   = futures[8]  as int;
    final avgTrustScore  = futures[9]  as double;
    final totalDeauths   = futures[10] as int;
    final topDeauths     = futures[11] as List<Map<String, dynamic>>;

    final now = DateTime.now().toUtc();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} UTC';

    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();

    // ── Page 1: Cover ──────────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.SizedBox(height: 80),
        pw.Center(child: pw.Text('SAFE-NET AUDITOR', style: pw.TextStyle(font: monoBold, fontSize: 26))),
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text('NETWORK SECURITY REPORT', style: pw.TextStyle(font: monoBold, fontSize: 16))),
        pw.SizedBox(height: 40),
        pw.Center(child: pw.Text('Generated: $dateStr', style: pw.TextStyle(font: mono, fontSize: 10))),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Snapshots in DB: ${stats['snapshots'] ?? 0}', style: pw.TextStyle(font: mono, fontSize: 10))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('APs Catalogued:   ${stats['networks'] ?? 0}', style: pw.TextStyle(font: mono, fontSize: 10))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Incidents Logged:  ${stats['incidents'] ?? 0}', style: pw.TextStyle(font: mono, fontSize: 10))),
      ],
    ));

    // ── Page: Session Summary ──────────────────────────────────────────────
    final firstSnap = snapshots.isNotEmpty ? snapshots.last : null;
    final lastSnap  = snapshots.isNotEmpty ? snapshots.first : null;
    final firstTime = firstSnap != null
        ? DateTime.fromMillisecondsSinceEpoch(firstSnap['wall_ms'] as int).toUtc().toIso8601String().replaceAll('T', ' ')
        : 'N/A';
    final lastTime  = lastSnap != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSnap['wall_ms'] as int).toUtc().toIso8601String().replaceAll('T', ' ')
        : 'N/A';
    final maxDeauths = snapshots.isNotEmpty
        ? snapshots.map((s) => s['deauths'] as int).reduce((a, b) => a > b ? a : b)
        : 0;
    final maxPps = snapshots.isNotEmpty
        ? snapshots.map((s) => s['packets_per_sec'] as int).reduce((a, b) => a > b ? a : b)
        : 0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        _pdfSection('SESSION SUMMARY'),
        _pdfKv('First Snapshot', firstTime.substring(0, 19)),
        _pdfKv('Last Snapshot', lastTime.substring(0, 19)),
        _pdfKv('Total Snapshots', '${snapshots.length}'),
        _pdfKv('Total Packets Captured', _fmtNum(totalPackets)),
        _pdfKv('Total Deauths', _fmtNum(totalDeauths)),
        _pdfKv('Max PPS (single sec)', _fmtNum(maxPps)),
        _pdfKv('Max Deauths (single sec)', _fmtNum(maxDeauths)),
        _pdfKv('Avg Trust Score', avgTrustScore.toStringAsFixed(1)),
        _pdfKv('APs Catalogued', '${networks.length}'),
        _pdfKv('Incidents Logged', '${incidents.length}'),
        _pdfKv('Trusted Networks', '${trustedNets.length}'),
        pw.SizedBox(height: 10),
        _pdfSection('CONFIGURATION'),
        _pdfKv('Deauth Threshold', settings['deauth_threshold'] ?? '50'),
        _pdfKv('Packet Threshold', settings['packet_threshold'] ?? '1024'),
        _pdfKv('Audit Logging', settings['audit_logging'] ?? 'true'),
      ],
    ));

    // ── Page: Incident Calendar ────────────────────────────────────────────
    final criticalDays = incidentCal.where((v) => v >= 3).length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        _pdfSection('INCIDENT HISTORY — PAST 90 DAYS'),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Critical days (>2 incidents): $criticalDays', style: pw.TextStyle(font: mono, fontSize: 9)),
            pw.Text('Total incidents: ${incidentCal.reduce((a, b) => a + b)}', style: pw.TextStyle(font: mono, fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 6),
        _heatmapPdf(incidentCal),
        pw.SizedBox(height: 6),
        _heatmapLegend(mono),
        pw.SizedBox(height: 16),
        _pdfSection('INCIDENT LOG — LAST 50'),
        _incidentTablePdf(incidents.take(50).toList(), mono, monoBold),
      ],
    ));

    // ── Page: Hourly Trends ────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        _pdfSection('HOURLY TRAFFIC TRENDS — PAST 24H'),
        pw.SizedBox(height: 4),
        _hourlyTablePdf(hourlyTrend, mono, monoBold),
        pw.SizedBox(height: 16),
        _pdfSection('KNOWN NETWORKS'),
        _networkTablePdf(networks, mono, monoBold),
      ],
    ));

    // ── Page: Top Deauth Events + Trusted ──────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        _pdfSection('TOP DEAUTH EVENTS'),
        _topDeauthTablePdf(topDeauths, mono, monoBold),
        if (trustedNets.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _pdfSection('TRUSTED NETWORKS'),
          _trustedTablePdf(trustedNets, mono, monoBold),
        ],
      ],
    ));

    // Save to temp file
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/safenet_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── PDF Widget Helpers ────────────────────────────────────────────────────

  static pw.Widget _pdfSection(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
      ),
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title, style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: 11)),
    );
  }

  static pw.Widget _pdfKv(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(key, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9)),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Text(value, style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  // ── Heatmap ───────────────────────────────────────────────────────────────

  static pw.Widget _heatmapPdf(List<int> data) {
    final weeks = (data.length / 7).ceil();
    final rows = <pw.TableRow>[];
    for (int d = 0; d < 7; d++) {
      final cells = <pw.Widget>[];
      for (int w = 0; w < weeks; w++) {
        final idx = w * 7 + d;
        if (idx >= data.length) {
          cells.add(pw.SizedBox(width: 8, height: 8));
        } else {
          final v = data[idx];
          final c = _heatColor(v);
          cells.add(pw.Container(
            width: 8, height: 8,
            color: c,
          ));
        }
      }
      rows.add(pw.TableRow(children: cells));
    }
    return pw.Table(
      columnWidths: {for (int i = 0; i < weeks; i++) i: const pw.FixedColumnWidth(8)},
      children: rows,
    );
  }

  static PdfColor _heatColor(int v) {
    if (v == 0)       return PdfColors.grey200;
    else if (v == 1)  return PdfColors.grey500;
    else if (v == 2)  return PdfColors.grey700;
    else if (v <= 4)  return PdfColors.black;
    else              return PdfColors.red;
  }

  static pw.Widget _heatmapLegend(pw.Font mono) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Text('LESS  ', style: pw.TextStyle(font: mono, fontSize: 7)),
        ...List.generate(5, (i) => pw.Container(
          width: 10, height: 10,
          color: PdfColors.grey200,
          margin: const pw.EdgeInsets.symmetric(horizontal: 1),
        )),
        pw.Container(width: 10, height: 10, color: PdfColors.red, margin: const pw.EdgeInsets.symmetric(horizontal: 1)),
        pw.Text('  MORE', style: pw.TextStyle(font: mono, fontSize: 7)),
      ],
    );
  }

  // ── Data Tables ───────────────────────────────────────────────────────────

  static pw.Widget _incidentTablePdf(List<Map<String, dynamic>> incidents, pw.Font mono, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(130),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FixedColumnWidth(120),
      },
      children: [
        _tableHeaderPdf(['TIME (UTC)', 'TYPE', 'DETAIL', 'BSSID'], mono, bold),
        ...incidents.map((inc) => pw.TableRow(
          children: [
            _cellPdf(_fmtWall(inc['wall_ms']), mono, 7),
            _cellPdf(inc['type']?.toString() ?? '', mono, 7),
            _cellPdf(inc['detail']?.toString() ?? '', mono, 7),
            _cellPdf(inc['bssid']?.toString() ?? '', mono, 7),
          ],
        )),
      ],
    );
  }

  static pw.Widget _hourlyTablePdf(List<double> trend, pw.Font mono, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(60),
        1: pw.FixedColumnWidth(100),
        2: pw.FixedColumnWidth(100),
      },
      children: [
        _tableHeaderPdf(['HOUR', 'AVG PPS', 'LOAD LEVEL'], mono, bold),
        ...List.generate(24, (i) {
          final v = trend[i];
          String level;
          if (v == 0) level = 'No Data';
          else if (v < 50) level = 'Low';
          else if (v < 200) level = 'Moderate';
          else if (v < 500) level = 'High';
          else level = 'Critical';
          return pw.TableRow(children: [
            _cellPdf('${i.toString().padLeft(2, '0')}:00', mono, 8),
            _cellPdf(v.toStringAsFixed(1), mono, 8),
            _cellPdf(level, mono, 8),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _networkTablePdf(List<Map<String, dynamic>> nets, pw.Font mono, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FixedColumnWidth(115),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(130),
      },
      children: [
        _tableHeaderPdf(['SSID', 'BSSID', 'RSSI', 'VENDOR', 'LAST SEEN'], mono, bold),
        ...nets.map((n) => pw.TableRow(children: [
          _cellPdf(n['ssid']?.toString() ?? '', mono, 7),
          _cellPdf(n['bssid']?.toString() ?? '', mono, 7),
          _cellPdf('${n['last_seen'] ?? '?'}', mono, 7),
          _cellPdf(n['oui_vendor']?.toString() ?? '', mono, 7),
          _cellPdf(_fmtWall(n['last_seen']), mono, 7),
        ])),
      ],
    );
  }

  static pw.Widget _topDeauthTablePdf(List<Map<String, dynamic>> rows, pw.Font mono, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(130),
        1: pw.FixedColumnWidth(80),
        2: pw.FixedColumnWidth(100),
        3: pw.FixedColumnWidth(80),
      },
      children: [
        _tableHeaderPdf(['TIME (UTC)', 'DEAUTHS', 'PACKETS/SEC', 'TRUST'], mono, bold),
        ...rows.map((r) {
          final trust = r['trust_score'] as int? ?? 100;
          return pw.TableRow(children: [
            _cellPdf(_fmtWall(r['wall_ms']), mono, 7),
            _cellPdfRed(r['deauths'] as int? ?? 0, mono, 7),
            _cellPdf(_fmtNum(r['packets_per_sec'] as int? ?? 0), mono, 7),
            _cellPdf(trust.toString(), mono, 7, red: trust < 40),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _trustedTablePdf(List<Map<String, dynamic>> rows, pw.Font mono, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(115),
        1: pw.FlexColumnWidth(1),
        2: pw.FixedColumnWidth(130),
      },
      children: [
        _tableHeaderPdf(['MAC', 'LABEL', 'ADDED'], mono, bold),
        ...rows.map((r) => pw.TableRow(children: [
          _cellPdf(r['mac']?.toString() ?? '', mono, 7),
          _cellPdf(r['label']?.toString() ?? '', mono, 7),
          _cellPdf(_fmtWall(r['created_at']), mono, 7),
        ])),
      ],
    );
  }

  static pw.TableRow _tableHeaderPdf(List<String> headers, pw.Font font, pw.Font bold) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: headers.map((h) => pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 7)),
      )).toList(),
    );
  }

  static pw.Widget _cellPdf(String text, pw.Font font, double size, {bool red = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: pw.TextStyle(
        font: font,
        fontSize: size,
        color: red ? PdfColors.red : PdfColors.black,
      )),
    );
  }

  static pw.Widget _cellPdfRed(int value, pw.Font font, double size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(value.toString(), style: pw.TextStyle(
        font: font,
        fontSize: size,
        color: value > 0 ? PdfColors.red : PdfColors.black,
        fontWeight: value > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
      )),
    );
  }

  static String _fmtWall(dynamic ms) {
    if (ms == null) return '';
    final t = ms is int ? ms : int.tryParse(ms.toString()) ?? 0;
    if (t == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(t).toUtc();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Share / Print ─────────────────────────────────────────────────────────

  static Future<void> shareFile(File file) async {
    await Printing.sharePdf(
      bytes:   await file.readAsBytes(),
      filename: file.path.split('/').last,
    );
  }
}
