import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

class RecognitionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  RecognitionScreen({required this.cameras});

  @override
  _RecognitionScreenState createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isUsingFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[0]);
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream((CameraImage image) {
        _sendImageStreamToServer(image);
      });
    }).catchError((error) {
      print('Error initializing camera: $error');
    });
  }

  Future<String> _convertCameraImageToBase64(CameraImage image) async {
    return await compute(_convertCameraImageToBase64Isolate, image);
  }

// Chuyển đổi CameraImage thành ảnh JPEG và mã hóa thành base64
  Future<String> _convertCameraImageToBase64Isolate(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;

    // Tạo đối tượng ảnh từ gói image
    imglib.Image img = imglib.Image(width, height);

    // Điền dữ liệu vào đối tượng ảnh
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (x ~/ 2) + (y ~/ 2) * (width ~/ 2);
        final int yValue = image.planes[0].bytes[y * width + x];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];

        // Tính toán màu pixel
        final int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final int g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        img.setPixel(x, y, imglib.getColor(r, g, b));
      }
    }

    // Mã hóa ảnh thành JPEG và chuyển đổi thành byte
    final List<int> jpegBytes = imglib.encodeJpg(img);
    final String base64Image = base64Encode(jpegBytes);

    return base64Image;
  }

  void _sendImageStreamToServer(CameraImage image) async {
    try {
      final String base64Image = await _convertCameraImageToBase64(image);

      final Uri uri = Uri.parse('http://192.168.1.234:5000/upload');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        print('Image successfully uploaded');
      } else {
        print('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending image to server: $e');
    }
  }

  Uint8List _convertCameraImageToBytes(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = Uint8List(width * height * 3);

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerRow ~/ (width ~/ 2);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        final int yValue = image.planes[0].bytes[index];
        final int uValue = image
            .planes[1].bytes[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];
        final int vValue = image
            .planes[2].bytes[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];
        final int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final int g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        // Assuming the bytes array is arranged as [R, G, B]
        bytes[index * 3] = r; // R
        bytes[index * 3 + 1] = g; // G
        bytes[index * 3 + 2] = b; // B
      }
    }

    return bytes;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera'),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera),
            onPressed: () {
              final cameraDescription =
                  _isUsingFrontCamera ? widget.cameras[0] : widget.cameras[1];
              setState(() {
                _isUsingFrontCamera = !_isUsingFrontCamera;
                _initializeCameraController(cameraDescription);
              });
            },
          ),
        ],
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
