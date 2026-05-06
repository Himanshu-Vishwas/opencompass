import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:opencompass/info.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLevel = false;
  Position? _currentPosition;
  String _currentAddress = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentAddress = "Location services disabled");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentAddress = "Permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentAddress = "Permission permanently denied");
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = "${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Open Compass",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.push(context, MaterialPageRoute(builder: (context) => const Info()));
            },
            icon: const Icon(Icons.info_outline, color: Colors.white70),
          )
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildDirectionHeader(),
                const Spacer(flex: 2),
                _buildCompassDisk(),
                const Spacer(flex: 2),
                _buildLocationCard(),
                const SizedBox(height: 15),
                _buildLeveler(),
                const Spacer(flex: 1),
                _buildBottomStats(),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.redAccent.withOpacity(0.8), size: 18),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CURRENT LOCATION", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_currentAddress, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              ],
            ),
          ),
          if (_currentPosition != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("ALTITUDE", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("${_currentPosition!.altitude.toInt()}m", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLeveler() {
    return StreamBuilder<AccelerometerEvent>(
      stream: accelerometerEventStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 80);

        double x = snapshot.data!.x;
        double y = snapshot.data!.y;

        double ballX = (x / 10) * 35;
        double ballY = (y / 10) * 35;

        bool levelNow = x.abs() < 0.2 && y.abs() < 0.2;
        if (levelNow && !_isLevel) {
          HapticFeedback.selectionClick();
          _isLevel = true;
        } else if (!levelNow) {
          _isLevel = false;
        }

        return Column(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 1, height: 80, color: Colors.white.withOpacity(0.05)),
                  Container(width: 80, height: 1, color: Colors.white.withOpacity(0.05)),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    child: Transform.translate(
                      offset: Offset(ballX, ballY),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: levelNow ? Colors.greenAccent : Colors.white60,
                          boxShadow: [
                            if (levelNow) BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text("LEVELER", style: TextStyle(color: levelNow ? Colors.greenAccent : Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundGlow() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        double heading = snapshot.data?.heading ?? 0;
        Color accentColor = _getAccentColor(heading);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [accentColor.withOpacity(0.08), Colors.transparent],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectionHeader() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        double heading = snapshot.data?.heading ?? 0;
        String direction = _getDirection(heading);
        Color accentColor = _getAccentColor(heading);
        return Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  direction.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [Shadow(color: accentColor.withOpacity(0.4), blurRadius: 30)],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${heading.ceil()}°",
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w200, letterSpacing: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompassDisk() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        double heading = snapshot.data?.heading ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                    gradient: RadialGradient(
                      colors: [Colors.white.withOpacity(0.02), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: ((heading * (pi / 180) * -1) + (pi / 2)),
                child: Image.asset("assets/images/degrees.png", cacheWidth: 1000, color: Colors.white.withOpacity(0.85)),
              ),
              Positioned(
                top: 5,
                child: Container(
                  width: 3, height: 25,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)],
                  ),
                ),
              ),
              Image.asset("assets/images/needle2.png", width: 120, color: Colors.white),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomStats() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoTile("ACCURACY", "${snapshot.data?.accuracy?.toStringAsFixed(0) ?? '0'}°"),
              _buildInfoTile("MAG. FIELD", "48μT"),
              _buildInfoTile("STATUS", snapshot.data?.accuracy != null ? "READY" : "CALIB."),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  String _getDirection(double heading) {
    if (heading > -22.5 && heading <= 22.5) return "North";
    if (heading > 22.5 && heading <= 67.5) return "North East";
    if (heading > 67.5 && heading <= 112.5) return "East";
    if (heading > 112.5 && heading <= 157.5) return "South East";
    if (heading > 157.5 || heading <= -157.5) return "South";
    if (heading > -157.5 && heading <= -112.5) return "South West";
    if (heading > -112.5 && heading <= -67.5) return "West";
    if (heading > -67.5 && heading <= -22.5) return "North West";
    return "N";
  }

  Color _getAccentColor(double heading) {
    int h = heading.ceil();
    if (h == 0 || h == 90 || h == 180 || h == -90) return Colors.redAccent;
    return Colors.white;
  }
}
