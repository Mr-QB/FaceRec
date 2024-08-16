import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';

class CameraCircle extends StatefulWidget {
  final List<CameraDescription> cameras;
  CameraCircle({required this.cameras});

  @override
  _CameraCircleState createState() => _CameraCircleState();
}

class _CameraCircleState extends State<CameraCircle> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  int _currentSegment = 0;
  final int _totalSegments = 11;
  List<Color> _segmentColors = List.generate(11, (index) => Colors.grey);

  void _btnCallBack() {
    setState(() {
      if (_currentSegment < _totalSegments) {
        _segmentColors[_currentSegment] = Colors.blue;
        _currentSegment++;
      }
    });
    print("click number $_currentSegment");
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
                  Positioned(
                    bottom: 16.0,
                    child: ElevatedButton(
                      onPressed: _btnCallBack,
                      child: Text('Nút'),
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
