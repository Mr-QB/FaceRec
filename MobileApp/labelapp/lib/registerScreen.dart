import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'homeScreen.dart';
import 'config.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String userName;
  CameraScreen({required this.userName, required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();
  List<File> _capturedImagesFiles = [];
  int _currentStep = 0;
  Timer? _timer;
  late String _imageID;
  late String _instructionsTitle = _instructions[_currentStep];
  final int _totalSegments = 11;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);

  final List<String> _instructions = [
    'Look Straight',
    'Turn Left',
    'Turn Right',
    'Look Up',
    'Look Down',
    'Tilt Head Left',
    'Tilt Head Up Left',
    'Tilt Head Down Left',
    'Tilt Head Right',
    'Tilt Head Up Right',
    'Tilt Head Down Right',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[1]);
    _startTimer();
    _imageID = _generateTimestampID();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _takePicture(context);
    });
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<String> _convertImageToBase64(File file) async {
    final imageBytes = await file.readAsBytes();
    return base64Encode(imageBytes);
  }

  Future<bool> _sendImagesToServer(File imageFile, String imageID) async {
    try {
      final base64Image = await _convertImageToBase64(imageFile);

      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/pushimages"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'images': base64Image,
          'userName': widget.userName,
          'imageID': imageID,
        }),
      );
      if (response.statusCode == 200) {
        print('Images uploaded successfully');
        setState(() {
          _segmentColors[_currentStep] = Colors.green;
          _currentStep++;
          _instructionsTitle = _instructions[_currentStep];
        });
        return true;
      } else {
        print('Failed to upload images');
        return false;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  Future<bool> _sendSignalTrainning(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/trainning"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': true,
        }),
      );
      if (response.statusCode == 200) {
        print('Successful training');
        showCustomToast(
          context,
          'Successful training, your face has been added to the recognition set.',
        );
        return true;
      } else {
        print('Failed to training');
        return false;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  String _generateTimestampID() {
    final now = DateTime.now();
    final formatter = DateFormat('HHmmss_MMddyyyy');
    final timestampStr = formatter.format(now);
    return timestampStr;
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  void showCustomToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16.0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<void> deleteAllCapturedImages(List<File> imageFiles) async {
    for (final file in imageFiles) {
      try {
        await file.delete();
        print("Deleted: ${file.path}");
      } catch (e) {
        print("Error deleting file: ${file.path}, Error: $e");
      }
    }
  }

  Future<void> _takePicture(BuildContext context) async {
    try {
      await _initializeControllerFuture;
      print("Camera initialized");

      final image = await _controller.takePicture();
      print("Picture taken: ${image.path}");

      final imageFile = File(image.path);
      _capturedImagesFiles.add(imageFile);

      final faces = await _detectFaces(image);
      final faceDetected = await _checkFaceAngle(faces);
      print("Face detected: $faceDetected");

      if (faceDetected) {
        if (await _sendImagesToServer(imageFile, _imageID)) {
          _imageID = _generateTimestampID();
        }
        if (_currentStep == _instructions.length) {
          _instructionsTitle = "Face scanning completed, please wait a moment";
          _timer?.cancel();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(cameras: widget.cameras),
            ),
          );
          await _sendSignalTrainning(context);
          await deleteAllCapturedImages(_capturedImagesFiles);
          _capturedImagesFiles.clear();
        } else {
          setState(() {});
        }
      } else {
        showCustomToast(
          context,
          'Face is not at the correct angle. Please try again.',
        );
      }
    } catch (e) {
      print(e);
    }
  }

  Future<List<Face>> _detectFaces(XFile image) async {
    final startTime = DateTime.now(); // start

    final inputImage = InputImage.fromFilePath(image.path);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    final endTime = DateTime.now(); // end
    final duration = endTime.difference(startTime);

    print("Time taken to detect faces: ${duration.inMilliseconds} ms");

    return faces;
  }

  bool _checkFaceAngle(List<Face> faces) {
    final face = faces.first;
    final headEulerAngleY = face.headEulerAngleY;
    final headEulerAngleZ = face.headEulerAngleZ;
    final headEulerAngleX = face.headEulerAngleX;

    print('headEulerAngleY: $headEulerAngleY');
    print('headEulerAngleZ: $headEulerAngleZ');
    print('headEulerAngleX: $headEulerAngleX');

    switch (_currentStep) {
      case 0: // Straight
        return headEulerAngleY!.abs() < 10 && headEulerAngleZ!.abs() < 10;
      case 1: // Left
        return headEulerAngleY! > 20;
      case 2: // Right
        return headEulerAngleY! < -20;
      case 3: // Up
        return headEulerAngleX! > 10;
      case 4: // Down
        return headEulerAngleX! < -10;
      case 5: // Tilt Head Left
        return headEulerAngleZ! < -10;
      case 6: // Tilt Head Up Left
        return headEulerAngleX! > 10 && headEulerAngleZ! < -10;
      case 7: // Tilt Head Down Left
        return headEulerAngleX! < -10 && headEulerAngleZ! < -10;
      case 8: // Tilt Head Right
        return headEulerAngleZ! > 10;
      case 9: // Tilt Head Up Right
        return headEulerAngleX! > 10 && headEulerAngleZ! > 10;
      case 10: // Tilt Head Down Right
        return headEulerAngleX! < -10 && headEulerAngleZ! > -10;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final circleDiameter = screenSize.width < screenSize.height
        ? screenSize.width * 0.9
        : screenSize.height * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(circleDiameter + 8.0, circleDiameter + 8.0),
                        painter: ProgressBar(
                          colors: _segmentColors,
                          segments: _totalSegments,
                        ),
                      ),
                      ClipOval(
                        child: SizedBox(
                          width: circleDiameter,
                          height: circleDiameter,
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: Transform.scale(
                              scale: _controller.value.aspectRatio /
                                  MediaQuery.of(context).size.aspectRatio *
                                  0.5,
                              child: Center(
                                child: CameraPreview(_controller),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 46.0),
                  Text(
                    _instructionsTitle,
                    // _instructions[_currentStep],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.0,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class ProgressBar extends CustomPainter {
  final List<Color> colors;
  final int segments;

  ProgressBar({required this.colors, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final radius = size.width / 2;
    final center = Offset(radius, radius);

    final segmentAngle = 2 * 3.14 / segments;
    final startAngle = -3.14 / 2;

    for (int i = 0; i < segments; i++) {
      paint.color = colors[i];
      final currentStartAngle = startAngle + i * segmentAngle;
      final sweepAngle = segmentAngle;

      final path = Path()
        ..arcTo(Rect.fromCircle(center: center, radius: radius),
            currentStartAngle, sweepAngle, false);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
