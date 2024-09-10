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

  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  final int _totalSegments = 11;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);
  Timer? _timer;

  Uint8List convertImageToGrayscaleBytes(imglib.Image imgImage) {
    final start_time = DateTime.now();
    final width = imgImage.width;
    final height = imgImage.height;
    final grayscaleBytes = Uint8List(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = imgImage.getPixel(x, y);
        final r = imglib.getRed(pixel);
        final g = imglib.getGreen(pixel);
        final b = imglib.getBlue(pixel);
        final grayscale =
            (r + g + b) ~/ 3; // Average of RGB channels for grayscale
        grayscaleBytes[y * width + x] = grayscale;
      }
    }
    final end_time = DateTime.now();
    final elapsed_time = end_time.difference(start_time).inMilliseconds;
    print(
        'function convertImageToGrayscaleBytes pocessing__: $elapsed_time ms');

    return grayscaleBytes;
  }

  Future<Uint8List> _convertImageToPng(CameraImage image) async {
    try {
      final start_time = DateTime.now();
      // const delayDuration = Duration(milliseconds: 345);
      // await Future.delayed(delayDuration);
      imglib.Image imgImage;
      Uint8List imageBytes;

      if (image.format.group == ImageFormatGroup.yuv420) {
        imgImage = _convertYUV420(image);

        imageBytes = imgImage.getBytes();
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        imgImage = _convertBGRA8888(image);
        imageBytes = imgImage.getBytes();
      } else {
        throw Exception('Unsupported image format');
      }
      imageBytes = convertImageToGrayscaleBytes(imgImage);
      print('Image size: ${imageBytes.length} bytes');
      // imglib.encodeJpg(imgImage, quality: 80);

      // Uint8List imgImage_ = Uint8List.fromList(imglib.encodePng(imgImage));
      Uint8List imgImage_ =
          Uint8List.fromList(imglib.encodeJpg(imgImage, quality: 80));
      print('imageBytes size: ${imgImage_.length} bytes');
      final end_time = DateTime.now();
      final elapsed_time = end_time.difference(start_time).inMilliseconds;
      print('function _convertImageToPng pocessing__: $elapsed_time ms');
      return imgImage_;
      // return imageBytes;
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

      final request = http.Request('POST', url);

      // Thêm dữ liệu byte vào body của request
      request.bodyBytes = pngBytes;

      // Đặt header để server biết loại dữ liệu
      request.headers['Content-Type'] = 'application/octet-stream';

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
      ResolutionPreset.high,
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
      final pngBytes = await _convertImageToPng(image);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
