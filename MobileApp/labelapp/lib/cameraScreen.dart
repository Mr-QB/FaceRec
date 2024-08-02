import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:intl/intl.dart';
// import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'homeScreen.dart';
import 'imageSetScreen.dart';
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
  late Directory _appDir;
  List<Rect> boundingBoxes = [];
  Timer? _timer;
  late String imageID;

  final List<String> _instructions = [
    'Look Straight',
    'Turn Left',
    'Turn Right',
    'Look Up',
    'Look Down'
  ];

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[0]);
    _initializeAppDir();
    _startTimer();
    imageID = _generateTimestampID();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _takePicture(context);
    });
  }

  void _initializeAppDir() async {
    _appDir = await getApplicationDocumentsDirectory();
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

  Future<Uint8List> _readImageAsBytes(File file) async {
    return await file.readAsBytes();
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

  Future<void> _takePicture(BuildContext context) async {
    try {
      await _initializeControllerFuture;
      print("Camera initialized");

      final image = await _controller.takePicture();
      print("Picture taken: ${image.path}");

      final imageFile = File(image.path);
      _capturedImagesFiles.add(imageFile);

      final faces = await _detectFaces(image);
      boundingBoxes = _getBoundingBox(faces);
      final faceDetected = await _checkFaceAngles(faces);
      print("Face detected: $faceDetected");

      if (faceDetected) {
        if (await _sendImagesToServer(imageFile, imageID)) {
          imageID = _generateTimestampID();
          _currentStep++;
        }
        if (_currentStep == _instructions.length) {
          _timer?.cancel();
          await _sentSignalTrainning(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(cameras: widget.cameras),
            ),
          );
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

  Future<void> _saveImagesToFolder(List<String> images) async {
    final folderName = DateTime.now().millisecondsSinceEpoch.toString();
    final folder = Directory(path.join(_appDir.path, folderName));
    await folder.create();

    for (var imagePath in images) {
      final fileName = path.basename(imagePath);
      final newImagePath = path.join(folder.path, fileName);
      final imageFile = File(imagePath);
      await imageFile.copy(newImagePath);
      await GallerySaver.saveImage(newImagePath);
    }

    // Save folder path globally
    ImagePathManager().folders.add(folder.path);

    _capturedImagesFiles.clear();
    _currentStep = 0;
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
        return headEulerAngleX! > 10;
      case 4: // Down
        return headEulerAngleX! < -10;
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
