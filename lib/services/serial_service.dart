// lib/services/serial_service.dart
//
// Manages the USB-Serial connection to the ESP32.
// Reads newline-delimited JSON and calls onPayload for each valid packet.
// ───────────────────────────────────────────────────────────────────────────────
// usb_serial package: https://pub.dev/packages/usb_serial
// Android manifest must declare:
//   <uses-feature android:name="android.hardware.usb.host"/>
// ───────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

enum SerialState { disconnected, connecting, connected, error }

typedef PayloadCallback = void Function(Map<String, dynamic> json);

class SerialService {
  SerialState state = SerialState.disconnected;
  String? errorMessage;

  UsbPort?            _port;
  StreamSubscription? _dataSub;
  StreamSubscription? _deviceSub;
  final StringBuffer  _buffer = StringBuffer();

  final VoidCallback    onStateChanged;
  final PayloadCallback onPayload;

  SerialService({required this.onStateChanged, required this.onPayload});

  // ── Start listening for USB attach/detach ─────────────────────────────────
  void init() {
    _deviceSub = UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        connect();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        _disconnect('Device detached');
      }
    });
    // Try connecting immediately in case device is already plugged in
    connect();
  }

  // ── Connect to the first available USB serial port ────────────────────────
  Future<void> connect() async {
    if (state == SerialState.connecting || state == SerialState.connected) return;

    _setState(SerialState.connecting);
    errorMessage = null;

    try {
      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        _setState(SerialState.disconnected);
        errorMessage = 'No USB device found. Connect ESP32 via OTG.';
        return;
      }

      // Pick the first device (typically the ESP32 CH340/CP210x)
      final device = devices.first;
      _port = await device.create();
      if (_port == null) {
        _setState(SerialState.error);
        errorMessage = 'Could not create port for ${device.productName}';
        return;
      }

      final ok = await _port!.open();
      if (!ok) {
        _setState(SerialState.error);
        errorMessage = 'Failed to open port — check OTG permissions.';
        return;
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        115200,                      // ← Must match ESP32 Serial.begin()
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _dataSub = _port!.inputStream?.listen(
        _onBytes,
        onError: (e) => _disconnect('Stream error: $e'),
        onDone:  ()  => _disconnect('Stream closed'),
      );

      _setState(SerialState.connected);
    } catch (e) {
      _setState(SerialState.error);
      errorMessage = 'Exception: $e';
    }
  }

  // ── Bytes → line-buffer → JSON parse ─────────────────────────────────────
  void _onBytes(Uint8List bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _buffer.write(chunk);

    final raw = _buffer.toString();
    final lines = raw.split('\n');

    // All but the last element are complete lines
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        onPayload(json);
      } catch (_) {
        // Ignore malformed / partial packets
      }
    }

    // Keep the incomplete tail in the buffer
    _buffer.clear();
    _buffer.write(lines.last);
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  Future<void> _disconnect(String reason) async {
    await _dataSub?.cancel();
    await _port?.close();
    _dataSub = null;
    _port    = null;
    _buffer.clear();
    errorMessage = reason;
    _setState(SerialState.disconnected);
  }

  Future<void> disconnect() => _disconnect('Manual disconnect');

  void _setState(SerialState s) {
    state = s;
    onStateChanged();
  }

  void dispose() {
    _deviceSub?.cancel();
    _disconnect('Disposed');
  }
}
