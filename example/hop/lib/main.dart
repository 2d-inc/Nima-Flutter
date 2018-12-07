import 'package:flutter/material.dart';
import 'package:nima/nima_actor.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Flutter + Nima'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _animationName = "idle";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey,
        appBar: AppBar(title: Text(widget.title)),
        body: Stack(children: <Widget>[
          Positioned.fill(
              child: NimaActor("assets/Hop.nima",
                  alignment: Alignment.center,
                  fit: BoxFit.contain,
                  animation: _animationName,
                  mixSeconds: 0.5, completed: (String animationName) {
            setState(() {
              // Return to idle.
              _animationName = "idle";
            });
          })),
          Positioned.fill(
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                  margin: const EdgeInsets.all(5.0),
                  child: FlatButton(
                      child: Text("Jump"),
                      textColor: Colors.white,
                      color: Colors.blue,
                      onPressed: () {
                        setState(() {
                          _animationName = "jump";
                        });
                      })),
              Container(
                  margin: const EdgeInsets.all(5.0),
                  child: FlatButton(
                      child: Text("Attack"),
                      textColor: Colors.white,
                      color: Colors.blue,
                      onPressed: () {
                        setState(() {
                          _animationName = "attack";
                        });
                      })),
            ],
          ))
        ]));
  }
}
