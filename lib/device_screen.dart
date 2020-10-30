import 'dart:core';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'service.dart';

class DeviceScreen extends StatelessWidget {
  final String serialNumber;

  const DeviceScreen(this.serialNumber);

  @override
  Widget build(BuildContext context) {
    DeviceBluetoothService.service.connect(serialNumber);

    return Material(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text("Device"),
        ),
        child: SafeArea(child: _content()),
      ),
    );
  }

  Widget _content() {
    List<String> debugMessages = [];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("device: $serialNumber"),
          StreamBuilder<List<String>>(
              stream: DeviceBluetoothService.stream,
              initialData: [],
              builder: (c, snapshot) {
                bool connected = snapshot.data.contains(this.serialNumber);
                return Text("Connected $connected");
              }),
          SizedBox(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                  child: Text('Connect'),
                  onPressed: () {
                    DeviceBluetoothService.service.connect(this.serialNumber);
                  }),
              ElevatedButton(
                  child: Text('Disconnect'),
                  onPressed: () {
                    DeviceBluetoothService.service
                        .disconnect(this.serialNumber);
                  }),
            ],
          ),
          SizedBox(),
          Expanded(
            child: StreamBuilder<String>(
                stream: DeviceBluetoothService.debugStream,
                initialData: "",
                builder: (c, snapshot) {
                  debugMessages.insert(0, snapshot.data);
                  return ListView.separated(
                    itemCount: debugMessages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(
                          "${debugMessages.length - index}: ${debugMessages[index]}",
                          style: TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(),
                  );
                }),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////

class DeviceScreen2 extends StatelessWidget {
  const DeviceScreen2({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                ),
            ),
          ],
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////
