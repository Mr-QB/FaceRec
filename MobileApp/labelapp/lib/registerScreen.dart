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
  bool _isUsingFrontCamera = false;
  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  List<File> _capturedImagesFiles = [];
  int _currentStep = 0;
  List<Rect> boundingBoxes = [];
  Timer? _timer;
  late String imageID;

  final List<String> _instructions = [
    'Look Straight',
    // 'Turn Left',
    // 'Turn Right',
    // 'Look Up',
    // 'Look Down',
    // 'Tilt Head Left',
    // 'Tilt Head Up Left',
    // 'Tilt Head Down Left',
    // 'Tilt Head Right',
    // 'Tilt Head Up Right',
    // 'Tilt Head Down Right',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[0]);
    _startTimer();
    imageID = _generateTimestampID();
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

  Future<bool> _sentSignalTrainning(BuildContext context) async {
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
    faceDetector.close();
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
        if (await _sendImagesToServer(imageFile, imageID)) {
          imageID = _generateTimestampID();
          _currentStep++;
        }
        if (_currentStep == _instructions.length) {
          _timer?.cancel();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(cameras: widget.cameras),
            ),
          );
          await _sentSignalTrainning(context);
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
    final List<Face> faces = await faceDetector.processImage(inputImage);

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

  void _switchCamera() {
    final cameraDescription =
        _isUsingFrontCamera ? widget.cameras[0] : widget.cameras[1];
    setState(() {
      _isUsingFrontCamera = !_isUsingFrontCamera;
      _initializeCameraController(cameraDescription);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera'),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _instructions[_currentStep],
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                      SizedBox(height: 10),
                      FloatingActionButton(
                        child: Icon(Icons.camera),
                        onPressed: () => _takePicture(context),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
