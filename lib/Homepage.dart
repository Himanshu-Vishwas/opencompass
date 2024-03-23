import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:opencompass/info.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double heading=0;
  String direction = "Unknown";
  Color color = Colors.white;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    FlutterCompass.events!.listen((event) {
      setState(() {
        heading = event.heading!;
        if(heading.ceil()==0 || heading.ceil() == 90 || heading.ceil()==180||heading.ceil()==-90){
          color = Colors.lightGreenAccent;
        }else{
          color = Colors.white;
        }
        if (heading > -45 && heading <= 45) {
          direction = "North";
        } else if (heading > 45 && heading <= 135) {
          direction = "East";
        } else if (heading > 135 || heading <= -135) {
          direction = "South";
        } else if (heading > -135 && heading <= -45) {
          direction = "West";
        }

      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Open Compass",style: TextStyle(color: Colors.white,fontSize: 26,fontWeight: FontWeight.bold),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context)=>Info()));
          }, icon: Icon(Icons.info,color: Colors.white,))
        ],
      ),
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("$direction",style: TextStyle(color: color,fontSize: 33,fontWeight: FontWeight.bold),),
              SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(angle: pi/2,child:
                    Image.asset("assets/images/degrees.png"),),
                    Transform.rotate(angle: ((heading ?? 0 )*(pi/180)*-1 ),
                    child: Image.asset("assets/images/needle2.png",scale: 1.1,color: Colors.white,))
                  ],
                ),
              ),
              SizedBox(height: 20,),
              Text("${heading.ceil()}°",style: TextStyle(color: color,fontSize: 50,fontWeight: FontWeight.bold),),
            ],
          ),
        ),
      ),
    );
  }
}
