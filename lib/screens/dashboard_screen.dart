import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';
import '../widgets/trust_gauge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        final isAttack = net.threatLevel == ThreatLevel.attack;
        final isCongestion = net.threatLevel == ThreatLevel.congestion;

        return Container(
          color: Colors.black,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Threat Banner ─────────────────────────────────────────
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

                // ─── Trust Score ───────────────────────────────────────────
                RetroPanel(
                  title: 'TRUST SCORE',
                  child: TrustScoreGauge(score: net.trustScore),
                ),

                const SizedBox(height: 10),

                // ─── Packet Count ──────────────────────────────────────────
                RetroPanel(
                  title: 'PACKET COUNT',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MonoText('RATE: ${(net.packetsPerSec / 1000).toStringAsFixed(1)}K/S', fontSize: 10),
                          MonoText('PEAK: 1.5K/S', fontSize: 10, color: Colors.white54),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _PacketBarGraph(history: net.packetHistory),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ─── Quick Stats ───────────────────────────────────────────
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: RetroPanel(
                        title: 'NETWORKS',
                        child: MonoText(
                          '${net.networks.length}',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RetroPanel(
                        title: 'RSSI',
                        borderColor: const Color(0xFF39FF14),
                        child: MonoText(
                          '${net.rssi.toStringAsFixed(0)}',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF39FF14),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── ASCII Decoration ──────────────────────────────────────
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

class _PacketBarGraph extends StatelessWidget {
  final List<double> history;
  const _PacketBarGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    final max = history.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: history.map((v) {
          final h = (v / max) * 68;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: Container(
                height: h.clamp(1.0, 68.0),
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
