// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../widgets/retro_widgets.dart';
import '../widgets/connection_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, net, _) {
        return RetroScreen(
          title: 'SETTINGS',
          children: [
            const ConnectionBanner(),

            // ── Trusted Networks Summary ──────────────────────────────────
            RetroPanel(
              title: 'TRUSTED NETWORKS (${net.trustedNetworks.length})',
              child: net.trustedNetworks.isEmpty
                  ? MonoText('NO TRUSTED NETWORKS. ADD VIA AUDITOR TAB.', fontSize: 9, color: Colors.white38)
                  : Column(
                      children: net.trustedNetworks.map((t) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 1)),
                        child: Row(
                          children: [
                            const Icon(Icons.shield, color: Color(0xFF39FF14), size: 12),
                            const SizedBox(width: 8),
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
                              onTap: () => net.removeTrustedNetwork(t.mac),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
            ),

            const SizedBox(height: 10),

            // ── Alert Thresholds ──────────────────────────────────────────
            RetroPanel(
              title: 'ALERT THRESHOLDS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('DEAUTH ALERT THRESHOLD', fontSize: 9),
                      MonoText(
                        net.deauthThreshold > 70 ? '[ HIGH ]' : net.deauthThreshold > 30 ? '[ MEDIUM ]' : '[ LOW ]',
                        fontSize: 9,
                        color: net.deauthThreshold > 70 ? const Color(0xFFFF0000) : Colors.white,
                      ),
                    ],
                  ),
                  RetroSlider(
                    value: net.deauthThreshold.toDouble(),
                    min: 10, max: 200,
                    onChanged: (v) => net.setDeauthThreshold(v.round()),
                  ),
                  MonoText('ALERT IF DEAUTHS > ${net.deauthThreshold} / SEC', fontSize: 8, color: Colors.white38),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('PACKET_LIMITS_SEC', fontSize: 9),
                      MonoText('[ ${net.packetThreshold} ]', fontSize: 9),
                    ],
                  ),
                  RetroSlider(
                    value: net.packetThreshold.toDouble(),
                    min: 100, max: 2000,
                    onChanged: (v) => net.setPacketThreshold(v.round()),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoText('AUDIT_LOGGING → SQLITE', fontSize: 10),
                      Row(
                        children: [
                          _ToggleBtn(label: '[ ON ]',  active: net.auditLogging,  onTap: () { if (!net.auditLogging) net.toggleAuditLogging(); }),
                          const SizedBox(width: 6),
                          _ToggleBtn(label: '[ OFF ]', active: !net.auditLogging, onTap: () { if (net.auditLogging) net.toggleAuditLogging(); }),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── DB Info ───────────────────────────────────────────────────
            RetroPanel(
              title: 'DATABASE INFO',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText('FILE: safenet_auditor.db', fontSize: 9),
                  MonoText('SNAPSHOTS  : ${net.dbStats['snapshots']  ?? '--'}', fontSize: 9, color: Colors.white70),
                  MonoText('NETWORKS   : ${net.dbStats['networks']   ?? '--'}', fontSize: 9, color: Colors.white70),
                  MonoText('INCIDENTS  : ${net.dbStats['incidents']  ?? '--'}', fontSize: 9, color: Colors.white70),
                  MonoText('TRUSTED    : ${net.trustedNetworks.length}', fontSize: 9, color: Colors.white70),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Danger Zone ───────────────────────────────────────────────
            RetroPanel(
              title: 'DANGER_ZONE',
              borderColor: const Color(0xFFFF0000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF0000), width: 1)),
                    child: MonoText(
                      'WARNING: CLEARING CACHE WILL\nREMOVE ALL INTERCEPTED PACKET\nHISTORY FROM SQLITE DATABASE.',
                      fontSize: 10,
                      color: const Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RetroButton(
                    label: '[ CLEAR ALL LOGS ]',
                    color: const Color(0xFFFF0000),
                    onTap: () => _showClearDialog(context, net),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.white12, width: 1)),
              child: MonoText(
                'SAFE-NET AUDITOR v1.0.0\n'
                'BUILD: 2025.06.ESP32\n'
                'PROTOCOL: 802.11 MGMT FRAMES\n'
                'BAND: 2.4GHz / PROMISCUOUS\n'
                'DB: SQLite via sqflite',
                fontSize: 8,
                color: Colors.white24,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearDialog(BuildContext context, NetworkProvider net) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF0000), width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoText('[ !! WARNING !! ]', fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFF0000)),
              const SizedBox(height: 12),
              MonoText('THIS WILL ERASE ALL\nSQLITE PACKET HISTORY.\nPROCEED?', fontSize: 10, color: Colors.white70, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RetroButton(label: '[ CANCEL ]', onTap: () => Navigator.of(context).pop()),
                  RetroButton(
                    label: '[ CONFIRM ]',
                    color: const Color(0xFFFF0000),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await net.clearDatabase();
                    },
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

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black,
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(label, style: GoogleFonts.spaceMono(color: active ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
