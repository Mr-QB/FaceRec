import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:labelapp/userNameScreen.dart';
import 'cameraScreen.dart';
import 'galleryScreen.dart';

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
              child: Text('New Face Registration'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      // builder: (context) => CameraScreen(
                      //   cameras: cameras,
                      //   userName: "re",
                      // ),
                      builder: (context) => UserNamePage(cameras: cameras)),
                );
              },
            ),
            ElevatedButton(
              child: Text('Face Recognition'),
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
