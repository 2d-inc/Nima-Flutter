import 'package:flutter/material.dart';
import 'package:nima/nima_actor.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        primarySwatch: Colors.blue
      ),
      home: new MyHomePage(title: 'Flutter + Nima'),
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
  String _animationName = "idle";

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
		backgroundColor: Colors.grey,
		appBar: new AppBar(
			title: new Text(widget.title)
		),
		body: new Stack(
			children: <Widget>[
			  	new Positioned.fill(
					child: NimaActor("assets/Hop", alignment:Alignment.center, fit:BoxFit.contain, animation:_animationName, mixSeconds:0.5, completed:(String animationName)
					{
						setState(()
						{
							// Return to idle.
							_animationName = "idle";
						});
					})
				),
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
									onPressed:() 
									{
										setState(() 
										{
											_animationName = "jump";
										});
									}
								)
							),
						  new Container(
								margin: const EdgeInsets.all(5.0), 
								child: new FlatButton(
									child: new Text("Attack"), 
									textColor: Colors.white, 
									color: Colors.blue, 
									onPressed:() 
									{
										setState(() 
										{
											_animationName = "attack";
										});
									}
								)
							),
				  		],
					)
				)
		  ]
      )
    );
  }
}
