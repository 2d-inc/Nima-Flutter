import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ik/aim_controller.dart';
import 'package:nima/nima_actor.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(primarySwatch: Colors.blue),
      home: new MyHomePage(title: 'Flutter + Nima IK'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _animationName = "run";
  AimController _oldManController = new AimController();

  void _pointerMove(PointerMoveEvent details) {
	  _oldManController.touchScreen(new Offset(details.position.dx, details.position.dy));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        backgroundColor: Colors.grey,
        appBar: new AppBar(title: new Text(widget.title)),
        body: new Listener(
          onPointerMove: _pointerMove,
          child: new Stack(children: <Widget>[
            new Positioned.fill(
                child: NimaActor("assets/Old Man",
                    alignment: Alignment.center,
                    fit: BoxFit.contain,
                    controller: _oldManController,
                    animation: _animationName,
                    mixSeconds: 0.5, completed: (String animationName) {
              setState(() {
                // Return to run.
                _animationName = "run";
              });
            })),
            new Positioned.fill(
                child: new Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    margin: const EdgeInsets.all(5.0),
                    child: new FlatButton(
                        child: new Text("Jump"),
                        textColor: Colors.white,
                        color: Colors.blue,
                        onPressed: () {
                          setState(() {
                            _animationName = "jump";
                          });
                        }))
              ],
            ))
          ]),
        ));
  }
}
