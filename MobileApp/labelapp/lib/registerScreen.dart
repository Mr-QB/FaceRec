import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'homeScreen.dart';
import 'package:http_parser/http_parser.dart';
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
  final int _totalSegments = 11;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);
  late String imageID;
  int _currentSegment = 0;
  Map<String, File?> imageConditions = {
    'Straight': null,
    'Left': null,
    'Right': null,
    'Up': null,
    'Down': null,
    'Tilt Head Left': null,
    'Tilt Head Up Left': null,
    'Tilt Head Down Left': null,
    'Tilt Head Right': null,
    'Tilt Head Up Right': null,
    'Tilt Head Down Right': null,
  };

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[1]);
    _startTimer();
    imageID = _generateTimestampID();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 200), (timer) {
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

  // Future<bool> _sendImagesToServer(File imageFile, String imageID) async {
  //   try {
  //     final base64Image = await _convertImageToBase64(imageFile);

  //     final response = await http.post(
  //       Uri.parse(AppConfig.http_url + "/pushimages"),
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({
  //         'images': base64Image,
  //         'userName': widget.userName,
  //         'imageID': imageID,
  //       }),
  //     );
  //     if (response.statusCode == 200) {
  //       print('Images uploaded successfully');
  //       return true;
  //     } else {
  //       print('Failed to upload images');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error: $e');
  //     return false;
  //   }
  // }
  Future<void> sendImagesToServer(Map<String, File?> imageConditions) async {
    final uri = Uri.parse(AppConfig.http_url + "/pushimages");

    var request = http.MultipartRequest('POST', uri);

    // Add each image file to the request
    imageConditions.forEach((key, file) async {
      if (file != null) {
        request.files.add(
          http.MultipartFile(
            key, // Field name for the file
            file.readAsBytes().asStream(),
            file.lengthSync(),
            filename: file.path.split('/').last,
            contentType: MediaType('image', 'jpeg'), // Adjust if needed
          ),
        );
      }
    });

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        print('Images uploaded successfully');
      } else {
        print('Failed to upload images. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred while uploading images: $e');
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
      await _checkFaceAngle(faces, imageFile);

      bool hasNonNullValues =
          imageConditions.values.any((file) => file != null);
      if (hasNonNullValues) {
        await sendImagesToServer(imageConditions);
      } else {
        print('No valid images to upload.');
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

  Map<String, dynamic> _checkFaceAngle(List<Face> faces, File imageFile) {
    final face = faces.first;
    final headEulerAngleY = face.headEulerAngleY;
    final headEulerAngleZ = face.headEulerAngleZ;
    final headEulerAngleX = face.headEulerAngleX;

    print('headEulerAngleY: $headEulerAngleY');
    print('headEulerAngleZ: $headEulerAngleZ');
    print('headEulerAngleX: $headEulerAngleX');

    if (headEulerAngleY != null &&
        headEulerAngleZ != null &&
        headEulerAngleX != null) {
      if (headEulerAngleY.abs() < 10 &&
          headEulerAngleZ.abs() < 10 &&
          imageConditions['Straight'] == null) {
        imageConditions['Straight'] = imageFile;
      }
      if (headEulerAngleY > 20 && imageConditions['Left'] == null) {
        imageConditions['Left'] = imageFile;
      }
      if (headEulerAngleY < -20 && imageConditions['Right'] == null) {
        imageConditions['Right'] = imageFile;
      }
      if (headEulerAngleX > 10 && imageConditions['Up'] == null) {
        imageConditions['Up'] = imageFile;
      }
      if (headEulerAngleX < -15 && imageConditions['Down'] == null) {
        imageConditions['Down'] = imageFile;
      }
      if (headEulerAngleZ < -15 &&
          headEulerAngleY.abs() < 10 &&
          headEulerAngleZ.abs() < 10 &&
          imageConditions['Tilt Head Left'] == null) {
        imageConditions['Tilt Head Left'] = imageFile;
      }
      if (headEulerAngleX > 15 &&
          headEulerAngleY > 20 &&
          imageConditions['Tilt Head Up Left'] == null) {
        imageConditions['Tilt Head Up Left'] = imageFile;
      }
      if (headEulerAngleX < -15 &&
          headEulerAngleY > 20 &&
          imageConditions['Tilt Head Down Left'] == null) {
        imageConditions['Tilt Head Down Left'] = imageFile;
      }
      if (headEulerAngleZ > 15 &&
          headEulerAngleY.abs() < 10 &&
          headEulerAngleZ.abs() < 10 &&
          imageConditions['Tilt Head Right'] == null) {
        imageConditions['Tilt Head Right'] = imageFile;
      }
      if (headEulerAngleX > 10 &&
          headEulerAngleY < -20 &&
          imageConditions['Tilt Head Up Right'] == null) {
        imageConditions['Tilt Head Up Right'] = imageFile;
      }
      if (headEulerAngleX < -15 &&
          headEulerAngleY < -20 &&
          imageConditions['Tilt Head Down Right'] == null) {
        imageConditions['Tilt Head Down Right'] = imageFile;
      }
    } else {
      print('Head Euler angles are null');
    }
    setState(() {
      int progress =
          imageConditions.values.where((value) => value != null).length;
      for (int i = 0; i < progress && i < _segmentColors.length; i++) {
        _segmentColors[i] = Colors.green;
      }
    });
    // Check
    final nullValues =
        imageConditions.entries.where((entry) => entry.value == null);

    for (var entry in nullValues) {
      print('pose null value: ${entry.key}');
    }

    return imageConditions;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final circleDiameter = screenSize.width < screenSize.height
        ? screenSize.width * 0.9
        : screenSize.height * 0.9;

    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(circleDiameter + 8.0, circleDiameter + 8.0),
                    painter: BorderPainter(
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
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class BorderPainter extends CustomPainter {
  final List<Color> colors;
  final int segments;

  BorderPainter({required this.colors, required this.segments});

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
