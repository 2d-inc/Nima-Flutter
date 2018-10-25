import 'package:flutter/material.dart';
import "package:nima/nima_actor.dart";

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'JSON Reader Demo',
      theme: new ThemeData(primarySwatch: Colors.blue),
      home: new MyHomePage(title: 'Nima-Flutter with JSON'),
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
  String _animationName = "Constraint";

  @override
    Widget build(BuildContext context) {
        return new Scaffold(
            backgroundColor: Colors.grey,
            appBar: new AppBar(title: new Text(widget.title)),
            body: new Center(
                child: new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: 
                    [
                        Expanded(
                            child: NimaActor("assets/SlidingSolo.nmj",
                                alignment: Alignment.center,
                                fit: BoxFit.contain,
                                animation: _animationName,
                            )
                        )
                    ],
                ),
            )
        );
    }
}
