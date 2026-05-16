// lib/widgets/connection_banner.dart
//
// Shows ESP32 connection status at the top of any screen.
// Green border = connected | blinking red = disconnected/error
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../services/serial_service.dart';
import 'retro_widgets.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (ctx, net, _) {
        final connected = net.isConnected;
        final isError   = net.serialState == SerialState.error;
        final isConnecting = net.serialState == SerialState.connecting;

        Color borderColor;
        String statusText;
        if (connected) {
          borderColor = const Color(0xFF39FF14);
          statusText  = '>> ESP32 CONNECTED — LIVE DATA ACTIVE';
        } else if (isConnecting) {
          borderColor = Colors.white54;
          statusText  = '>> CONNECTING TO ESP32...';
        } else if (isError) {
          borderColor = const Color(0xFFFF0000);
          statusText  = '>> ERROR: ${net.serialError ?? "UNKNOWN"}';
        } else {
          borderColor = Colors.white30;
          statusText  = '>> ESP32 DISCONNECTED — CONNECT VIA USB-OTG';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: borderColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MonoText(
                  statusText,
                  fontSize: 9,
                  color: borderColor,
                ),
              ),
              if (!connected)
                GestureDetector(
                  onTap: net.connectSerial,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                    child: MonoText('[ RETRY ]', fontSize: 9, color: Colors.white54),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
