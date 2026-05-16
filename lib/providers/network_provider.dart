import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/network_model.dart';

enum ThreatLevel { clear, congestion, attack }

class NetworkProvider extends ChangeNotifier {
  final _rng = Random();
  Timer? _timer;

  // Live data
  int packetsPerSec = 0;
  int deauths = 0;
  int trustScore = 88;
  ThreatLevel threatLevel = ThreatLevel.clear;
  List<int> channelCongestion = List.filled(13, 0);
  List<NetworkInfo> networks = [];
  double rssi = -42;

  // History buffers
  final List<double> packetHistory = List.filled(40, 0);
  final List<double> deauthHistory = List.filled(40, 0);
  final List<double> rssiHistory = List.filled(60, -65);

  // Incident calendar (90 days)
  late List<int> incidentCalendar;

  // Hourly trend (24h)
  final List<double> hourlyTrend = List.generate(24, (i) {
    // Morning quiet, peak at midday and evening
    if (i < 6) return 10 + Random().nextDouble() * 10;
    if (i < 9) return 40 + Random().nextDouble() * 20;
    if (i < 14) return 60 + Random().nextDouble() * 30;
    if (i < 18) return 50 + Random().nextDouble() * 20;
    if (i < 21) return 70 + Random().nextDouble() * 20;
    return 30 + Random().nextDouble() * 15;
  });

  // Settings
  int deauthThreshold = 50;
  int packetThreshold = 1024;
  bool auditLogging = true;
  List<TrustedNetwork> trustedNetworks = [
    TrustedNetwork(mac: 'A1:B2:C3:D4:E5:F6', label: 'HOME_BASE_ROUTER'),
    TrustedNetwork(mac: 'A1:B2:C3:D4:E5:F7', label: 'CAFE_SECURE_NODE'),
    TrustedNetwork(mac: 'AA:BB:CC:DD:EE:FF', label: 'OFFICE_GUEST_WIFI'),
  ];

  // Attack simulation toggle
  bool _simulateAttack = false;
  int _attackCooldown = 0;

  NetworkProvider() {
    incidentCalendar = List.generate(90, (i) {
      if (i % 7 == 0 || i % 7 == 6) return _rng.nextInt(3);
      return _rng.nextInt(8);
    });

    networks = [
      NetworkInfo(
        ssid: 'Campus_WiFi',
        bssid: '00:1A:2B:3C:4D:5E',
        rssi: -45,
        channel: 11,
        ouiVendor: 'ESPRESSIF',
      ),
      NetworkInfo(
        ssid: 'Campus_WiFi',
        bssid: 'A1:B2:C3:D4:E5:F6',
        rssi: -60,
        channel: 6,
        ouiVendor: 'TP-Link',
      ),
      NetworkInfo(
        ssid: 'Library_Net',
        bssid: 'DE:AD:BE:EF:CA:FE',
        rssi: -72,
        channel: 1,
        ouiVendor: 'Cisco',
      ),
    ];

    channelCongestion = [12, 5, 0, 0, 1, 45, 0, 0, 0, 0, 18, 2, 0];
  }

  void startSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
  }

  void triggerAttackSimulation() {
    _simulateAttack = true;
    _attackCooldown = 8;
    notifyListeners();
  }

  void _tick() {
    if (_attackCooldown > 0) {
      _attackCooldown--;
      if (_attackCooldown == 0) _simulateAttack = false;
    }

    // Randomly trigger attack occasionally
    if (!_simulateAttack && _rng.nextInt(60) == 0) {
      _simulateAttack = true;
      _attackCooldown = 6;
    }

    if (_simulateAttack) {
      packetsPerSec = 800 + _rng.nextInt(600);
      deauths = 80 + _rng.nextInt(120);
      trustScore = max(5, trustScore - _rng.nextInt(8));
      threatLevel = ThreatLevel.attack;
    } else {
      packetsPerSec = 100 + _rng.nextInt(200);
      deauths = _rng.nextInt(5);
      trustScore = min(95, trustScore + _rng.nextInt(3));
      if (trustScore > 70) {
        threatLevel = ThreatLevel.clear;
      } else if (trustScore > 40) {
        threatLevel = ThreatLevel.congestion;
      }
    }

    // Update packet history
    packetHistory.removeAt(0);
    packetHistory.add(packetsPerSec.toDouble());

    // Update deauth history
    deauthHistory.removeAt(0);
    deauthHistory.add(deauths.toDouble());

    // Update RSSI
    rssi = -42 + (_rng.nextDouble() - 0.5) * 6;
    rssiHistory.removeAt(0);
    rssiHistory.add(rssi);

    // Drift channel congestion
    channelCongestion = channelCongestion.map((v) {
      final delta = _rng.nextInt(5) - 2;
      return max(0, min(99, v + delta));
    }).toList();

    notifyListeners();
  }

  String get signalQuality {
    if (rssi > -50) return 'EXCELLENT';
    if (rssi > -60) return 'GOOD';
    if (rssi > -70) return 'FAIR';
    if (rssi > -80) return 'POOR';
    return 'DEAD ZONE';
  }

  String get threatText {
    switch (threatLevel) {
      case ThreatLevel.clear:
        return 'ALL CLEAR';
      case ThreatLevel.congestion:
        return 'HIGH CONGESTION';
      case ThreatLevel.attack:
        return 'UNDER ATTACK';
    }
  }

  List<NetworkInfo> get evilTwinSuspects {
    final Map<String, List<NetworkInfo>> grouped = {};
    for (final n in networks) {
      grouped.putIfAbsent(n.ssid, () => []).add(n);
    }
    return grouped.entries
        .where((e) => e.value.length > 1)
        .expand((e) => e.value)
        .toList();
  }

  void addTrustedNetwork(String mac, String label) {
    trustedNetworks.add(TrustedNetwork(mac: mac, label: label));
    notifyListeners();
  }

  void removeTrustedNetwork(int index) {
    trustedNetworks.removeAt(index);
    notifyListeners();
  }

  void setDeauthThreshold(int val) {
    deauthThreshold = val;
    notifyListeners();
  }

  void setPacketThreshold(int val) {
    packetThreshold = val;
    notifyListeners();
  }

  void toggleAuditLogging() {
    auditLogging = !auditLogging;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
