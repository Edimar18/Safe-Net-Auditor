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
                  if (net.selectedNetwork != null) ...[
                    const SizedBox(height: 4),
                    MonoText(
                      'BSSID: ${net.selectedNetwork!.bssid}   CH: ${net.selectedNetwork!.channel}   OUI: ${net.selectedNetwork!.ouiVendor}',
                      fontSize: 8,
                      color: Colors.white38,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: _RssiWaterfallGraph(history: net.activeRssiHistory),
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

// ── RSSI Waterfall ────────────────────────────────────────────────────────────
class _RssiWaterfallGraph extends StatelessWidget {
  final List<double> history;
  const _RssiWaterfallGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => CustomPaint(
        size: Size(c.maxWidth, 80),
        painter: _RssiPainter(history: history),
      ),
    );
  }
}

class _RssiPainter extends CustomPainter {
  final List<double> history;
  _RssiPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final barW = size.width / history.length;
    for (int i = 0; i < history.length; i++) {
      final rssi       = history[i].clamp(-90.0, -30.0);
      final normalized = (rssi + 90) / 60;
      final h          = normalized * size.height;
      final isActive   = i >= history.length - 8;
      canvas.drawRect(
        Rect.fromLTWH(i * barW + 0.5, size.height - h, barW - 1, h),
        Paint()..color = isActive ? const Color(0xFF39FF14) : Colors.white24,
      );
    }
  }

  @override
  bool shouldRepaint(_RssiPainter old) => true;
}
