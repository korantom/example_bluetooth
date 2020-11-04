import 'dart:core';
import 'dart:developer';

import 'package:example_bluetooth/service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'device_screen.dart';

class MainScreen extends StatelessWidget {
  final serialNumberController = TextEditingController(text: "1596352656100528929");

  DeviceBluetoothService service = DeviceBluetoothService();

  @override
  Widget build(BuildContext context) {
    FlutterBlue.instance.startScan();
    print("App started scanning");
    return Material(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text("Main"),
          trailing: _scanButton(),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _connected_device_list(),
                    ),
                    Placeholder(
                      fallbackWidth: 1,
                    ),
                    Expanded(
                      child: _scanned_device_list(),
                    ),
                  ],
                ),
              ),
              _connected_count(),
              Container(
                color: Colors.limeAccent,
                padding: const EdgeInsets.all(20.0),
                child: _connect_to_form(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanButton() {
    return StreamBuilder<bool>(
      stream: FlutterBlue.instance.isScanning,
      initialData: false,
      builder: (c, snapshot) {
        if (snapshot.data) {
          return CupertinoButton(
            child: Icon(
              Icons.bluetooth_searching,
              color: Colors.blue,
            ),
            onPressed: () => FlutterBlue.instance.stopScan(),
          );
        } else {
          return CupertinoButton(
            child: Icon(
              Icons.bluetooth_searching,
              color: Colors.black,
            ),
            onPressed: () => FlutterBlue.instance.startScan(),
          );
        }
      },
    );
  }

  Widget _connected_count() {
    return StreamBuilder<List<BluetoothDevice>>(
        stream: Stream.periodic(Duration(seconds: 1))
            .asyncMap((_) => FlutterBlue.instance.connectedDevices),
        initialData: [],
        builder: (c, snapshot) {
          return Text("Connected bluetooth devices: ${snapshot.data.length}");
        });
  }

  Widget _connected_device_list() {
    return StreamBuilder<List<BluetoothDevice>>(
      stream: Stream.periodic(Duration(seconds: 1))
          .asyncMap((_) => FlutterBlue.instance.connectedDevices),
      initialData: [],
      builder: (c, snapshot) {
        final connectedDevicesList = snapshot.data;
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: connectedDevicesList.length,
          itemBuilder: (BuildContext context, int index) {
            final device = connectedDevicesList[index];
            return ConnectedDeviceTileCard(
              device: device,
              onTap: () async {
                await device.disconnect();
                print("Device disconnected");
              },
            );
          },
          separatorBuilder: (BuildContext context, int index) => Divider(),
        );
      },
    );
  }

  Widget _scanned_device_list() {
    return StreamBuilder<List<ScanResult>>(
      stream: FlutterBlue.instance.scanResults,
      // .map(
      // (List<ScanResult> scanResults) => scanResults
      //     .where(
      //         (ScanResult scanResult) => scanResult.device.name.isNotEmpty)
      //     .toList()),
      initialData: [],
      builder: (c, snapshot) {
        final scanResultList = snapshot.data;
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: scanResultList.length,
          itemBuilder: (BuildContext context, int index) {
            final scanResult = scanResultList[index];
            return ScanResultTileCard(
              scanResult: scanResult,
              onTap: () async {
                await scanResult.device.connect();
                print('Device connected');
              },
            );
          },
          separatorBuilder: (BuildContext context, int index) => Divider(),
        );
      },
    );
  }

  Widget _connect_to_form(BuildContext context) {
    return Form(
      child: Column(
        children: <Widget>[
          Text('Connect by ID'),
          TextFormField(
            controller: serialNumberController,
          ),
          ElevatedButton(
            child: Text('Connect'),
            onPressed: () {
              service.scanAndConnect(serialNumberController.text).then((value) {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                  return DeviceScreen(serialNumberController.text, service);
                }));
              }).catchError((e) {
                print(e);
              showDialog(
                context: context,
                child: AlertDialog(
                  title: Text('Error'),
                  content: Text('${serialNumberController.text} cannot be connected'),
                )
              );
              });
            },
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////

class ScanResultTileCard extends StatelessWidget {
  final ScanResult scanResult;
  final VoidCallback onTap;
  const ScanResultTileCard({@required this.scanResult, this.onTap});

  Widget build(BuildContext context) {
    return TileCard(
      onTap: onTap,
      child: ListTile(
        title: Text(
            scanResult.device.name.isEmpty ? 'Unknow' : scanResult.device.name),
        subtitle: Text(
          scanResult.advertisementData.manufacturerData[65535]
                  ?.map((byte) => String.fromCharCode(byte))
                  ?.toList()
                  ?.join() ??
              "no advert data",
        ),
      ),
    );
  }
}

class ConnectedDeviceTileCard extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;
  const ConnectedDeviceTileCard({@required this.device, this.onTap});

  Widget build(BuildContext context) {
    return TileCard(
      onTap: onTap,
      child: ListTile(
        title: Text(device.name.isEmpty ? 'Unknow' : device.name),
        subtitle: Text(device.id.id),
      ),
    );
  }
}

class TileCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const TileCard({@required this.child, this.onTap});

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        child: Padding(padding: const EdgeInsets.all(10.0), child: child),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
