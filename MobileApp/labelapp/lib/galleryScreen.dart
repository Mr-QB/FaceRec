import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[0]);
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.234:8765'),
    );
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.low, // Giảm độ phân giải
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

  Uint8List _convertCameraImageToUint8List(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final List<int> imageBytes = List<int>.filled(width * height * 3, 0);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        final int yValue = image.planes[0].bytes[index];
        final int uValue = image.planes[1].bytes[
            (x ~/ 2) * image.planes[1].bytesPerPixel! +
                (y ~/ 2) * image.planes[1].bytesPerRow];
        final int vValue = image.planes[2].bytes[
            (x ~/ 2) * image.planes[2].bytesPerPixel! +
                (y ~/ 2) * image.planes[2].bytesPerRow];

        final int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final int g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        final int pixelIndex = (y * width + x) * 3;
        imageBytes[pixelIndex] = r;
        imageBytes[pixelIndex + 1] = g;
        imageBytes[pixelIndex + 2] = b;
      }
    }

    return Uint8List.fromList(imageBytes);
  }

  void _sendImageStreamToServer(CameraImage image) async {
    try {
      final Uint8List imageBytes = _convertCameraImageToUint8List(image);
      _channel.sink.add(imageBytes);
      print('Image successfully sent to WebSocket server');
    } catch (e) {
      print('Error sending image to WebSocket server: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _channel.sink.close(); // Đóng kết nối WebSocket
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
