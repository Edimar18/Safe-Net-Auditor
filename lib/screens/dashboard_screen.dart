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
                            ? '>> SHOWING: GLOBAL PACKET RATE'
                            : '>> SHOWING: PACKETS FOR ${net.selectedNetwork?.ssid ?? net.selectedBssid}',
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
                      ? 'PACKET COUNT — ALL NETWORKS'
                      : 'PACKET COUNT — ${(net.selectedNetwork?.ssid ?? net.selectedBssid)!.toUpperCase()}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MonoText(
                            'RATE: ${net.packetsPerSec}/S',
                            fontSize: 10,
                          ),
                          MonoText(
                            'PKT LIMIT: ${net.packetThreshold}/S',
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                        borderColor: const Color(0xFF39FF14),
                        child: MonoText(
                          net.rssi.toStringAsFixed(0),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF39FF14),
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
                    '>> PROMISCUOUS MODE: ACTIVE\n'
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
    final maxVal = history.isEmpty ? 1.0 : history.fold(0.0, (a, b) => a > b ? a : b);
    final hasData = maxVal > 0;

    return SizedBox(
      height: 70,
      child: hasData
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.map((v) {
                final h = maxVal > 0 ? (v / maxVal) * 68 : 1.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Container(
                      height: h.clamp(2.0, 68.0),
                      color: v > 0 ? Colors.white : Colors.white10,
                    ),
                  ),
                );
              }).toList(),
            )
          : Center(
              child: MonoText(
                '>> WAITING FOR ESP32 DATA...',
                fontSize: 10,
                color: Colors.white24,
              ),
            ),
    );
  }
}
