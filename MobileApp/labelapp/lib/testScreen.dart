import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;
import 'package:http/http.dart' as http;
import 'config.dart';

class CameraCircle extends StatefulWidget {
  final List<CameraDescription> cameras;
  CameraCircle({required this.cameras});

  @override
  _CameraCircleState createState() => _CameraCircleState();
}

class _CameraCircleState extends State<CameraCircle> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final int _totalSegments = 11;
  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  int _currentSegment = 0;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);
  Timer? _timer;
  bool _isProcessing = false;

  Future<Uint8List> convertImageToPng(CameraImage image) async {
    try {
      imglib.Image imgImage;

      if (image.format.group == ImageFormatGroup.yuv420) {
        imgImage = _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        imgImage = _convertBGRA8888(image);
      } else {
        throw Exception('Unsupported image format');
      }

      // Encode imgImage to PNG
      return Uint8List.fromList(imglib.encodePng(imgImage));
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

  Future<void> _sendImageToServer(Uint8List pngBytes) async {
    try {
      final url = Uri.parse(AppConfig.http_url + "/pushimages");

      final request = http.MultipartRequest('POST', url);

      // Add the image as a file to the request
      request.files.add(http.MultipartFile.fromBytes('file', pngBytes,
          filename: 'image.png'));

      try {
        final response = await request.send();

        if (response.statusCode == 200) {
          print('Photo sent successfully');
        } else {
          print('Error while sending photo: ${response.statusCode}');
        }
      } catch (e) {
        print('Error while sending photo: $e');
      }
    } catch (e) {
      print('Error encoding image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[1]);
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    _initializeControllerFuture.then((_) {
      _controller.startImageStream((image) async {
        _processImageStream(image);
      });
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
  }

  void _processImageStream(CameraImage image) async {
    try {
      final pngBytes = await convertImageToPng(image);
      if (pngBytes != null) {
        await _sendImageToServer(pngBytes);
      } else {
        print("Error converting image to PNG");
      }
    } catch (e) {
      print("Error processing image stream: " + e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
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
