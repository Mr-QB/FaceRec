import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'cameraScreen.dart';

class UserNamePage extends StatefulWidget {
  final List<CameraDescription> cameras; // Thêm tham số cameras

  UserNamePage({required this.cameras});

  @override
  _UserNamePageState createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  final TextEditingController _controller = TextEditingController();

  void _navigateToCameraScreen() {
    final userName = _controller.text;
    if (userName.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            userName: userName,
            cameras:
                widget.cameras, // Truyền danh sách cameras vào CameraScreen
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a user name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter User Name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'User Name',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToCameraScreen,
              child: Text('Go to Camera Screen'),
            ),
          ],
        ),
      ),
    );
  }
}
