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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Open Compass",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "This is an open source Compass app for android. You can also contribute to the app.\n\nThis open-source Compass app for Android offers users a reliable tool for directional orientation. With a user-friendly interface, it facilitates easy navigation. Contributions are welcome from developers of all levels to enhance features, fix bugs, improve UI/UX, optimize performance, localize, document, test, ensure accessibility, and shape its future. By joining the community, contributors can improve the app's functionality and usability, benefiting users worldwide.",
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () => _launchUrl(),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    ),
                    child: const Text(
                      "Contribute here",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 50),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border, color: Colors.white38),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.star_border, color: Colors.white70),
                      ),
                      Icon(Icons.star_border, color: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "CONTRIBUTORS",
                    style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Column(
                    children: [
                      Text(
                        "Himanshu",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Text(
                    "version: ${Constants.version}",
                    style: const TextStyle(color: Colors.white24, fontSize: 12),
                  )
                ],
              ),
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
