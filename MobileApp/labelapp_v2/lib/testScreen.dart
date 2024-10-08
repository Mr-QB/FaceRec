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

class SimpleSemaphore {
  int _available;
  final List<Completer<void>> _waiters = [];

  SimpleSemaphore(this._available);

  Future<void> acquire() {
    if (_available > 0) {
      _available--;
      return Future.value();
    } else {
      final completer = Completer<void>();
      _waiters.add(completer);
      return completer.future;
    }
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeAt(0);
      completer.complete();
    } else {
      _available++;
    }
  }
}

class CameraCircle extends StatefulWidget {
  final List<CameraDescription> cameras;
  CameraCircle({required this.cameras});

  @override
  _CameraCircleState createState() => _CameraCircleState();
}

class _CameraCircleState extends State<CameraCircle> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();
  final int _totalSegments = 11;
  final double mirror = pi;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);
  Timer? _timer;
  final semaphore = SimpleSemaphore(1);
  Future<void> _sendImageToServerWithLimit(CameraImage image) async {
    await semaphore.acquire();
    try {
      await _sendImageToServer(image);
    } finally {
      semaphore.release();
    }
  }

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
      imageBytes = convertImageToGrayscaleBytes(imgImage);
      print('Image size: ${imageBytes.length} bytes');
      // imglib.encodeJpg(imgImage, quality: 80);

      // Uint8List imgImage_ = Uint8List.fromList(imglib.encodePng(imgImage));
      // Uint8List imgImage_ =
      //     Uint8List.fromList(imglib.encodeJpg(imgImage, quality: 80));
      // print('imageBytes size: ${imgImage_.length} bytes');

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

  Future<void> _sendImageToServer(CameraImage image) async {
    try {
      final start_time = DateTime.now();
      final imageBytes = await _convertImageToPng(image);

      final url = Uri.parse(AppConfig.http_url + "/pushimages");

      final request = http.Request('POST', url);

      // Thêm dữ liệu byte vào body của request
      request.bodyBytes = imageBytes;

      // Đặt header để server biết loại dữ liệu
      request.headers['Content-Type'] = 'application/octet-stream';

      try {
        final response = await request.send();

        if (response.statusCode == 200) {
          print('Photo sent successfully');
        } else {
          print('Error while sending photo: ${response.statusCode}');
        }
        final end_time = DateTime.now();
        final elapsed_time = end_time.difference(start_time).inMilliseconds;
        print('function _sendImageToServer pocessing__: $elapsed_time ms');
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
      ResolutionPreset.low,
    );
    _initializeControllerFuture = _controller.initialize();
    _initializeControllerFuture.then((_) {
      _controller.startImageStream((image) async {
        await _processImageStream(image);
      });
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
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

  Future<bool> _sendImagesToServer(CameraImage image, String imageID) async {
    try {
      Uint8List imageBytes = await _convertImageToPng(image);
      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/pushimages"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'images': imageBytes,
          'userName': "widget.userName",
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

  Future<void> _processImageStream(CameraImage image) async {
    try {
      final start_time = DateTime.now();

      // rotatedImage = imglib.copyRotate(image, 270);

      int totalLength =
          image.planes.fold(0, (sum, plane) => sum + plane.bytes.length);

      Uint8List imageByte = Uint8List(totalLength);
      int offset = 0;
      for (final plane in image.planes) {
        imageByte.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      final endTime = DateTime.now(); // end
      final duration = endTime.difference(start_time);
      print("Time to convert image: ${duration.inMilliseconds} ms");
      // Uint8List imgImage_ =
      //     Uint8List.fromList(imglib.encodeJpg(imageByte, quality: 80));
      // _sendImageToServer(imgImage_);
      if (imageByte != null) {
        // await _sendImageToServer(pngBytes);
        // _detectFaces(imageByte);
        await _sendImageToServer(image);
        // await _sendImagesToServer((image), "21");
      } else {
        print("Error converting image to PNG");
      }
    } catch (e) {
      print("Error processing image stream: " + e.toString());
    }
  }

  Future<List<Face>> _detectFaces(Uint8List image) async {
    print("rotation: ${_controller.description.sensorOrientation}");
    // Uint8List bgraData = yuv420ToBgra8888(image, 1280, 720);
    // Uint8List rotatedImageBytes = rotateBgra8888Degree270(bgraData, 1280, 720);
    // Uint8List rotatedImageBytes = rotateYUV420Degree270(image, 1280, 720);
    try {
      final metadata = createMetadata(
        size: Size(320, 240),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: 0,
      );

      // final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata)
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
    } catch (e) {
      print("Error processing image detectface: " + e.toString());
      return [];
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
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(mirror),
              child: CameraPreview(_controller),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
