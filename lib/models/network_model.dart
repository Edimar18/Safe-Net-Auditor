class NetworkData {
  final int timestamp;
  final int packetsPerSec;
  final int deauths;
  final List<int> channelCongestion;
  final List<NetworkInfo> networks;

  NetworkData({
    required this.timestamp,
    required this.packetsPerSec,
    required this.deauths,
    required this.channelCongestion,
    required this.networks,
  });

  factory NetworkData.fromJson(Map<String, dynamic> json) {
    return NetworkData(
      timestamp: json['timestamp'] ?? 0,
      packetsPerSec: json['packets_per_sec'] ?? 0,
      deauths: json['deauths'] ?? 0,
      channelCongestion: List<int>.from(json['channel_congestion'] ?? []),
      networks: (json['networks'] as List<dynamic>? ?? [])
          .map((n) => NetworkInfo.fromJson(n))
          .toList(),
    );
  }
}

class NetworkInfo {
  final String ssid;
  final String bssid;
  final int rssi;
  final int channel;
  final String ouiVendor;

  NetworkInfo({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.channel,
    required this.ouiVendor,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInfo(
      ssid: json['ssid'] ?? '',
      bssid: json['bssid'] ?? '',
      rssi: json['rssi'] ?? -70,
      channel: json['channel'] ?? 1,
      ouiVendor: json['oui_vendor'] ?? 'Unknown',
    );
  }
}

class TrustedNetwork {
  final String mac;
  final String label;

  TrustedNetwork({required this.mac, required this.label});
}
