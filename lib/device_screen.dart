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
