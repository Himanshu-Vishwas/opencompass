import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:opencompass/info.dart';
import 'package:camera/camera.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isLevel = false;
  Position? _currentPosition;
  String _currentAddress = "Fetching location...";
  double _heading = 0.0;
  double? _accuracy;
  bool _hasInitialHeading = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _isCameraEnabled = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determinePosition();
    _initCompass();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage("assets/images/degrees.png"), context);
    precacheImage(const AssetImage("assets/images/needle2.png"), context);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_isCameraEnabled) return;

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      double target = event.heading!;
      if (mounted) {
        setState(() {
          if (!_hasInitialHeading) {
            _heading = target;
            _hasInitialHeading = true;
          } else {
            double diff = target - _heading;
            while (diff < -180) {
              diff += 360;
            }
            while (diff > 180) {
              diff -= 360;
            }
            _heading += diff * 0.15;
          }
          _accuracy = event.accuracy;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _disposeCamera();
    super.dispose();
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
          if (_isCameraEnabled && _isCameraInitialized && _cameraController != null) ...[
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1080,
                  height: _cameraController!.value.previewSize?.width ?? 1920,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            Container(
              color: Colors.black.withOpacity(0.25),
            ),
          ],
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
          Positioned(
            right: 24,
            bottom: 110,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_isCameraEnabled) {
                  _disposeCamera();
                  _isCameraEnabled = false;
                } else {
                  _isCameraEnabled = true;
                  _initCamera();
                }
                setState(() {});
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isCameraEnabled ? Icons.videocam : Icons.videocam_off_outlined,
                  color: _isCameraEnabled ? Colors.greenAccent : Colors.white70,
                  size: 20,
                ),
              ),
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
    Color accentColor = _getAccentColor(_heading);
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
  }

  Widget _buildDirectionHeader() {
    String direction = _getDirection(_heading);
    Color accentColor = _getAccentColor(_heading);
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
              "${_heading.ceil()}°",
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
  }

  Widget _buildCompassDisk() {
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
            angle: ((_heading * (pi / 180) * -1) + (pi / 2)),
            child: Image.asset("assets/images/degrees.png", cacheWidth: 600, color: Colors.white.withOpacity(0.85)),
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
  }

  Widget _buildBottomStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoTile("ACCURACY", "${_accuracy?.toStringAsFixed(0) ?? '0'}°"),
          _buildInfoTile("MAG. FIELD", "48μT"),
          _buildInfoTile("STATUS", _accuracy != null ? "READY" : "CALIB."),
        ],
      ),
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
