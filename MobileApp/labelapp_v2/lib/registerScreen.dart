import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'homeScreen.dart';
import 'config.dart';
import 'dart:typed_data';

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
  bool first_submit = true;

  final List<String> _instructions = [
    'Look Straight',
    'Turn Left',
    'Turn Right',
    'Look Up',
    'Look Down',
    'Tilt Head Left',
    'Tilt Head Right',
  ];
  late List<String> _missing_images = List.from(_instructions);
  late int _totalSegments = _instructions.length;
  List<Color> _segmentColors = List.generate(7, (index) => Colors.grey);
  List<Map<String, CameraImage>> capturedImages = [];
  final int user_id = 1;

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[1]);
  }

  Future<Uint8List> _convertImageToPng(CameraImage image) async {
    try {
      imglib.Image imgImage;
      Uint8List imageBytes;

      if (image.format.group == ImageFormatGroup.yuv420) {
        imgImage = _convertYUV420(image);
        // imageBytes = imgImage.getBytes();
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        imgImage = _convertBGRA8888(image);
        // imageBytes = imgImage.getBytes();
      } else {
        throw Exception('Unsupported image format');
      }
      final rotatedImage = imglib.copyRotate(imgImage, -90);

      imageBytes =
          Uint8List.fromList(imglib.encodeJpg(rotatedImage, quality: 80));
      return imageBytes;
    } catch (e) {
      print(">>>>>>>>>>>> ERROR: " + e.toString());
      return Future.error(e);
    }
  }

  imglib.Image _convertBGRA8888(CameraImage image) {
    // CameraImage BGRA8888 -> PNG
    return imglib.Image.fromBytes(
      image.width,
      image.height,
      image.planes[0].bytes,
      format: imglib.Format.bgra,
    );
  }

  imglib.Image _convertYUV420(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final convertedImage = imglib.Image(width, height);

    final yPlane = image.planes[0];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;

        if (yIndex < yPlane.bytes.length) {
          // Ensure index is within bounds
          final yValue = yPlane.bytes[yIndex];

          // Set the pixel value as grayscale
          convertedImage.setPixel(
              x,
              y,
              imglib.getColor(
                yValue,
                yValue,
                yValue,
              ));
        }
      }
    }

    return convertedImage;
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.low,
    );
    _initializeControllerFuture = _controller.initialize();
    _initializeControllerFuture.then((_) {
      _controller.startImageStream((image) async {
        _processImageStream(context, image);
      });
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
  }

  void _backToHome() async {
    if (_controller != null && _controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    await _controller.dispose();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(cameras: widget.cameras),
      ),
    );
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

  void _processFaceDetection() async {
    List<Map<String, CameraImage>> selectedImages = [];
    Set<String> encounteredInstructions = {};
    for (var item in capturedImages) {
      String instruction = item.keys.first;
      if (_missing_images.contains(instruction) &&
          !encounteredInstructions.contains(instruction)) {
        encounteredInstructions.add(instruction);
        selectedImages.add(item);
      }
    }

    capturedImages.removeWhere((item) => selectedImages.contains(item));

    List<Map<String, Uint8List>> imageFace = [];
    for (var item in selectedImages) {
      String instruction = item.keys.first;
      CameraImage? cameraImage = item[instruction];

      if (cameraImage != null) {
        Uint8List imageBytes = await _convertImageToPng(cameraImage);
        imageFace.add({
          instruction: imageBytes,
        });
      }
    }
    if (first_submit) {
      first_submit = false;
      if (await _postToAPI(imageFace, "/user")) {
        _backToHome();
      }
    } else {
      if (await _postToAPI(imageFace, "/update/$user_id")) {
        _backToHome();
      }
    }
  }

  Future<bool> _postToAPI(
      List<Map<String, Uint8List>> imageFace, String api) async {
    try {
      Map<String, String> imagesMap = {};
      for (var item in imageFace) {
        String instruction = item.keys.first;
        Uint8List imageBytes = item[instruction]!;
        String base64Image = base64Encode(imageBytes);
        imagesMap[instruction] = base64Image;
      }
      final jsonData = {
        'images': imagesMap,
        'userName': widget.userName,
        'type': "add",
      };

      final response = await http.post(
        Uri.parse(AppConfig.http_url + api),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _missing_images.removeWhere((element) =>
            (responseData['eligibleImages'] ?? []).contains(element));

        if (_missing_images.isNotEmpty) {
          print('Missing images: $_missing_images');
          return false;
        } else {
          return true;
        }
      } else {
        print('Failed to upload images');
        return false;
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  void _processImageStream(BuildContext context, CameraImage image) async {
    try {
      int totalLength =
          image.planes.fold(0, (sum, plane) => sum + plane.bytes.length);

      Uint8List imageByte = Uint8List(totalLength);
      int offset = 0;
      for (final plane in image.planes) {
        imageByte.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      if (imageByte != null) {
        final faces = await _detectFaces(imageByte);
        _checkFaceAngle(faces, image);

        if (countUniqueInstructions(capturedImages, _missing_images) ==
            _missing_images.length) {
          _processFaceDetection();
        } else {
          showCustomToast(
            context,
            'Face is not at the correct angle. Please try again.',
          );
        }
        _updateProgress();
      } else {
        print("Error converting image to PNG");
      }
    } catch (e) {
      print("Error processing image stream: " + e.toString());
    }
  }

  InputImageMetadata createMetadata({
    required Size size,
    required InputImageRotation rotation,
    required InputImageFormat format,
    required int bytesPerRow,
  }) {
    return InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: bytesPerRow,
    );
  }

  Future<List<Face>> _detectFaces(Uint8List image) async {
    InputImageRotation rotation;
    switch (_controller.description.sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
        break;
    }

    final metadata = createMetadata(
      size: Size(320, 240),
      rotation: rotation,
      format: InputImageFormat.yuv420,
      bytesPerRow: 0,
    );

    final inputImage = InputImage.fromBytes(bytes: image, metadata: metadata);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    return faces;
  }

  int countUniqueInstructions(List<Map<String, CameraImage>> capturedImages,
      List<String> _missing_images) {
    Set<String> uniqueInstructions = {};
    try {
      for (var item in capturedImages) {
        for (var instruction in item.keys) {
          if (_missing_images.contains(instruction)) {
            uniqueInstructions.add(instruction);
          }
        }
      }
    } catch (e) {
      print("function countUniqueInstructions error: $e");
    }
    print(uniqueInstructions.length);

    return uniqueInstructions.length;
  }

  void _updateProgress() {
    int current_progress = _instructions.length - _missing_images.length;
    List<Color> colors = List.generate(
      current_progress,
      (index) => Colors.green,
    );

    if (colors.length < _totalSegments) {
      colors.addAll(List<Color>.filled(
        _totalSegments - colors.length,
        Colors.grey,
      ));
    }

    setState(() {
      _segmentColors = colors;
    });
  }

  void addImage(
      Map<String, CameraImage> newImage,
      List<Map<String, CameraImage>> capturedImages,
      String instruction_current) {
    String instruction = newImage.keys.first;
    int count = capturedImages
        .where((item) => item.keys.first == instruction_current)
        .length;

    if (instruction == instruction && count >= 5) {
      // print('Cannot add more "$instruction" instructions, limit reached.');
    } else {
      capturedImages.add(newImage);
    }
  }

  void _checkFaceAngle(List<Face> faces, CameraImage image) {
    try {
      final face = faces.first;
      final headEulerAngleY = face.headEulerAngleY;
      final headEulerAngleZ = face.headEulerAngleZ;
      final headEulerAngleX = face.headEulerAngleX;

      if (headEulerAngleY!.abs() < 10 && headEulerAngleZ!.abs() < 10) {
        addImage({
          'Look Straight': image,
        }, capturedImages, _instructions[0]);
      } else if (headEulerAngleX! > 20) {
        addImage({
          'Look Up': image,
        }, capturedImages, _instructions[3]);
      } else if (headEulerAngleX < -15) {
        addImage({
          'Look Down': image,
        }, capturedImages, _instructions[4]);
      } else if (headEulerAngleY < -10 &&
          (headEulerAngleX! > 2 || headEulerAngleX < -5)) {
        addImage({
          'Tilt Head Left': image,
        }, capturedImages, _instructions[5]);
      } else if (headEulerAngleY > 10 &&
          (headEulerAngleX! > 2 || headEulerAngleX < -5)) {
        addImage({
          'Tilt Head Right': image,
        }, capturedImages, _instructions[6]);
      } else if (headEulerAngleY > 15) {
        addImage({
          'Turn Left': image,
        }, capturedImages, _instructions[1]);
      } else if (headEulerAngleY < -15) {
        addImage({
          'Turn Right': image,
        }, capturedImages, _instructions[2]);
      }
    } catch (e) {
      print("Error checking face pose: " + e.toString());
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
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(pi),
                                  child: CameraPreview(_controller),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 86.0),
                  Text(
                    "Please move your face slowly in a circular motion.",
                    // _instructions[_currentStep],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
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
