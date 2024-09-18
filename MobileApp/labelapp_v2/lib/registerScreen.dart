import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;
import 'dart:io';
import 'package:intl/intl.dart';
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
  int _currentStep = 0;
  Timer? _timer;
  late String _imageID = _instructions[_currentStep];
  late String _instructionsTitle = _instructions[_currentStep];
  final int _totalSegments = 11;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);
  List<Map<String, CameraImage>> capturedImages = [];

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

  void _stopCameraStream() async {
    if (_controller != null && _controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    await _controller.dispose();
  }

  Future<bool> _sendImagesToServer(Uint8List imageBytes, String imageID) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/pushimages"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'images': imageBytes,
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

  void removeFirstUniqueImages(
      List<Map<String, dynamic>> capturedImages, List<String> _instructions) {
    // Tạo Set để lưu những instruction đã gặp
    Set<String> seenInstructions = {};
    List<Map<String, dynamic>> imagesToRemove = [];

    for (var item in capturedImages) {
      String instruction = item['instruction'];

      // Kiểm tra nếu instruction thuộc _instructions và chưa gặp trước đó
      if (_instructions.contains(instruction) &&
          !seenInstructions.contains(instruction)) {
        imagesToRemove.add(item);
        seenInstructions.add(instruction); // Đánh dấu instruction đã gặp
      }
    }

    // Xóa các phần tử lần đầu tiên gặp
    capturedImages.removeWhere((item) => imagesToRemove.contains(item));

    // In ra các phần tử đã xóa
    print('Removed images: $imagesToRemove');
  }

  void _processFaceDetection() async {
    List<Map<String, CameraImage>> selectedImages = [];
    Set<String> encounteredInstructions = {};
    for (var item in capturedImages) {
      String instruction = item.keys.first;
      if (!encounteredInstructions.contains(instruction)) {
        encounteredInstructions.add(instruction);
        selectedImages.add(item);
      }
    }

    capturedImages.removeWhere((item) => selectedImages.contains(item));

    for (var item in selectedImages) {
      // String instruction = item.keys.first;
      String instruction = item.keys.first;
      CameraImage? cameraImage = item[instruction];

      if (cameraImage != null) {
        Uint8List imageBytes = await _convertImageToPng(cameraImage);

        await _sendImagesToServer(imageBytes, _imageID);
      }
    }

    // try {
    //   bool success = await _sendImagesToServer(imageBytes, _imageID);
    //   if (success) {
    //     _imageID = _instructions[_currentStep];
    //   }

    //   //   if (_currentStep == _instructions.length) {
    //   //     _instructionsTitle = "Face scanning completed, please wait a moment";
    //   //     _timer?.cancel();

    //   //     Navigator.push(
    //   //       context,
    //   //       MaterialPageRoute(
    //   //         builder: (context) {
    //   //           _stopCameraStream();
    //   //           return HomeScreen(cameras: widget.cameras);
    //   //         },
    //   //       ),
    //   //     );
    //   //   } else {
    //   //     setState(() {});
    //   //   }
    // } catch (e) {
    //   print("error in here: ${e}");
    // }
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
        // await _sendImageToServer(pngBytes);
        final faces = await _detectFaces(imageByte);
        _checkFaceAngle(faces, image);

        if (countUniqueInstructions(capturedImages) == _instructions.length) {
          _processFaceDetection();
        } else {
          showCustomToast(
            context,
            'Face is not at the correct angle. Please try again.',
          );
        }
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
    print("sensorOrientation ${rotation.toString()}");

    final metadata = createMetadata(
      size: Size(320, 240),
      rotation: rotation,
      format: InputImageFormat.yuv420,
      bytesPerRow: 0,
    );

    final inputImage = InputImage.fromBytes(bytes: image, metadata: metadata);
    final startTime = DateTime.now(); // start
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) {
      print("not face");
    } else {
      print("have face");
    }

    final endTime = DateTime.now(); // end
    final duration = endTime.difference(startTime);
    print("Time taken to detect faces: ${duration.inMilliseconds} ms");

    return faces;
  }

  int countUniqueInstructions(List<Map<String, dynamic>> capturedImages) {
    Set<String> uniqueInstructions = {};

    for (var item in capturedImages) {
      uniqueInstructions.add(item['instruction']);
    }

    return uniqueInstructions.length;
  }

  void addImage(Map<String, CameraImage> newImage,
      List<Map<String, CameraImage>> capturedImages, String instruction) {
    int count = capturedImages
        .where((item) => item['instruction'] == instruction)
        .length;

    if (newImage['instruction'] == 'Look Straight' && count >= 2) {
      print('Cannot add more "Look Straight" instructions, limit reached.');
    } else {
      capturedImages.add(newImage);
      print('Image added: $newImage');
    }
  }

  void _checkFaceAngle(List<Face> faces, CameraImage image) {
    final face = faces.first;
    final headEulerAngleY = face.headEulerAngleY;
    final headEulerAngleZ = face.headEulerAngleZ;
    final headEulerAngleX = face.headEulerAngleX;

    print('headEulerAngleY: $headEulerAngleY');
    print('headEulerAngleZ: $headEulerAngleZ');
    print('headEulerAngleX: $headEulerAngleX');

    if (headEulerAngleY!.abs() < 10 && headEulerAngleZ!.abs() < 10) {
      addImage({
        'Look Straight': image,
      }, capturedImages, _instructions[0]);
    } else if (headEulerAngleY > 20) {
      addImage({
        'Turn Left': image, // 'Turn Left'
      }, capturedImages, _instructions[1]);
    } else if (headEulerAngleY < -20) {
      addImage({
        'Turn Right': image, // 'Turn Right'
      }, capturedImages, _instructions[2]);
    } else if (headEulerAngleX! > 15) {
      addImage({
        'Look Up': image,
      }, capturedImages, _instructions[3]);
    } else if (headEulerAngleX < -15) {
      addImage({
        'Look Down': image,
      }, capturedImages, _instructions[4]);
    } else if (headEulerAngleZ! < -15) {
      addImage({
        'Tilt Head Left': image,
      }, capturedImages, _instructions[5]);
    } else if (headEulerAngleX > 15 && headEulerAngleZ < -15) {
      addImage({
        'Tilt Head Up Left': image,
      }, capturedImages, _instructions[6]);
    } else if (headEulerAngleX < -15 && headEulerAngleZ < -15) {
      addImage({
        'Tilt Head Down Left': image,
      }, capturedImages, _instructions[7]);
    } else if (headEulerAngleZ > 15) {
      addImage({
        'Tilt Head Right': image,
      }, capturedImages, _instructions[8]);
    } else if (headEulerAngleX > 15 && headEulerAngleZ > 15) {
      addImage({
        'Tilt Head Up Right': image,
      }, capturedImages, _instructions[9]);
    } else if (headEulerAngleX < -15 && headEulerAngleZ > -15) {
      addImage({
        'Tilt Head Down Right': image,
      }, capturedImages, _instructions[10]);
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
