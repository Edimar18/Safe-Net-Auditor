import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';

class SpectrumScreen extends StatelessWidget {
  const SpectrumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        return RetroScreen(
          title: 'SPECTRUM',
          children: [
            // ─── Channel Congestion Bar Chart ─────────────────────────────
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
                    children: List.generate(13, (i) {
                      return Text(
                        '${i + 1}',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white38,
                          fontSize: 8,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── Signal Strength RSSI ─────────────────────────────────────
            RetroPanel(
              title: 'SIGNAL STRENGTH (RSSI)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${net.rssi.toStringAsFixed(0)} dBm',
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF39FF14),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StatusBadge(
                        '[ ${net.signalQuality} ]',
                        color: const Color(0xFF39FF14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: _RssiWaterfallGraph(history: net.rssiHistory),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('1 MINUTE AGO', fontSize: 8, color: Colors.white30),
                      MonoText('REAL-TIME', fontSize: 8, color: Colors.white30),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── RSSI Legend ──────────────────────────────────────────────
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
  final Color color;
  const _RssiRow(this.dbm, this.desc, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: MonoText(dbm, fontSize: 9, color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: MonoText(desc, fontSize: 9, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _ChannelChart extends StatelessWidget {
  final List<int> data;
  const _ChannelChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce(max).toDouble().clamp(1.0, double.infinity);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 140),
          painter: _ChannelChartPainter(data: data, maxVal: maxVal),
        );
      },
    );
  }
}

class _ChannelChartPainter extends CustomPainter {
  final List<int> data;
  final double maxVal;
  _ChannelChartPainter({required this.data, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    final barW = (size.width - data.length * 2) / data.length;

    // Y-axis grid lines
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < data.length; i++) {
      final h = (data[i] / maxVal) * size.height;
      final x = i * (barW + 2);

      // Shadow / glow effect
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, barW, h),
        Paint()..color = Colors.white10,
      );

      // Main bar — highlight peak channel
      final isPeak = data[i] == data.reduce(max);
      canvas.drawRect(
        Rect.fromLTWH(x + 1, size.height - h + 1, barW - 2, h - 1),
        Paint()..color = isPeak ? Colors.white : Colors.white70,
      );
    }
  }

  @override
  bool shouldRepaint(_ChannelChartPainter old) => true;
}

class _RssiWaterfallGraph extends StatelessWidget {
  final List<double> history;
  const _RssiWaterfallGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 80),
          painter: _RssiPainter(history: history),
        );
      },
    );
  }
}

class _RssiPainter extends CustomPainter {
  final List<double> history;
  _RssiPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / history.length;
    // RSSI range: -90 to -30
    const minRssi = -90.0;
    const maxRssi = -30.0;
    const range = maxRssi - minRssi;

    final activePaint = Paint()..color = const Color(0xFF39FF14);
    final dimPaint = Paint()..color = Colors.white24;

    for (int i = 0; i < history.length; i++) {
      final rssi = history[i].clamp(minRssi, maxRssi);
      final normalized = (rssi - minRssi) / range;
      final h = normalized * size.height;
      final isActive = i >= history.length - 8;

      canvas.drawRect(
        Rect.fromLTWH(i * barW + 0.5, size.height - h, barW - 1, h),
        isActive ? activePaint : dimPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RssiPainter old) => true;
}
