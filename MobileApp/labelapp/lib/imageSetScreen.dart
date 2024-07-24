import 'package:flutter/material.dart';
import 'dart:io';

class ImageSetScreen extends StatelessWidget {
  final String folderPath;

  ImageSetScreen({required this.folderPath});

  @override
  Widget build(BuildContext context) {
    final directory = Directory(folderPath);
    final images = directory.listSync().map((item) => item.path).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Image Set'),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            child: Image.file(File(images[index])),
          );
        },
      ),
    );
  }
}

class ImagePathManager {
  static final ImagePathManager _instance = ImagePathManager._internal();
  factory ImagePathManager() => _instance;
  ImagePathManager._internal();
  List<String> folders = [];
}
