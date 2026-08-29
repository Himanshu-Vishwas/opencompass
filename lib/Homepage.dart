import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:magnetic_declination/magnetic_declination.dart';
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
  String _currentAddress = "Click to see Location";
  double _heading = 0.0;
  double? _accuracy;
  bool _hasInitialHeading = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _isCameraEnabled = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;
  bool _useTrueNorth = false;
  double _declination = 0.0;
  bool _isBearingLocked = false;
  bool _isFlashlightOn = false;
  bool _isVibrationEnabled = true;
  DateTime? _lastVibrateTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCompass();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage("assets/images/degrees.png"), context);
    precacheImage(const AssetImage("assets/images/needle2.png"), context);
  }

  Future<void> _initCamera() async {
    if (_isCameraInitializing || _cameraController != null) return;
    _isCameraInitializing = true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _isCameraInitializing = false;
        return;
      }

      // Verify controller is still null before initializing
      if (_cameraController != null) {
        _isCameraInitializing = false;
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _cameraController = controller;

      await controller.initialize();

      if (mounted && _isCameraEnabled && _cameraController == controller) {
        setState(() {
          _isCameraInitialized = true;
        });
      } else {
        // Clean up if either unmounted, disabled by user or replaced
        controller.dispose();
        if (_cameraController == controller) {
          _cameraController = null;
        }
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
      if (mounted) {
        setState(() {
          _isCameraEnabled = false;
          _isCameraInitialized = false;
          _cameraController = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera access is required for camera background.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isCameraInitializing = false;
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    _isFlashlightOn = false;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraEnabled) return;

    if (state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      if (_isBearingLocked) return;

      double target = event.heading!;
      if (_useTrueNorth) {
        target = (target + _declination) % 360;
      }

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

            // Normalize _heading to [-180, 180) to prevent infinite drift while keeping rotation smooth
            _heading = (_heading + 180) % 360;
            if (_heading < 0) {
              _heading += 360;
            }
            _heading -= 180;
          }

          double normalizedHeading = (_heading % 360 + 360) % 360;
          if (_isVibrationEnabled && (normalizedHeading <= 3 || normalizedHeading >= 357)) {
            if (_lastVibrateTime == null || DateTime.now().difference(_lastVibrateTime!).inMilliseconds > 1200) {
              HapticFeedback.vibrate();
              _lastVibrateTime = DateTime.now();
            }
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
      if (mounted) {
        bool? shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Location Access", style: TextStyle(color: Colors.white)),
            content: const Text(
              "Open Compass needs location access to calculate True North and show your altitude/coordinates. Your data never leaves your device.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Not Now", style: TextStyle(color: Colors.redAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Continue", style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
        );

        if (shouldRequest != true) {
          setState(() => _currentAddress = "Permission denied");
          return;
        }
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentAddress = "Permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _currentAddress = "Permission permanently denied");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location permission in app settings')));
      }
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      double declination = await MagneticDeclination.calculateDeclination(position.latitude, position.longitude, position.altitude, DateTime.now());
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = "${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°";
          _declination = declination;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E1E1E),
            onSelected: (value) {
              HapticFeedback.selectionClick();
              if (value == 'vibration') {
                setState(() {
                  _isVibrationEnabled = !_isVibrationEnabled;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVibrationEnabled ? 'Vibration on North Enabled' : 'Vibration Disabled'), duration: const Duration(seconds: 1)));
              } else if (value == 'bearing_lock') {
                setState(() {
                  _isBearingLocked = !_isBearingLocked;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isBearingLocked ? 'Bearing Locked' : 'Bearing Unlocked'), duration: const Duration(seconds: 1)));
              } else if (value == 'true_north') {
                setState(() {
                  _useTrueNorth = !_useTrueNorth;
                });
                if (_useTrueNorth) {
                  _determinePosition();
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_useTrueNorth ? 'True North Enabled' : 'Magnetic North Enabled'), duration: const Duration(seconds: 1)));
              } else if (value == 'info') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const Info()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'vibration',
                child: Row(
                  children: [
                    Icon(_isVibrationEnabled ? Icons.vibration : Icons.mobile_off, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Text('Vibration on North', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'bearing_lock',
                child: Row(
                  children: [
                    Icon(_isBearingLocked ? Icons.lock : Icons.lock_open, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Text('Bearing Lock', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'true_north',
                child: Row(
                  children: [
                    Icon(_useTrueNorth ? Icons.explore : Icons.explore_off, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Text('True North', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Info', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
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
            child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
          ),
          Positioned(
            left: 24,
            bottom: isLandscape ? 24 : 110,
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                if (_cameraController != null && _isCameraInitialized) {
                  _isFlashlightOn = !_isFlashlightOn;
                  await _cameraController!.setFlashMode(_isFlashlightOn ? FlashMode.torch : FlashMode.off);
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable camera mode (bottom right icon) to use flashlight.'), duration: Duration(seconds: 2)));
                }
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
                  _isFlashlightOn ? Icons.highlight : Icons.highlight_outlined,
                  color: _isFlashlightOn ? Colors.amberAccent : Colors.white70,
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: isLandscape ? 24 : 110,
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
          _buildCalibrationPrompt(isLandscape),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
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
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: _buildCompassDisk(isLandscape: true),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDirectionHeader(),
                  const SizedBox(height: 20),
                  _buildLocationCard(isLandscape: true),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLeveler(),
                        Column(
                          children: [
                            _buildInfoTile("ACCURACY", "${_accuracy?.toStringAsFixed(0) ?? '0'}°"),
                            const SizedBox(height: 16),
                            _buildInfoTile("MAG. FIELD", "48μT"),
                            const SizedBox(height: 16),
                            _buildInfoTile("STATUS", _accuracy != null ? "READY" : "CALIB."),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard({bool isLandscape = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isLandscape ? 10 : 30),
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
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPosition == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Getting your location...')),
                            );
                            _determinePosition();
                          }
                        },
                        child: Text(_currentAddress, overflow: TextOverflow.ellipsis, style: TextStyle(color: _currentPosition == null ? Colors.blueAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_currentPosition != null)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: "${_currentPosition!.latitude}, ${_currentPosition!.longitude}"));
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates copied to clipboard', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: Duration(seconds: 1)));
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.copy, color: Colors.white54, size: 14),
                        ),
                      ),
                  ],
                ),
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

  Widget _buildCalibrationPrompt(bool isLandscape) {
    bool needsCalibration = _heading == 0.0 || _accuracy == null;
    if (!needsCalibration) return const SizedBox.shrink();

    return Positioned(
      bottom: isLandscape ? 20 : 160,
      left: isLandscape ? 20 : 30,
      right: isLandscape ? null : 30,
      width: isLandscape ? 320 : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: needsCalibration ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xE60F0F0F), // Solid rich dark background matching scaffold with 90% opacity to prevent transparent clashing
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.screen_rotation_outlined, color: Colors.amberAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "CALIBRATION RECOMMENDED",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Wave your phone in a figure-8 motion for better accuracy.",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
              "${((_heading.round() + 360) % 360).toInt()}°",
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

  Widget _buildCompassDisk({bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 10.0 : 50.0),
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
    int h = (heading.round() + 360) % 360;
    if (h == 0 || h == 90 || h == 180 || h == 270) return Colors.redAccent;
    return Colors.white;
  }
}
