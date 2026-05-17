import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../models/network_model.dart';
import '../widgets/retro_widgets.dart';

class AuditorScreen extends StatefulWidget {
  const AuditorScreen({super.key});

  @override
  State<AuditorScreen> createState() => _AuditorScreenState();
}

class _AuditorScreenState extends State<AuditorScreen> {
  Timer? _flashTimer;
  int _flashTick = 0;

  @override
  void initState() {
    super.initState();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _flashTick++);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  bool _isFlashingRed(String bssid) {
    return _flashTick % 2 == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        final targeted = net.deauthTargetedNetworks;

        return RetroScreen(
          title: 'AUDITOR',
          children: [
            // ─── 1. Deauth Spike Graph ───────────────────────────────────
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
                      if (targeted.isNotEmpty)
                        MonoText('TARGET: ${targeted.length} AP(s)', fontSize: 8, color: const Color(0xFFFF4444)),
                      MonoText('NOW', fontSize: 8, color: Colors.white38),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── 2. BSSID Fingerprint (with deauth flash) ──────────────────
            RetroPanel(
              title: 'BSSID FINGERPRINT',
              child: Column(
                children: net.networks.map((n) {
                  final isTargeted = n.deauthTargeted;
                  final isRisky = n.ouiVendor.toUpperCase().contains('ESPRESSIF');
                  final trusted = net.isTrusted(n.bssid);
                  final flashing = isTargeted && _isFlashingRed(n.bssid);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: flashing ? const Color(0xFFFF0000) : Colors.black,
                        border: Border.all(
                          color: isTargeted ? const Color(0xFFFF0000) : Colors.white24,
                          width: isTargeted ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isTargeted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.gpp_maybe, color: Color(0xFFFF0000), size: 14),
                                  const SizedBox(width: 4),
                                  MonoText(
                                    'DEAUTH TARGET — UNDER ATTACK',
                                    fontSize: 9,
                                    color: flashing ? Colors.black : const Color(0xFFFF0000),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ],
                              ),
                            ),
                          _FingerprintRow(
                            'SSID:', n.ssid.isEmpty ? '<HIDDEN>' : "'${n.ssid}'",
                            color: flashing ? Colors.black : Colors.white,
                            bold: true,
                          ),
                          _FingerprintRow(
                            'TARGET MAC:', n.bssid,
                            color: flashing ? Colors.black : null,
                          ),
                          _FingerprintRow(
                            'CHANNEL:', '${n.channel} (2.4GHz)',
                            color: flashing ? Colors.black : null,
                          ),
                          _FingerprintRow(
                            'SIGNAL (RSSI):', '${n.rssi} dBm',
                            color: flashing ? Colors.black : null,
                          ),
                          _FingerprintRow(
                            'FRAMES/S:', '${n.perApFrames}',
                            color: flashing ? Colors.black : null,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              MonoText('VENDOR OUI:', fontSize: 10, color: flashing ? Colors.black : Colors.white54),
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
                                    border: Border.all(
                                      color: trusted ? const Color(0xFF39FF14) : Colors.white54,
                                      width: 1,
                                    ),
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
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // ─── 3. Evil Twin Scanner ───────────────────────────────────────
            RetroPanel(
              title: 'EVIL TWIN SCAN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group networks by SSID, show pairs with same SSID
                  ...(() {
                    final Map<String, List<NetworkInfo>> bySsid = {};
                    for (final n in net.networks) {
                      if (n.ssid.isEmpty || n.ssid == '<Hidden>') continue;
                      bySsid.putIfAbsent(n.ssid, () => []).add(n);
                    }

                    final paired = bySsid.entries.where((e) => e.value.length > 1).toList();

                    if (paired.isEmpty) {
                      return [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: MonoText(
                              'NO EVIL TWIN DETECTED',
                              fontSize: 10,
                              color: const Color(0xFF39FF14),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        MonoText(
                          '>> ALL SSIDs ARE UNIQUE\n>> NO DUPLICATE BSSIDs FOUND',
                          fontSize: 8,
                          color: Colors.white30,
                        ),
                      ];
                    }

                    return paired.map((entry) {
                      final ssid = entry.key;
                      final aps = entry.value;
                      final hasEspressif = aps.any((n) => n.ouiVendor.toUpperCase().contains('ESPRESSIF'));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasEspressif ? const Color(0xFF1A0000) : const Color(0xFF0A0A00),
                          border: Border.all(
                            color: hasEspressif ? const Color(0xFFFF0000) : const Color(0xFFFFFF00),
                            width: hasEspressif ? 2 : 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SSID header
                            Row(
                              children: [
                                Icon(
                                  hasEspressif ? Icons.warning_amber_rounded : Icons.copy,
                                  color: hasEspressif ? const Color(0xFFFF0000) : const Color(0xFFFFFF00),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: MonoText(
                                    "SSID: '$ssid'",
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasEspressif ? const Color(0xFFFF4444) : const Color(0xFFFFFF00),
                                  ),
                                ),
                                StatusBadge(
                                  hasEspressif
                                      ? '[ EVIL TWIN ]\nPHISHING RISK'
                                      : '[ DUPLICATE ]\nTWIN FOUND',
                                  color: hasEspressif ? const Color(0xFFFF0000) : const Color(0xFFFFFF00),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            MonoText(
                              '${aps.length} BSSIDs share this SSID:',
                              fontSize: 8,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 4),
                            // List each BSSID in the pair
                            ...aps.map((ap) => Container(
                              margin: const EdgeInsets.only(bottom: 4, left: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(
                                  color: ap.deauthTargeted ? const Color(0xFFFF0000) : Colors.white12,
                                  width: ap.deauthTargeted ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MonoText('BSSID: ${ap.bssid}', fontSize: 9, color: Colors.white),
                                        Row(
                                          children: [
                                            MonoText('CH:${ap.channel}', fontSize: 8, color: Colors.white38),
                                            const SizedBox(width: 8),
                                            MonoText('${ap.rssi} dBm', fontSize: 8, color: Colors.white38),
                                            const SizedBox(width: 8),
                                            MonoText(ap.ouiVendor, fontSize: 8, color: ap.ouiVendor.toUpperCase().contains('ESPRESSIF')
                                                ? const Color(0xFFFF4444) : Colors.white38),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (ap.deauthTargeted)
                                    const Icon(Icons.gpp_maybe, color: Color(0xFFFF0000), size: 16),
                                ],
                              ),
                            )),
                            // RSSI difference warning
                            if (aps.length >= 2) ...[
                              const SizedBox(height: 4),
                              MonoText(
                                'Δ RSSI: ${(aps[0].rssi - aps[1].rssi).abs()} dBm',
                                fontSize: 8,
                                color: (aps[0].rssi - aps[1].rssi).abs() < 5
                                    ? const Color(0xFFFF0000)
                                    : Colors.white38,
                              ),
                              if ((aps[0].rssi - aps[1].rssi).abs() < 5)
                                MonoText(
                                  '>> CLOSE SIGNAL STRENGTH — HIGHLY SUSPICIOUS',
                                  fontSize: 7,
                                  color: const Color(0xFFFF4444),
                                ),
                            ],
                          ],
                        ),
                      );
                    }).toList();
                  })(),
                ],
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
  final Color? color;
  final bool bold;
  const _FingerprintRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: MonoText(label, fontSize: 10, color: color ?? Colors.white54),
          ),
          Expanded(child: MonoText(value, fontSize: 10, color: color ?? Colors.white, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
