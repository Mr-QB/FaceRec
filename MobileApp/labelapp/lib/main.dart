import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'cameraScreen.dart';
import 'galleryScreen.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera and Gallery App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(cameras: cameras),
      // home: HomeScreen2(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  HomeScreen({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Text('Open Camera'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(cameras: cameras),
                  ),
                );
              },
            ),
            ElevatedButton(
              child: Text('Open Gallery'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GalleryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// class HomeScreen2 extends StatelessWidget {
//   Future<void> _sendPostRequest() async {
//     const url = 'https://httptest.onlyfan.vn/pushtest';
//     final response = await http.post(
//       Uri.parse(url),
//       headers: {'Content-Type': 'application/json'},
//       body: '{"message": "Hello, this is a test message!"}',
//     );

//     if (response.statusCode == 200) {
//       print('Request successful');
//     } else {
//       print('Request failed with status: ${response.statusCode}');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('HTTP POST Request Example'),
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: _sendPostRequest,
//           child: Text('Send POST Request'),
//         ),
//       ),
//     );
//   }
// }
