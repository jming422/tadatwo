import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = const MethodChannel('tadatwo.example.com/authnet');

  String _authNetState = 'Unknown state';
  Future<void> _initAuthNet() async {
    String authNetState;
    try {
      final bool result =
          await platform.invokeMethod('initAuthNet', <String, String>{
        'env': 'test',
        'deviceID': 'flutterexampletestingdeviceid',
        'user': userController.text,
        'pass': passController.text
      });
      authNetState = 'Authorize.Net ${result ? "" : "Not! "} Initialized.';
    } on PlatformException catch (e) {
      authNetState = "Failed to initialize: '${e.message}'.";
    }
    setState(() {
      _authNetState = authNetState;
    });
  }

  String _txnId = 'None yet';
  Future<void> _chargeIt() async {
    String txnId;
    try {
      txnId = await platform.invokeMethod('chargeIt');
    } on PlatformException catch (e) {
      txnId = "Failed to charge it: '${e.message}'.";
    }
    setState(() {
      _txnId = txnId;
    });
  }

  Future<void> _chargeBT() async {
    try {
      await platform.invokeMethod('chargeBT');
    } on PlatformException catch (e) {
      print("Failed to charge it: '${e.message}'.");
    }
  }

  final userController = TextEditingController();
  final passController = TextEditingController();

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('User:'),
            TextField(
              controller: userController,
              autocorrect: false,
            ),
            Text('Password:'),
            TextField(
              controller: passController,
              autocorrect: false,
              obscureText: true,
            ),
            RaisedButton(
              child: Text('Login'),
              onPressed: _initAuthNet,
            ),
            Text(_authNetState),
            RaisedButton(
              child: Text('Charge It!'),
              onPressed: _chargeIt,
            ),
            Text(_txnId),
            RaisedButton(
              child: Text('REALLY charge it!'),
              onPressed: _chargeBT,
            ),
          ],
        ),
      ),
    );
  }
}
