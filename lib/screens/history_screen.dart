// lib/screens/history_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';
import '../widgets/connection_banner.dart';
import '../services/export_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        final criticalCount = net.incidentCalendar.where((v) => v >= 3).length;

        return RetroScreen(
          title: 'HISTORY',
          children: [
            const ConnectionBanner(),

            // ── Incident Heatmap Calendar ─────────────────────────────────
            RetroPanel(
              title: 'INCIDENT HISTORY (DB)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('PAST 90 DAYS', fontSize: 9, color: Colors.white54),
                      Row(
                        children: [
                          MonoText('CRITICAL EVENTS: ', fontSize: 9, color: Colors.white54),
                          MonoText('$criticalCount', fontSize: 9, color: const Color(0xFFFF0000), fontWeight: FontWeight.bold),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _HeatmapCalendar(data: net.incidentCalendar),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MonoText('LESS', fontSize: 8, color: Colors.white30),
                      const SizedBox(width: 4),
                      ...List.generate(5, (i) => Container(
                        width: 12, height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: Colors.white.withOpacity(0.1 + i * 0.18),
                      )),
                      const SizedBox(width: 4),
                      MonoText('MORE', fontSize: 8, color: Colors.white30),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Hourly Traffic Trends ─────────────────────────────────────
            RetroPanel(
              title: 'HOURLY TRENDS (DB AVG)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('NETWORK LOAD / 24H', fontSize: 9, color: Colors.white54),
                      MonoText(
                        _peakHour(net.hourlyTrend),
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: _HourlyLineGraph(data: net.hourlyTrend),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['00:00', '06:00', '12:00', '18:00', '24:00']
                        .map((t) => MonoText(t, fontSize: 8, color: Colors.white30))
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── DB Summary ────────────────────────────────────────────────
            RetroPanel(
              title: 'SQLITE DATABASE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DbStatCell('SNAPSHOTS', '${net.dbStats['snapshots'] ?? 0}'),
                      _DbStatCell('APS SEEN', '${net.dbStats['networks'] ?? 0}'),
                      _DbStatCell('INCIDENTS', '${net.dbStats['incidents'] ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MonoText(
                    '>> DATABASE: safenet_auditor.db\n'
                    '>> LOCATION: /data/data/<pkg>/databases/\n'
                    '>> AUTO-DUMP SCHEDULED FOR 23:59:00.',
                    fontSize: 8,
                    color: Colors.white30,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Export Tools ──────────────────────────────────────────────
            RetroPanel(
              title: 'EXPORT TOOLS',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _ExportButton(icon: Icons.table_chart_outlined, label: '[ DATA.CSV ]', onTap: () => _showExportDialog(context, 'CSV'))),
                      const SizedBox(width: 12),
                      Expanded(child: _ExportButton(icon: Icons.picture_as_pdf_outlined, label: '[ REPORT.PDF ]', onTap: () => _showExportDialog(context, 'PDF'))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _peakHour(List<double> trend) {
    if (trend.every((v) => v == 0)) return 'PEAK: --:--';
    double max = 0;
    int idx = 0;
    for (int i = 0; i < trend.length; i++) {
      if (trend[i] > max) { max = trend[i]; idx = i; }
    }
    return 'PEAK: ${idx.toString().padLeft(2, '0')}:00';
  }

  void _showExportDialog(BuildContext context, String format) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExportDialog(format: format),
    );
  }
}

class _DbStatCell extends StatelessWidget {
  final String label;
  final String value;
  const _DbStatCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonoText(value, fontSize: 22, fontWeight: FontWeight.bold),
        MonoText(label, fontSize: 7, color: Colors.white38),
      ],
    );
  }
}

class _ExportButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ExportButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed ? Colors.white : Colors.black,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(widget.icon, color: _pressed ? Colors.black : Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(widget.label, style: GoogleFonts.spaceMono(color: _pressed ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _HeatmapCalendar extends StatelessWidget {
  final List<int> data;
  const _HeatmapCalendar({required this.data});

  @override
  Widget build(BuildContext context) {
    final weeks = (data.length / 7).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(weeks, (w) {
        return Expanded(
          child: Column(
            children: List.generate(7, (d) {
              final idx = w * 7 + d;
              if (idx >= data.length) return const SizedBox(height: 10);
              final v = data[idx];
              Color c;
              if (v == 0)       c = Colors.white10;
              else if (v == 1)  c = Colors.white24;
              else if (v == 2)  c = Colors.white54;
              else if (v <= 4)  c = Colors.white;
              else              c = const Color(0xFFFF0000);
              return Container(margin: const EdgeInsets.all(1), width: double.infinity, height: 8, color: c);
            }),
          ),
        );
      }),
    );
  }
}

class _HourlyLineGraph extends StatelessWidget {
  final List<double> data;
  const _HourlyLineGraph({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => CustomPaint(
        size: Size(c.maxWidth, 100),
        painter: _LinePainter(data: data),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> data;
  _LinePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.every((v) => v == 0)) return;
    final maxV = data.reduce(max).clamp(1.0, double.infinity);
    final path = Path();
    final fill = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - (data[i] / maxV) * size.height * 0.9 - 4;
      if (i == 0) { path.moveTo(x, y); fill.moveTo(x, size.height); fill.lineTo(x, y); }
      else { path.lineTo(x, y); fill.lineTo(x, y); }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..color = Colors.white10);
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

class _ExportDialog extends StatefulWidget {
  final String format;
  const _ExportDialog({required this.format});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _loading = true;
  String _message = 'Generating...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _doExport();
  }

  Future<void> _doExport() async {
    try {
      if (widget.format == 'CSV') {
        final file = await ExportService.generateCsv();
        setState(() => _message = 'Sharing CSV...');
        await ExportService.shareFile(file);
      } else {
        final file = await ExportService.generatePdf();
        setState(() => _message = 'Sharing PDF...');
        await ExportService.shareFile(file);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoText('[ EXPORT ${widget.format} ]', fontSize: 13, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            if (_loading) ...[
              const SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(height: 10),
              MonoText(_message, fontSize: 10, color: Colors.white70, textAlign: TextAlign.center),
            ] else ...[
              MonoText('EXPORT FAILED', fontSize: 10, color: const Color(0xFFFF0000), fontWeight: FontWeight.bold),
              const SizedBox(height: 4),
              MonoText(_error ?? 'Unknown error', fontSize: 8, color: Colors.white54, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              RetroButton(label: '[ OK ]', onTap: () => Navigator.of(context).pop()),
            ],
          ],
        ),
      ),
    );
  }
}
