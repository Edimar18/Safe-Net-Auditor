import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _macController = TextEditingController();

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        return RetroScreen(
          title: 'SETTINGS',
          children: [
            // ─── Trusted Networks ─────────────────────────────────────────
            RetroPanel(
              title: 'TRUSTED NETWORKS',
              child: Column(
                children: [
                  ...List.generate(net.trustedNetworks.length, (i) {
                    final t = net.trustedNetworks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonoText(t.label, fontSize: 10, fontWeight: FontWeight.bold),
                                MonoText(t.mac, fontSize: 9, color: Colors.white54),
                              ],
                            ),
                          ),
                          RetroButton(
                            label: '[ REMOVE ]',
                            fontSize: 9,
                            color: const Color(0xFFFF0000),
                            onTap: () => net.removeTrustedNetwork(i),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Add node row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54, width: 1),
                          ),
                          child: TextField(
                            controller: _macController,
                            style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'ENTER MAC ADDR',
                              hintStyle: GoogleFonts.spaceMono(
                                color: Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                            cursorColor: const Color(0xFF39FF14),
                            cursorWidth: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RetroButton(
                        label: '[\nADD_NODE\n]',
                        onTap: () {
                          final mac = _macController.text.trim();
                          if (mac.isNotEmpty) {
                            net.addTrustedNetwork(mac, 'NODE_${net.trustedNetworks.length + 1}');
                            _macController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── Alert Thresholds ─────────────────────────────────────────
            RetroPanel(
              title: 'ALERT THRESHOLDS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deauth threshold
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('VIBRATION_INTENSITY', fontSize: 9),
                      MonoText(
                        net.deauthThreshold > 70
                            ? '[ HIGH ]'
                            : net.deauthThreshold > 30
                                ? '[ MEDIUM ]'
                                : '[ LOW ]',
                        fontSize: 9,
                        color: net.deauthThreshold > 70
                            ? const Color(0xFFFF0000)
                            : Colors.white,
                      ),
                    ],
                  ),
                  RetroSlider(
                    value: net.deauthThreshold.toDouble(),
                    min: 10,
                    max: 200,
                    onChanged: (v) => net.setDeauthThreshold(v.round()),
                  ),

                  const SizedBox(height: 8),

                  // Packet threshold
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('PACKET_LIMITS_SEC', fontSize: 9),
                      MonoText('[ ${net.packetThreshold} ]', fontSize: 9),
                    ],
                  ),
                  RetroSlider(
                    value: net.packetThreshold.toDouble(),
                    min: 100,
                    max: 2000,
                    onChanged: (v) => net.setPacketThreshold(v.round()),
                  ),

                  const SizedBox(height: 10),

                  // Audit logging toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('AUDIT_LOGGING', fontSize: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: net.auditLogging ? null : net.toggleAuditLogging,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: net.auditLogging ? Colors.white : Colors.black,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                '[ ON ]',
                                style: GoogleFonts.spaceMono(
                                  color: net.auditLogging ? Colors.black : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: net.auditLogging ? net.toggleAuditLogging : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !net.auditLogging ? Colors.white : Colors.black,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                '[ OFF ]',
                                style: GoogleFonts.spaceMono(
                                  color: !net.auditLogging ? Colors.black : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── Danger Zone ──────────────────────────────────────────────
            RetroPanel(
              title: 'DANGER_ZONE',
              borderColor: const Color(0xFFFF0000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFF0000), width: 1),
                    ),
                    child: MonoText(
                      'WARNING: CLEARING CACHE WILL\nREMOVE ALL INTERCEPTED PACKET\nHISTORY.',
                      fontSize: 10,
                      color: const Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RetroButton(
                    label: '[ CLEAR ALL LOGS ]',
                    color: const Color(0xFFFF0000),
                    onTap: () => _showClearDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ─── App info ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.white12, width: 1)),
              child: MonoText(
                'SAFE-NET AUDITOR v1.0.0\n'
                'BUILD: 2025.06.ESP32\n'
                'PROTOCOL: 802.11 MGMT FRAMES\n'
                'BAND: 2.4GHz / PROMISCUOUS',
                fontSize: 8,
                color: Colors.white24,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFF0000), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoText('[ !! WARNING !! ]', fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFF0000)),
              const SizedBox(height: 12),
              MonoText('THIS WILL ERASE ALL\nLOGGED PACKET HISTORY.\nPROCEED?', fontSize: 10, color: Colors.white70, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RetroButton(
                    label: '[ CANCEL ]',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  RetroButton(
                    label: '[ CONFIRM ]',
                    color: const Color(0xFFFF0000),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
