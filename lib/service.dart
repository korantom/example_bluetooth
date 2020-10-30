import 'dart:async';

import 'package:flutter_blue/flutter_blue.dart';

class DeviceBluetoothService {
  static final DeviceBluetoothService _service =
      DeviceBluetoothService._internal();

  factory DeviceBluetoothService() => _service;
  DeviceBluetoothService._internal();

  static DeviceBluetoothService get service => _service;

  //////////////////////////////////////////////////////////////////////////////

  // ignore: close_sinks
  final StreamController<List<String>> streamController =
      StreamController<List<String>>.broadcast();

  // ignore: close_sinks
  final StreamController<String> debugStreamController =
      StreamController<String>.broadcast();

  static Stream<List<String>> get stream =>
      DeviceBluetoothService._service.streamController.stream;
  static Stream<String> get debugStream =>
      DeviceBluetoothService._service.debugStreamController.stream;

  //////////////////////////////////////////////////////////////////////////////

  final Map<String, ScanResult> connectedDevices = Map<String, ScanResult>();

  Map<String, StreamSubscription<List<ScanResult>>> _scanListenerMap =
      Map<String, StreamSubscription<List<ScanResult>>>();
  Map<String, StreamSubscription<BluetoothDeviceState>>
      _connectionStateListenerMap =
      Map<String, StreamSubscription<BluetoothDeviceState>>();

  //////////////////////////////////////////////////////////////////////////////

  Future<void> connect(String serialNumber) async {
    debugStreamController.add("Searching for to $serialNumber");

    if (this.connectedDevices.containsKey(serialNumber)) return;
    if (this._scanListenerMap.containsKey(serialNumber)) return;

    this._scanListenerMap[serialNumber] = FlutterBlue.instance.scanResults
        .where((List<ScanResult> scanResultList) {
      return scanResultList
          .where(
              (ScanResult scanResult) => _matchDevice(scanResult, serialNumber))
          .isNotEmpty;
    }).listen(null);

    this._scanListenerMap[serialNumber].onData((scanResultList) {
      // FlutterBlue.instance.stopScan();
      debugStreamController.add("Found $serialNumber in scan list");

      this._scanListenerMap[serialNumber]?.cancel();
      this._scanListenerMap.remove(serialNumber);

      final scanResult = scanResultList
          .firstWhere((scanResult) => _matchDevice(scanResult, serialNumber));

      if (!this._connectionStateListenerMap.containsKey(serialNumber)) {
        this._connectionStateListenerMap[serialNumber] = scanResult.device.state
            .listen(_onConnectionStateChanged(serialNumber, scanResult));
      }
      debugStreamController.add("Connecting to $serialNumber");
      scanResult.device.connect();
    });

    FlutterBlue.instance.isScanning.last.then((value) => );
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 30));
  }

  void disconnect(String serialNumber) {
    if (connectedDevices[serialNumber] != null) {
      connectedDevices[serialNumber].device.disconnect();
      debugStreamController.add("disconnecting $serialNumber");
    } else
      debugStreamController.add("$serialNumber not connected");
  }

  bool _matchDevice(ScanResult scanResult, String serialNumber) {
    // companyID 2B
    // prefix 2B
    // imei 16B

    final companyID_hex = 'FFFF';
    //final prefix_hex = '063C';
    //final prefix_int = 1596;

    final List<int> imei = scanResult.advertisementData
        .manufacturerData[int.parse(companyID_hex, radix: 16)];

    if (imei == null || imei.isEmpty) return false;
    final imei_fix = imei.where(
        (byte) => byte >= '0'.codeUnitAt(0) && byte <= '9'.codeUnitAt(0));
    // Fixme: Temp fix for hw bug

    // return imei.map((byte) => String.fromCharCode(byte)).toList().join() == serialNumber;
    return serialNumber.contains(
        imei_fix.map((byte) => String.fromCharCode(byte)).toList().join());
  }

  Function _onConnectionStateChanged(
      String serialNumber, ScanResult scanResult) {
    return (BluetoothDeviceState state) {
      debugStreamController
          .add("\t$serialNumber _onConnectionStateChanged $state");

      if (state == BluetoothDeviceState.connected) {
        this.connectedDevices[serialNumber] = scanResult;
        debugStreamController.add(
            "connected $serialNumber, total: ${this.connectedDevices.keys.toList().length}");
      }

      if (state == BluetoothDeviceState.disconnected) {
        this.connectedDevices.remove(serialNumber);
        debugStreamController.add(
            "disconnected $serialNumber, total: ${this.connectedDevices.keys.toList().length}");
      }

      this.streamController.add(this.connectedDevices.keys.toList());
    };
  }
}
