import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'dart:convert';
import 'dart:async';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeCameraController(widget.cameras[0]);
  }

  void _initializeCameraController(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // Set resolution
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      _timer = Timer.periodic(Duration(seconds: 1), (_) async {
        try {
          final image = await _controller.takePicture();
          final base64Image = await convertImageToBase64(image);
          _sendImageStreamToServer(context, base64Image);
        } catch (e) {
          print('Error capturing image: $e');
        }
      });
    }).catchError((error) {
      print('Error initializing camera: $error');
    });
  }

  Future<String> convertImageToBase64(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  void _sendImageStreamToServer(
      BuildContext context, String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.http_url + "/recogn"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        print('Image successfully uploaded');
        final data = jsonDecode(response.body);
        final List<dynamic> names = data['names'];

        _showToastsForNames(context, List<String>.from(names));
      } else {
        print('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending image to server: $e');
    }
  }

  void showCustomToast(BuildContext context, String message) {
    final OverlayState? overlay = Overlay.of(context);
    if (overlay == null) return;

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

  void _showToastsForNames(BuildContext context, List<String> names) {
    final List<OverlayEntry> toastEntries = [];
    for (int i = 0; i < names.length; i++) {
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top +
              16.0 +
              i * 80.0, // Adjust offset
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
                names[i],
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );

      toastEntries.add(overlayEntry);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overlay = Overlay.of(context);
        if (overlay != null) {
          overlay.insert(overlayEntry);
          Future.delayed(Duration(milliseconds: 600), () {
            overlayEntry.remove();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
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
