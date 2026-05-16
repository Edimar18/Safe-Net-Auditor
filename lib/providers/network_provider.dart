// lib/providers/network_provider.dart
//
// Real-data provider.
// • Reads JSON from ESP32 via SerialService
// • Persists every snapshot to SQLite via DatabaseService
// • Exposes selectedBssid for per-AP RSSI and packet graphs
// ───────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/network_model.dart';
import '../services/serial_service.dart';
import '../services/database_service.dart';

enum ThreatLevel { clear, congestion, attack }

class NetworkProvider extends ChangeNotifier {

  // ── Services ────────────────────────────────────────────────────────────
  late final SerialService _serial;
  final DatabaseService    _dbSvc = DatabaseService.instance;

  // ── Connection state (exposed to UI) ────────────────────────────────────
  SerialState get serialState => _serial.state;
  String? get serialError     => _serial.errorMessage;
  bool get isConnected        => _serial.state == SerialState.connected;

  // ── Live fields (updated from ESP32) ────────────────────────────────────
  int              packetsPerSec     = 0;
  int              deauths           = 0;
  int              trustScore        = 100;
  ThreatLevel      threatLevel       = ThreatLevel.clear;
  List<int>        channelCongestion = List.filled(13, 0);
  List<NetworkInfo> networks         = [];
  double           rssi              = -70;

  // ── Rolling history buffers (global) ────────────────────────────────────
  final List<double> packetHistory = List.filled(40, 0);
  final List<double> deauthHistory = List.filled(40, 0);
  final List<double> rssiHistory   = List.filled(60, -70);

  // ── Per-AP history buffers (for selected BSSID) ──────────────────────────
  List<double> selectedRssiHistory   = List.filled(60, -70);
  List<double> selectedPacketHistory = List.filled(40, 0);

  // ── AP Selector ─────────────────────────────────────────────────────────
  String? selectedBssid;
  NetworkInfo? get selectedNetwork =>
      selectedBssid == null
          ? null
          : networks.where((n) => n.bssid == selectedBssid).firstOrNull;

  void selectAp(String? bssid) {
    selectedBssid = bssid;
    if (bssid != null) _loadDbHistoryFor(bssid);
    notifyListeners();
  }

  // ── Historical / analytics (loaded from DB) ──────────────────────────────
  List<int>    incidentCalendar = List.filled(90, 0);
  List<double> hourlyTrend      = List.filled(24, 0);

  // ── Settings ─────────────────────────────────────────────────────────────
  int  deauthThreshold  = 50;
  int  packetThreshold  = 1024;
  bool auditLogging     = true;
  List<TrustedNetwork> trustedNetworks = [
    TrustedNetwork(mac: 'A1:B2:C3:D4:E5:F6', label: 'HOME_BASE_ROUTER'),
    TrustedNetwork(mac: 'A1:B2:C3:D4:E5:F7', label: 'CAFE_SECURE_NODE'),
    TrustedNetwork(mac: 'AA:BB:CC:DD:EE:FF', label: 'OFFICE_GUEST_WIFI'),
  ];

  // ── DB stats ─────────────────────────────────────────────────────────────
  Map<String, int> dbStats = {};

  int _snapshotCounter = 0;

  // ═════════════════════════════════════════════════════════════════════════
  NetworkProvider() {
    _serial = SerialService(
      onStateChanged: () => notifyListeners(),
      onPayload: _onEsp32Payload,
    );
  }

  Future<void> init() async {
    incidentCalendar = await _dbSvc.getIncidentCalendar();
    hourlyTrend      = await _dbSvc.getHourlyTrend();
    dbStats          = await _dbSvc.getStats();
    notifyListeners();
    _serial.init();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ESP32 PAYLOAD HANDLER
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _onEsp32Payload(Map<String, dynamic> json) async {
    packetsPerSec       = (json['packets_per_sec'] as num?)?.toInt() ?? 0;
    deauths             = (json['deauths']         as num?)?.toInt() ?? 0;
    final int disassocs = (json['disassocs']        as num?)?.toInt() ?? 0;
    final int probeReqs = (json['probe_reqs']       as num?)?.toInt() ?? 0;
    final int esp32Ts   = (json['timestamp']        as num?)?.toInt() ?? 0;

    // Channel congestion
    final rawCh = json['channel_congestion'];
    if (rawCh is List) {
      channelCongestion = rawCh.take(13).map((v) => (v as num).toInt()).toList();
      while (channelCongestion.length < 13) channelCongestion.add(0);
    }

    // Networks
    final rawNets = json['networks'];
    if (rawNets is List) {
      networks = rawNets
          .map((n) => NetworkInfo.fromJson(n as Map<String, dynamic>))
          .toList();
    }

    // Update selected-AP history
    if (selectedBssid != null) {
      final target = networks.where((n) => n.bssid == selectedBssid).firstOrNull;
      if (target != null) {
        rssi = target.rssi.toDouble();
        selectedRssiHistory.removeAt(0);
        selectedRssiHistory.add(rssi);
        selectedPacketHistory.removeAt(0);
        selectedPacketHistory.add(packetsPerSec.toDouble());
      }
    } else {
      if (networks.isNotEmpty) {
        rssi = networks.reduce((a, b) => a.rssi > b.rssi ? a : b).rssi.toDouble();
      }
      rssiHistory.removeAt(0);
      rssiHistory.add(rssi);
    }

    // Global rolling history
    packetHistory.removeAt(0);
    packetHistory.add(packetsPerSec.toDouble());
    deauthHistory.removeAt(0);
    deauthHistory.add(deauths.toDouble());

    _recalcTrustScore();
    await _detectAndLogEvilTwins();

    // Persist to SQLite
    if (auditLogging) {
      await _dbSvc.insertSnapshot(
        esp32Ts          : esp32Ts,
        packetsPerSec    : packetsPerSec,
        deauths          : deauths,
        disassocs        : disassocs,
        probeReqs        : probeReqs,
        trustScore       : trustScore,
        channelCongestion: channelCongestion,
        networks: networks.map((n) => {
          'ssid'      : n.ssid,
          'bssid'     : n.bssid,
          'rssi'      : n.rssi,
          'channel'   : n.channel,
          'oui_vendor': n.ouiVendor,
        }).toList(),
      );
    }

    notifyListeners();

    // Refresh DB analytics every 30 snapshots
    _snapshotCounter++;
    if (_snapshotCounter % 30 == 0) {
      incidentCalendar = await _dbSvc.getIncidentCalendar();
      hourlyTrend      = await _dbSvc.getHourlyTrend();
      dbStats          = await _dbSvc.getStats();
    }
  }

  Future<void> _loadDbHistoryFor(String bssid) async {
    final rssiList   = await _dbSvc.getRssiHistory(bssid, limit: 60);
    final packetList = await _dbSvc.getPacketHistory(bssid, limit: 40);

    selectedRssiHistory = List.filled(60, -70);
    for (int i = 0; i < rssiList.length; i++) {
      selectedRssiHistory[60 - rssiList.length + i] = rssiList[i].toDouble();
    }

    selectedPacketHistory = List.filled(40, 0);
    for (int i = 0; i < packetList.length; i++) {
      selectedPacketHistory[40 - packetList.length + i] = packetList[i].toDouble();
    }
    notifyListeners();
  }

  void _recalcTrustScore() {
    int score = 100;
    if (deauths > deauthThreshold)       score -= 40;
    else if (deauths > 10)               score -= 20;
    if (packetsPerSec > packetThreshold) score -= 20;
    if (evilTwinSuspects.isNotEmpty)     score -= 30;
    trustScore = score.clamp(0, 100);

    if (trustScore < 40 || deauths > deauthThreshold) {
      threatLevel = ThreatLevel.attack;
    } else if (trustScore < 70) {
      threatLevel = ThreatLevel.congestion;
    } else {
      threatLevel = ThreatLevel.clear;
    }
  }

  Future<void> _detectAndLogEvilTwins() async {
    final Map<String, List<NetworkInfo>> bySsid = {};
    for (final n in networks) bySsid.putIfAbsent(n.ssid, () => []).add(n);
    for (final entry in bySsid.entries) {
      if (entry.value.length > 1) {
        await _dbSvc.logEvilTwin(
          entry.key, entry.value[0].bssid, entry.value[1].bssid);
      }
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  String get threatText {
    switch (threatLevel) {
      case ThreatLevel.clear:      return 'ALL CLEAR';
      case ThreatLevel.congestion: return 'HIGH CONGESTION';
      case ThreatLevel.attack:     return 'UNDER ATTACK';
    }
  }

  String get signalQuality {
    final v = rssi;
    if (v > -50) return 'EXCELLENT';
    if (v > -60) return 'GOOD';
    if (v > -70) return 'FAIR';
    if (v > -80) return 'POOR';
    return 'DEAD ZONE';
  }

  List<NetworkInfo> get evilTwinSuspects {
    final Map<String, List<NetworkInfo>> grouped = {};
    for (final n in networks) grouped.putIfAbsent(n.ssid, () => []).add(n);
    return grouped.entries
        .where((e) => e.value.length > 1)
        .expand((e) => e.value)
        .toList();
  }

  List<double> get activeRssiHistory =>
      selectedBssid != null ? selectedRssiHistory : rssiHistory;

  List<double> get activePacketHistory =>
      selectedBssid != null ? selectedPacketHistory : packetHistory;

  // ── Serial control ────────────────────────────────────────────────────────
  Future<void> connectSerial()    => _serial.connect();
  Future<void> disconnectSerial() => _serial.disconnect();

  // ── Settings ─────────────────────────────────────────────────────────────
  void setDeauthThreshold(int v) { deauthThreshold  = v; notifyListeners(); }
  void setPacketThreshold(int v) { packetThreshold   = v; notifyListeners(); }
  void toggleAuditLogging()      { auditLogging = !auditLogging; notifyListeners(); }

  void addTrustedNetwork(String mac, String label) {
    trustedNetworks.add(TrustedNetwork(mac: mac, label: label));
    notifyListeners();
  }
  void removeTrustedNetwork(int i) {
    trustedNetworks.removeAt(i);
    notifyListeners();
  }

  Future<void> clearDatabase() async {
    await _dbSvc.clearAll();
    incidentCalendar = List.filled(90, 0);
    hourlyTrend      = List.filled(24, 0);
    dbStats          = {};
    notifyListeners();
  }

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }
}
