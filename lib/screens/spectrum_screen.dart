// lib/screens/spectrum_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';
import '../widgets/ap_selector.dart';
import '../widgets/connection_banner.dart';

class SpectrumScreen extends StatelessWidget {
  const SpectrumScreen({super.key});

  Color _rssiColor(double rssi) {
    if (rssi > -55) return const Color(0xFF39FF14);
    if (rssi > -70) return Colors.white;
    return const Color(0xFFFF0000);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        return RetroScreen(
          title: 'SPECTRUM',
          children: [
            const ConnectionBanner(),

            // ── AP Selector ───────────────────────────────────────────────
            RetroPanel(
              title: 'MONITOR TARGET AP',
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText(
                    net.selectedBssid == null
                        ? '>> RSSI: STRONGEST VISIBLE AP'
                        : '>> RSSI LOCKED TO: ${net.selectedNetwork?.ssid ?? net.selectedBssid}',
                    fontSize: 9,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 6),
                  const ApSelector(compact: true),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Channel Congestion Bar Chart ───────────────────────────────
            RetroPanel(
              title: 'CHANNEL CONGESTION',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 140,
                    child: _ChannelChart(data: net.channelCongestion),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(13, (i) => Text(
                      '${i + 1}',
                      style: GoogleFonts.spaceMono(
                        color: Colors.white38,
                        fontSize: 8,
                      ),
                    )),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Signal Strength (RSSI) ────────────────────────────────────
            RetroPanel(
              title: net.selectedBssid == null
                  ? 'SIGNAL STRENGTH (RSSI) — STRONGEST AP'
                  : 'SIGNAL STRENGTH — ${(net.selectedNetwork?.ssid ?? net.selectedBssid)!.toUpperCase()}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${net.rssi.toStringAsFixed(0)}',
                            style: GoogleFonts.spaceMono(
                              color: _rssiColor(net.rssi),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'dBm',
                            style: GoogleFonts.spaceMono(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      StatusBadge(
                        '[ ${net.signalQuality} ]',
                        color: _rssiColor(net.rssi),
                      ),
                    ],
                  ),
                  if (net.selectedNetwork != null) ...[
                    const SizedBox(height: 4),
                    MonoText(
                      'BSSID: ${net.selectedNetwork!.bssid}   CH: ${net.selectedNetwork!.channel}   OUI: ${net.selectedNetwork!.ouiVendor}',
                      fontSize: 8,
                      color: Colors.white38,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: _RssiLineGraph(history: net.activeRssiHistory),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('60s AGO', fontSize: 8, color: Colors.white30),
                      MonoText('NOW', fontSize: 8, color: Colors.white30),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Live Network Table ────────────────────────────────────────
            RetroPanel(
              title: 'VISIBLE NETWORKS (${net.networks.length})',
              padding: const EdgeInsets.all(0),
              child: Column(
                children: net.networks.isEmpty
                    ? [Padding(
                        padding: const EdgeInsets.all(12),
                        child: MonoText('>> NO NETWORKS DETECTED', fontSize: 10, color: Colors.white30),
                      )]
                    : net.networks.map((n) {
                        final isSelected = net.selectedBssid == n.bssid;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white10 : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: Colors.white12, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MonoText(
                                      n.ssid.isEmpty ? '<HIDDEN>' : n.ssid,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF39FF14) : Colors.white,
                                    ),
                                    MonoText(
                                      '${n.bssid}  CH${n.channel}  ${n.ouiVendor}',
                                      fontSize: 8,
                                      color: Colors.white38,
                                    ),
                                  ],
                                ),
                              ),
                              MonoText(
                                '${n.rssi} dBm',
                                fontSize: 10,
                                color: n.rssi > -60
                                    ? const Color(0xFF39FF14)
                                    : n.rssi > -75
                                        ? Colors.white
                                        : const Color(0xFFFF4444),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // ── RSSI Reference ────────────────────────────────────────────
            RetroPanel(
              title: 'RSSI REFERENCE',
              child: Column(
                children: const [
                  _RssiRow('-30 dBm', 'EXCELLENT — RIGHT NEXT TO AP', Color(0xFF39FF14)),
                  _RssiRow('-50 dBm', 'GOOD — RELIABLE CONNECTION', Colors.white),
                  _RssiRow('-67 dBm', 'FAIR — MINIMUM FOR VOIP', Colors.white60),
                  _RssiRow('-80 dBm', 'POOR — BASIC CONNECTIVITY', Colors.white38),
                  _RssiRow('-90 dBm', 'DEAD ZONE — UNUSABLE', Color(0xFFFF0000)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RssiRow extends StatelessWidget {
  final String dbm;
  final String desc;
  final Color  color;
  const _RssiRow(this.dbm, this.desc, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 60, child: MonoText(dbm, fontSize: 9, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: MonoText(desc, fontSize: 9, color: Colors.white54)),
        ],
      ),
    );
  }
}

// ── Channel Chart ─────────────────────────────────────────────────────────────
class _ChannelChart extends StatelessWidget {
  final List<int> data;
  const _ChannelChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce(max).toDouble().clamp(1.0, double.infinity);
    return LayoutBuilder(
      builder: (ctx, c) => CustomPaint(
        size: Size(c.maxWidth, 140),
        painter: _ChannelPainter(data: data, maxVal: maxVal),
      ),
    );
  }
}

class _ChannelPainter extends CustomPainter {
  final List<int> data;
  final double    maxVal;
  _ChannelPainter({required this.data, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barW = (size.width - data.length * 2) / data.length;
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final peak = data.reduce(max);
    for (int i = 0; i < data.length; i++) {
      final h = (data[i] / maxVal) * size.height;
      final x = i * (barW + 2);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, barW, h),
        Paint()..color = data[i] == peak ? Colors.white : Colors.white60,
      );
    }
  }

  @override
  bool shouldRepaint(_ChannelPainter old) => true;
}

// ── RSSI Line Graph ──────────────────────────────────────────────────────────
class _RssiLineGraph extends StatelessWidget {
  final List<double> history;
  const _RssiLineGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => CustomPaint(
        size: Size(c.maxWidth, 100),
        painter: _RssiLinePainter(history: history),
      ),
    );
  }
}

class _RssiLinePainter extends CustomPainter {
  final List<double> history;
  _RssiLinePainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final values = history.where((v) => v != -70 || history.indexOf(v) == 0).toList();
    if (values.isEmpty) return;

    // Reference lines at -30, -50, -70, -90 dBm
    final refPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    final refs = [-30, -50, -70, -90];
    for (final ref in refs) {
      final normalized = (-ref - 30) / 60; // invert: -30→0, -90→1
      final y = normalized * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), refPaint);
    }

    // Reference labels
    for (final ref in refs) {
      final normalized = (-ref - 30) / 60;
      final y = normalized * size.height;
      final tp = TextPainter(
        text: TextSpan(
          text: '$ref',
          style: GoogleFonts.spaceMono(color: Colors.white30, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // Build path
    final path = Path();
    final barW = size.width / values.length;

    for (int i = 0; i < values.length; i++) {
      final rssi = values[i].clamp(-90.0, -30.0);
      final normalized = (-rssi - 30) / 60; // -30→0, -90→1
      final x = i * barW + barW / 2;
      final y = normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw fill
    final lastX = (values.length - 1) * barW + barW / 2;
    final fillPath = Path.from(path);
    fillPath.lineTo(lastX, size.height);
    fillPath.lineTo(barW / 2, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = const Color(0xFF39FF14).withOpacity(0.08));

    // Draw line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF39FF14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Draw last point dot
    if (values.isNotEmpty) {
      final lastRssi = values.last.clamp(-90.0, -30.0);
      final lastNorm = (-lastRssi - 30) / 60;
      final lastPointY = lastNorm * size.height;
      canvas.drawCircle(
        Offset(lastX, lastPointY),
        3,
        Paint()..color = const Color(0xFF39FF14),
      );
    }
  }

  @override
  bool shouldRepaint(_RssiLinePainter old) => true;
}