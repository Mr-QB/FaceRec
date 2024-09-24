import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'homeScreen.dart';
import 'config.dart';
import 'dart:typed_data';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String user_name;
  CameraScreen({required this.user_name, required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final FaceDetector _face_detector = GoogleMlKit.vision.faceDetector();
  final int user_id = Random().nextInt(100);
  final List<String> _instructions = [
    'Look Straight',
    'Turn Left',
    'Turn Right',
    'Look Up',
    'Look Down',
    'Tilt Head Left',
    'Tilt Head Right',
  ];

  late List<Color> _segment_colors = List.generate(7, (index) => Colors.grey);
  late List<Map<String, CameraImage>> captured_images = [];
  late CameraController _controller;
  late List<String> _missing_images = List.from(_instructions);
  late int _total_segments = _instructions.length;
  late Future<void> _initializeControllerFuture;
  late bool _first_submit = true;

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[1]);
  }

  Future<Uint8List> _convertImageToPng(CameraImage image) async {
    try {
      imglib.Image img_image;
      Uint8List imageBytes;

      if (image.format.group == ImageFormatGroup.yuv420) {
        img_image = _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        img_image = _convertBGRA8888(image);
      } else {
        throw Exception('Unsupported image format');
      }
      final rotatedImage = imglib.copyRotate(img_image, -90);

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
    _face_detector.close();
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
    List<Map<String, CameraImage>> selected_images = [];
    Set<String> encounteredInstructions = {};
    for (var item in captured_images) {
      String instruction = item.keys.first;
      if (_missing_images.contains(instruction) &&
          !encounteredInstructions.contains(instruction)) {
        encounteredInstructions.add(instruction);
        selected_images.add(item);
      }
    }

    captured_images.removeWhere((item) => selected_images.contains(item));

    List<Map<String, Uint8List>> image_face = [];
    for (var item in selected_images) {
      String instruction = item.keys.first;
      CameraImage? camera_image = item[instruction];

      if (camera_image != null) {
        Uint8List imageBytes = await _convertImageToPng(camera_image);
        image_face.add({
          instruction: imageBytes,
        });
      }
    }
    if (_first_submit) {
      _first_submit = false;
      if (await _postToAPI(image_face, "/user")) {
        _backToHome();
      }
    } else {
      if (await _postToAPI(image_face, "/user/$user_id")) {
        _backToHome();
      }
    }
  }

  Future<bool> _postToAPI(
      List<Map<String, Uint8List>> imageFace, String api) async {
    try {
      Map<String, String> images_map = {};
      for (var item in imageFace) {
        String instruction = item.keys.first;
        Uint8List image_bytes = item[instruction]!;
        String base64_image = base64Encode(image_bytes);
        images_map[instruction] = base64_image;
      }
      final json_data = {
        'images': images_map,
        'userName': widget.user_name,
        'type': "add",
        'userID': user_id,
      };

      final response = await http.post(
        Uri.parse(AppConfig.http_url + api),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(json_data),
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
      int total_length =
          image.planes.fold(0, (sum, plane) => sum + plane.bytes.length);

      Uint8List image_byte = Uint8List(total_length);
      int offset = 0;
      for (final plane in image.planes) {
        image_byte.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      if (image_byte != null) {
        final faces = await _detectFaces(image_byte);
        _checkFaceAngle(faces, image);

        if (countUniqueInstructions(captured_images, _missing_images) ==
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
    required int bytes_perRow,
  }) {
    return InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: bytes_perRow,
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
      bytes_perRow: 0,
    );

    final input_image = InputImage.fromBytes(bytes: image, metadata: metadata);
    final List<Face> faces = await _face_detector.processImage(input_image);

    return faces;
  }

  int countUniqueInstructions(List<Map<String, CameraImage>> captured_images,
      List<String> _missing_images) {
    Set<String> unique_instructions = {};
    try {
      for (var item in captured_images) {
        for (var instruction in item.keys) {
          if (_missing_images.contains(instruction)) {
            unique_instructions.add(instruction);
          }
        }
      }
    } catch (e) {
      print("function countUniqueInstructions error: $e");
    }

    return unique_instructions.length;
  }

  void _updateProgress() {
    int current_progress = _instructions.length - _missing_images.length;
    List<Color> colors = List.generate(
      current_progress,
      (index) => Colors.green,
    );

    if (colors.length < _total_segments) {
      colors.addAll(List<Color>.filled(
        _total_segments - colors.length,
        Colors.grey,
      ));
    }

    setState(() {
      _segment_colors = colors;
    });
  }

  void addImage(
      Map<String, CameraImage> new_image,
      List<Map<String, CameraImage>> captured_images,
      String instruction_current) {
    String instruction = new_image.keys.first;
    int count = captured_images
        .where((item) => item.keys.first == instruction_current)
        .length;

    if (instruction == instruction && count >= 5) {
      print('Cannot add more "$instruction" instructions, limit reached.');
    } else {
      captured_images.add(new_image);
    }
  }

  void _checkFaceAngle(List<Face> faces, CameraImage image) {
    try {
      final face = faces.first;
      final head_euler_angle_y = face.headEulerAngleY;
      final head_euler_angle_z = face.headEulerAngleZ;
      final head_euler_angle_x = face.headEulerAngleX;

      if (head_euler_angle_y!.abs() < 10 && head_euler_angle_z!.abs() < 10) {
        addImage({
          'Look Straight': image,
        }, captured_images, _instructions[0]);
      } else if (head_euler_angle_x! > 20) {
        addImage({
          'Look Up': image,
        }, captured_images, _instructions[3]);
      } else if (head_euler_angle_x < -15) {
        addImage({
          'Look Down': image,
        }, captured_images, _instructions[4]);
      } else if (head_euler_angle_y < -10 &&
          (head_euler_angle_x! > 2 || head_euler_angle_x < -5)) {
        addImage({
          'Tilt Head Left': image,
        }, captured_images, _instructions[5]);
      } else if (head_euler_angle_y > 10 &&
          (head_euler_angle_x! > 2 || head_euler_angle_x < -5)) {
        addImage({
          'Tilt Head Right': image,
        }, captured_images, _instructions[6]);
      } else if (head_euler_angle_y > 15) {
        addImage({
          'Turn Left': image,
        }, captured_images, _instructions[1]);
      } else if (head_euler_angle_y < -15) {
        addImage({
          'Turn Right': image,
        }, captured_images, _instructions[2]);
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
                          colors: _segment_colors,
                          segments: _total_segments,
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
