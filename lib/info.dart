import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Constants.dart';
class Info extends StatefulWidget {
  const Info({super.key});

  @override
  State<Info> createState() => _InfoState();
}

final Uri _url = Uri.parse("https://github.com/Himanshu-Vishwas/opencompass");

class _InfoState extends State<Info> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Info",style: TextStyle(color: Colors.white,fontSize: 20),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("This is an open source Compass app for android. You can also contribute to the app.\nThis open-source Compass app for Android offers users a reliable tool for directional orientation. With a user-friendly interface, it facilitates easy navigation. Contributions are welcome from developers of all levels to enhance features, fix bugs, improve UI/UX, optimize performance, localize, document, test, ensure accessibility, and shape its future. By joining the community, contributors can improve the app's functionality and usability, benefiting users worldwide.",style: TextStyle(color: Colors.white)),
                SizedBox(height: 10,),
                TextButton(onPressed: (){
                  _launchUrl();
                }, child: Text("Contribute here",style: TextStyle(color: Colors.black),),style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
                ),),
                SizedBox(height: 40,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.star_border,color: Colors.white,),Icon(Icons.star_border,color: Colors.white,),Icon(Icons.star_border,color: Colors.white,),],
                ),
                SizedBox(height: 10,),
                Text("CONTRIBUTORS", style: TextStyle(color: Colors.white),),
                SizedBox(height: 20,),
                Column(
                  //contributors list
                  children: [
                    Text("Himanshu",style: TextStyle(color: Colors.white),),

                  ],
                ),
                SizedBox(height: 50,),
                Text("version: ${Constants.version}",style: TextStyle(color: Colors.white),)
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }
}
