// lib/widgets/ap_selector.dart
//
// Retro-styled Access Point selector widget.
// Shows all currently visible APs; tapping one sets it as the "monitored" AP.
// The selected AP's RSSI is highlighted in the Spectrum tab and its
// packet-per-second data replaces the global graph in the Dashboard tab.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import 'retro_widgets.dart';

class ApSelector extends StatefulWidget {
  /// compact = single-row dropdown style (for embedding in Dashboard/Spectrum header)
  /// expanded = full panel with list (standalone usage)
  final bool compact;

  const ApSelector({super.key, this.compact = false});

  @override
  State<ApSelector> createState() => _ApSelectorState();
}

class _ApSelectorState extends State<ApSelector> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (ctx, net, _) {
        if (widget.compact) return _buildCompact(net);
        return _buildFull(net);
      },
    );
  }

  // ── Compact (dropdown-style, embeds in other panels) ─────────────────────
  Widget _buildCompact(NetworkProvider net) {
    final selected = net.selectedNetwork;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Selected row (tap to toggle list) ──────────────────────────
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: _open ? Colors.white : Colors.white54,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: selected == null
                      ? MonoText('[ ALL NETWORKS — GLOBAL VIEW ]', fontSize: 10, color: Colors.white54)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoText(
                              selected.ssid.isEmpty ? '<HIDDEN>' : selected.ssid,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            MonoText(selected.bssid, fontSize: 8, color: Colors.white54),
                          ],
                        ),
                ),
                // RSSI badge (when selected)
                if (selected != null) ...[
                  const SizedBox(width: 6),
                  _RssiChip(rssi: selected.rssi),
                  const SizedBox(width: 6),
                ],
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        // ── Dropdown list ───────────────────────────────────────────────
        if (_open)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              children: [
                _ApRow(
                  label: '[ ALL NETWORKS ]',
                  sublabel: 'GLOBAL VIEW — NO FILTER',
                  selected: net.selectedBssid == null,
                  onTap: () {
                    net.selectAp(null);
                    setState(() => _open = false);
                  },
                ),
                ...net.networks.map((n) => _ApRow(
                  label: n.ssid.isEmpty ? '<HIDDEN>' : n.ssid,
                  sublabel: '${n.bssid}  CH${n.channel}  ${n.rssi}dBm',
                  vendor: n.ouiVendor,
                  rssi: n.rssi,
                  selected: net.selectedBssid == n.bssid,
                  flagged: net.evilTwinSuspects.contains(n),
                  onTap: () {
                    net.selectAp(n.bssid);
                    setState(() => _open = false);
                  },
                )),
              ],
            ),
          ),
      ],
    );
  }

  // ── Full panel (used as standalone widget if needed) ─────────────────────
  Widget _buildFull(NetworkProvider net) {
    return RetroPanel(
      title: 'SELECT AP TO MONITOR',
      child: Column(
        children: [
          // All-networks option
          _ApRow(
            label: '[ ALL NETWORKS ]',
            sublabel: 'GLOBAL VIEW — NO FILTER',
            selected: net.selectedBssid == null,
            onTap: () => net.selectAp(null),
          ),
          const RetroDivider(),
          ...net.networks.map((n) => _ApRow(
            label: n.ssid.isEmpty ? '<HIDDEN>' : n.ssid,
            sublabel: '${n.bssid}  CH${n.channel}',
            vendor: n.ouiVendor,
            rssi: n.rssi,
            selected: net.selectedBssid == n.bssid,
            flagged: net.evilTwinSuspects.contains(n),
            onTap: () => net.selectAp(n.bssid),
          )),
          if (net.networks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: MonoText(
                '>> NO NETWORKS DETECTED\n>> CONNECT ESP32 VIA USB-OTG',
                fontSize: 10,
                color: Colors.white30,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single AP row ─────────────────────────────────────────────────────────────
class _ApRow extends StatefulWidget {
  final String label;
  final String sublabel;
  final String? vendor;
  final int?    rssi;
  final bool    selected;
  final bool    flagged;
  final VoidCallback onTap;

  const _ApRow({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    this.vendor,
    this.rssi,
    this.flagged = false,
  });

  @override
  State<_ApRow> createState() => _ApRowState();
}

class _ApRowState extends State<_ApRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.transparent;
    Color bgColor     = Colors.transparent;
    Color textColor   = Colors.white;

    if (widget.flagged) {
      borderColor = const Color(0xFFFF0000);
      bgColor     = const Color(0xFF0D0000);
      textColor   = const Color(0xFFFF6666);
    } else if (widget.selected) {
      bgColor   = Colors.white;
      textColor = Colors.black;
    } else if (_pressed) {
      bgColor   = Colors.white24;
    }

    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: borderColor == Colors.transparent ? 0 : 1),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              color: widget.selected ? (widget.flagged ? const Color(0xFFFF0000) : textColor) : Colors.transparent,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.spaceMono(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.sublabel,
                    style: GoogleFonts.spaceMono(
                      color: widget.selected ? Colors.black54 : Colors.white38,
                      fontSize: 8,
                    ),
                  ),
                  if (widget.vendor != null)
                    Text(
                      'OUI: ${widget.vendor}',
                      style: GoogleFonts.spaceMono(
                        color: widget.selected ? Colors.black54 : Colors.white24,
                        fontSize: 7,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.rssi != null) _RssiChip(rssi: widget.rssi!, inverted: widget.selected),
            if (widget.flagged)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: StatusBadge('TWIN', color: const Color(0xFFFF0000)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── RSSI signal-bar chip ──────────────────────────────────────────────────────
class _RssiChip extends StatelessWidget {
  final int  rssi;
  final bool inverted;
  const _RssiChip({required this.rssi, this.inverted = false});

  Color get _barColor {
    if (rssi > -55) return const Color(0xFF39FF14);
    if (rssi > -70) return Colors.white;
    return const Color(0xFFFF0000);
  }

  int get _bars {
    if (rssi > -55) return 4;
    if (rssi > -65) return 3;
    if (rssi > -75) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${rssi}dBm',
          style: GoogleFonts.spaceMono(
            fontSize: 8,
            color: inverted ? Colors.black : _barColor,
          ),
        ),
        const SizedBox(width: 4),
        // Signal bars
        ...List.generate(4, (i) {
          final active = i < _bars;
          return Container(
            width: 3,
            height: 4.0 + i * 3,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            color: active
                ? (inverted ? Colors.black : _barColor)
                : (inverted ? Colors.black26 : Colors.white12),
          );
        }),
      ],
    );
  }
}
