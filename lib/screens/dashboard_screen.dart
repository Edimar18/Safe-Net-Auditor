// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';
import '../widgets/trust_gauge.dart';
import '../widgets/ap_selector.dart';
import '../widgets/connection_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        final isAttack    = net.threatLevel == ThreatLevel.attack;
        final isCongestion = net.threatLevel == ThreatLevel.congestion;

        return Container(
          color: Colors.black,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Connection status ─────────────────────────────────────
                const ConnectionBanner(),

                // ── Threat Banner ─────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isAttack
                        ? const Color(0xFFFF0000)
                        : isCongestion
                            ? const Color(0xFF1A1A00)
                            : Colors.black,
                    border: Border.all(
                      color: isAttack
                          ? const Color(0xFFFF0000)
                          : isCongestion
                              ? const Color(0xFFFFFF00)
                              : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    net.threatText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(
                      color: isAttack ? Colors.black : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Trust Score ───────────────────────────────────────────
                RetroPanel(
                  title: 'TRUST SCORE',
                  child: TrustScoreGauge(score: net.trustScore),
                ),

                const SizedBox(height: 10),

                // ── AP Selector ───────────────────────────────────────────
                RetroPanel(
                  title: 'MONITOR TARGET AP',
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText(
                        net.selectedBssid == null
                            ? '>> SHOWING: GLOBAL MGMT FRAME RATE'
                            : '>> SHOWING: MGMT FRAMES FOR ${net.selectedNetwork?.ssid ?? net.selectedBssid}',
                        fontSize: 9,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 6),
                      const ApSelector(compact: true),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Packet Count ──────────────────────────────────────────
                RetroPanel(
                  title: net.selectedBssid == null
                      ? 'MGMT FRAMES — ALL NETWORKS'
                      : 'MGMT FRAMES — ${(net.selectedNetwork?.ssid ?? net.selectedBssid)!.toUpperCase()}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${net.packetsPerSec}',
                            style: GoogleFonts.spaceMono(
                              color: net.packetsPerSec > 0 ? Colors.white : Colors.white30,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'FRAMES/S',
                            style: GoogleFonts.spaceMono(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MonoText(
                                net.isConnected ? 'LIVE' : 'NO DATA',
                                fontSize: 9,
                                color: net.isConnected ? const Color(0xFF39FF14) : Colors.white30,
                              ),
                              MonoText(
                                'LIMIT: ${net.packetThreshold}/S',
                                fontSize: 8,
                                color: Colors.white30,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PacketBarGraph(history: net.activePacketHistory),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Quick Stats ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: RetroPanel(
                        title: 'DEAUTHS',
                        borderColor: net.deauths > 10
                            ? const Color(0xFFFF0000)
                            : Colors.white,
                        child: MonoText(
                          '${net.deauths}',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: net.deauths > 10
                              ? const Color(0xFFFF0000)
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RetroPanel(
                        title: 'APS',
                        child: MonoText(
                          '${net.networks.length}',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RetroPanel(
                        title: 'RSSI',
                        borderColor: _rssiColor(net.rssi),
                        child: MonoText(
                          '${net.rssi.toStringAsFixed(0)}',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _rssiColor(net.rssi),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── DB Stats ──────────────────────────────────────────────
                if (net.dbStats.isNotEmpty)
                  RetroPanel(
                    title: 'DATABASE',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCell('SNAPSHOTS', '${net.dbStats['snapshots'] ?? 0}'),
                        _StatCell('APS SEEN', '${net.dbStats['networks'] ?? 0}'),
                        _StatCell('INCIDENTS', '${net.dbStats['incidents'] ?? 0}'),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // ── ASCII Decoration ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: MonoText(
                    '01001110 01000101 01010100\n'
                    '>> MONITORING 2.4GHz BAND\n'
                    '>> MGMT FRAME SNIFFER: ACTIVE\n'
                    '>> CHANNEL HOP: 1-13 @ 60ms\n'
                    '01010111 01001001 01000110 01001001',
                    fontSize: 8,
                    color: Colors.white24,
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

Color _rssiColor(double rssi) {
  if (rssi > -50) return const Color(0xFF39FF14);   // EXCELLENT - green
  if (rssi > -60) return const Color(0xFFBFFF00);   // GOOD - lime
  if (rssi > -70) return const Color(0xFFFFFF00);   // FAIR - yellow
  if (rssi > -80) return const Color(0xFFFF8800);   // POOR - orange
  return const Color(0xFFFF0000);                     // DEAD - red
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonoText(value, fontSize: 18, fontWeight: FontWeight.bold),
        MonoText(label, fontSize: 7, color: Colors.white38),
      ],
    );
  }
}

class _PacketBarGraph extends StatelessWidget {
  final List<double> history;
  const _PacketBarGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    final values = history.isEmpty ? List.filled(40, 0.0) : history;
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    final hasData = maxVal > 0;

    return SizedBox(
      height: 70,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values.map((v) {
                final h = maxVal > 0 ? (v / maxVal) * 64 : 2.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Container(
                      height: h.clamp(2.0, 64.0),
                      color: v > 0 ? Colors.white : Colors.white10,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: MonoText(
                '>> WAITING FOR ESP32 DATA...',
                fontSize: 8,
                color: Colors.white24,
              ),
            ),
        ],
      ),
    );
  }
}
