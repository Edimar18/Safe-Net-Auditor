import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';

class AuditorScreen extends StatelessWidget {
  const AuditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        final twins = net.evilTwinSuspects;

        return RetroScreen(
          title: 'AUDITOR',
          children: [
            // ─── Deauth Spike Graph ──────────────────────────────────────
            RetroPanel(
              title: 'DEAUTH SPIKES',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 90,
                    child: _DeauthGraph(history: net.deauthHistory),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('T-60s', fontSize: 8, color: Colors.white38),
                      if (net.deauths > 20)
                        MonoText('▲ ALERT TRIGGERED', fontSize: 8, color: const Color(0xFFFF0000)),
                      MonoText('NOW', fontSize: 8, color: Colors.white38),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── Evil Twin Scanner ────────────────────────────────────────
            RetroPanel(
              title: 'EVIL TWIN SCAN',
              child: Column(
                children: net.networks.map((n) {
                  final isTwin = twins.contains(n);
                  final isEspressif = n.ouiVendor.toUpperCase().contains('ESPRESSIF');
                  final flagged = isTwin && isEspressif;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: flagged ? const Color(0xFF1A0000) : Colors.black,
                      border: Border.all(
                        color: flagged ? const Color(0xFFFF0000) : Colors.white30,
                        width: flagged ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (flagged)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFFF0000), size: 14),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoText(
                                "SSID: '${n.ssid}'",
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: flagged ? const Color(0xFFFF4444) : Colors.white,
                              ),
                              MonoText(n.bssid, fontSize: 9, color: Colors.white54),
                            ],
                          ),
                        ),
                        StatusBadge(
                          flagged
                              ? '[ RED ALERT: PHISHING\n${n.ssid} RISK ]'
                              : '[ SECURE ]',
                          color: flagged ? const Color(0xFFFF0000) : const Color(0xFF39FF14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // ─── BSSID Fingerprint ────────────────────────────────────────
            RetroPanel(
              title: 'BSSID FINGERPRINT',
              child: Column(
                children: net.networks.map((n) {
                  final isRisky = n.ouiVendor.toUpperCase().contains('ESPRESSIF');
                  final trusted = net.isTrusted(n.bssid);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FingerprintRow('TARGET MAC:', n.bssid),
                        _FingerprintRow('CHANNEL:', '${n.channel} (2.4GHz)'),
                        _FingerprintRow('SIGNAL (RSSI):', '${n.rssi} dBm'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            MonoText('VENDOR OUI:', fontSize: 10, color: Colors.white54),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              color: isRisky ? const Color(0xFFFF0000) : Colors.white,
                              child: Text(
                                isRisky
                                    ? '${n.ouiVendor.toUpperCase()} ! (HI-RISK)'
                                    : n.ouiVendor.toUpperCase(),
                                style: GoogleFonts.spaceMono(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                if (trusted) {
                                  net.removeTrustedNetwork(n.bssid);
                                } else {
                                  net.addTrustedNetwork(n.bssid, n.ssid.isEmpty ? n.bssid : n.ssid);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: trusted ? const Color(0xFF39FF14) : Colors.black,
                                  border: Border.all(color: trusted ? const Color(0xFF39FF14) : Colors.white54, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      trusted ? Icons.shield : Icons.shield_outlined,
                                      color: trusted ? Colors.black : Colors.white54,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      trusted ? '[ TRUSTED ]' : '[ TRUST ]',
                                      style: GoogleFonts.spaceMono(
                                        color: trusted ? Colors.black : Colors.white54,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (n != net.networks.last) const RetroDivider(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FingerprintRow extends StatelessWidget {
  final String label;
  final String value;
  const _FingerprintRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: MonoText(label, fontSize: 10, color: Colors.white54),
          ),
          Expanded(child: MonoText(value, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DeauthGraph extends StatelessWidget {
  final List<double> history;
  const _DeauthGraph({required this.history});

  @override
  Widget build(BuildContext context) {
    final max = history.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 90),
          painter: _DeauthPainter(history: history, max: max),
        );
      },
    );
  }
}

class _DeauthPainter extends CustomPainter {
  final List<double> history;
  final double max;
  _DeauthPainter({required this.history, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / history.length;

    for (int i = 0; i < history.length; i++) {
      final v = history[i];
      final h = (v / max) * size.height;
      final isSpike = v > 20;

      final paint = Paint()
        ..color = isSpike ? const Color(0xFFFF0000) : Colors.white60;
      canvas.drawRect(
        Rect.fromLTWH(
          i * barW + 0.5,
          size.height - h,
          barW - 1,
          h,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DeauthPainter old) => true;
}
