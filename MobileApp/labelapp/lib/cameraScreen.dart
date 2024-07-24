import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'galleryScreen.dart';
import 'config.dart';

class CameraScreen extends StatefulWidget {
  final String userName;
  // final List<CameraDescription> cameras;
  CameraScreen({required this.userName});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isUsingFrontCamera = false;
  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  List<File> _capturedImagesFiles = [];
  late List<CameraDescription> _cameras;
  int _currentStep = 0;
  List<Rect> boundingBoxes = [];
  Timer? _timer;

  final List<String> _instructions = [
    'Look Straight',
    // 'Turn Left',
    // 'Turn Right',
    'Look Up',
    'Look Down'
  ];

  @override
  void initState() {
    super.initState();
    _initializeCameras();
    _startTimer();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isNotEmpty) {
        final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras[0],
        );

        _initializeCameraController(frontCamera);
      } else {
        print("No cameras available.");
      }
    } catch (e) {
      print('Error initializing cameras: $e');
    }
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

  Future<void> _sendImagesToServer(List<File> imageFiles) async {
    try {
      final List<String> base64Images = [];
      for (var imageFile in imageFiles) {
        final base64Image = await _convertImageToBase64(imageFile);
        base64Images.add(base64Image);
      }

      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/pushimages"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'images': base64Images, 'userName': widget.userName}),
      );
      if (response.statusCode == 200) {
        print('Images uploaded successfully');
      } else {
        print('Failed to upload images');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> _takePicture(BuildContext context) async {
    try {
      await _initializeControllerFuture;
      print("Camera initialized");

      final image = await _controller.takePicture();
      final imageFile = File(image.path);

      final faces = await _detectFaces(image);
      boundingBoxes = _getBoundingBox(faces);
      final faceDetected = await _checkFaceAngles(faces);
      print("Face detected: $faceDetected");

      if (faceDetected) {
        _currentStep++;
        _capturedImagesFiles.add(imageFile);
        if (_currentStep >= _instructions.length) {
          await _sendImagesToServer(_capturedImagesFiles);
          _timer?.cancel();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GalleryScreen(),
            ),
          );
        } else {
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Face is not at the correct angle. Please try again.')),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  Future<List<Face>> _detectFaces(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final List<Face> faces = await faceDetector.processImage(inputImage);
    return faces;
  }

  bool _checkFaceAngles(List<Face> faces) {
    final face = faces.first;
    final headEulerAngleY = face.headEulerAngleY;
    final headEulerAngleZ = face.headEulerAngleZ;
    final headEulerAngleX = face.headEulerAngleX;

    switch (_currentStep) {
      case 0: // Straight
        return headEulerAngleY!.abs() < 10 && headEulerAngleZ!.abs() < 10;
      case 1: // Left
        return headEulerAngleY! > 20;
      case 2: // Right
        return headEulerAngleY! < -20;
      case 3: // Up
        return headEulerAngleX! > 10; // Tilt head up
      case 4: // Down
        return headEulerAngleX! < -10; // Tilt head down
      default:
        return false;
    }
  }

  List<Rect> _getBoundingBox(List<Face> faces) {
    List<Rect> boundingBoxes = [];
    for (Face face in faces) {
      final boundingBox = face.boundingBox;
      boundingBoxes.add(boundingBox);
    }

    return boundingBoxes;
  }

  void _switchCamera() {
    if (_cameras.isNotEmpty) {
      final cameraDescription = _isUsingFrontCamera ? _cameras[1] : _cameras[0];
      setState(() {
        _isUsingFrontCamera = !_isUsingFrontCamera;
        _initializeCameraController(cameraDescription);
      });
    }
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
                // ...boundingBoxes.map((rect) {
                //   return Positioned(
                //     left: rect.left,
                //     top: rect.top,
                //     width: rect.width,
                //     height: rect.height,
                //     child: Container(
                //       decoration: BoxDecoration(
                //         border: Border.all(color: Colors.red, width: 2),
                //       ),
                //     ),
                //   );
                // }).toList(),
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
