import 'dart:async';

import 'package:flutter_blue/flutter_blue.dart';

class DeviceBluetoothService {
  bool isScanning = false;

  StreamSubscription subScan;
  StreamSubscription subScanResults;
  StreamSubscription subDevice;

  DeviceBluetoothService() {
    subScan = FlutterBlue.instance.isScanning.listen((isScanning) => this.isScanning = isScanning);
  }

  void close() {
    subScan.cancel();
    if (subScanResults != null) {
      subScanResults.cancel();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  // ignore: close_sinks
  final StreamController<List<String>> streamController = StreamController<List<String>>.broadcast();

  // ignore: close_sinks
  final StreamController<String> debugStreamController = StreamController<String>.broadcast();

  Stream<List<String>> get stream => streamController.stream;
  Stream<String> get debugStream => debugStreamController.stream;

  //////////////////////////////////////////////////////////////////////////////

  final Map<String, BluetoothDevice> connectedDevices = {};
  List<ScanResult> scanResults = [];

  Map<String, StreamSubscription<List<ScanResult>>> _scanListenerMap = Map<String, StreamSubscription<List<ScanResult>>>();
  Map<String, StreamSubscription<BluetoothDeviceState>> _connectionStateListenerMap =
      Map<String, StreamSubscription<BluetoothDeviceState>>();

  //////////////////////////////////////////////////////////////////////////////

  Future<void> scanAndConnect(String serialNumber) async {
    debugStreamController.add("Searching for to $serialNumber");
    if (!isScanning) {
      FlutterBlue.instance.startScan();
    }

    subScanResults = FlutterBlue.instance.scanResults.listen((List<ScanResult> scanResultList) async {
      ScanResult result = scanResultList.firstWhere((ScanResult scanResult) => _matchDevice(scanResult, serialNumber), orElse: () => null);
      if (result != null) debugStreamController.add("Found $serialNumber in scan list");
      if (result != null && !connectedDevices.values.any((device) => device == result.device)) {
        subDevice = result.device.state.listen(_onConnectionStateChanged(serialNumber, result));
        await connect(serialNumber, result);
        if (subScanResults != null) {
          subScanResults.cancel();
        }
        if (isScanning) {
          FlutterBlue.instance.stopScan();
        }
        print('Connected devices:');
        FlutterBlue.instance.connectedDevices.then((devices) => devices.forEach((device) => print(device)));
      }
      return null;
    });
  }

  Future<void> connect(String serialNumber, ScanResult scanResult) {
    debugStreamController.add("Connecting to $serialNumber");
    return scanResult.device.connect().then((value) {
      connectedDevices[serialNumber] = scanResult.device;
      scanResult.device.state.listen((state) => print('Device ${scanResult.device.id} state: $state'));
    }).catchError((error) {
      print(error);
    });
  }

  Future<void> disconnect(String serialNumber) {
    if (connectedDevices[serialNumber] != null) {
      debugStreamController.add("disconnecting $serialNumber");
      return connectedDevices[serialNumber].disconnect()
          .then((value) {
            if (subDevice != null) subDevice.cancel();
            return null;
          })
          .catchError((error) {
            print(error);
            throw error;
          });
    } else {
      debugStreamController.add("$serialNumber not connected");
      return null;
    }
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

  Function _onConnectionStateChanged(String serialNumber, ScanResult scanResult) {
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
