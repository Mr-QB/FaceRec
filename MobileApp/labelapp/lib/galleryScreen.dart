import 'package:flutter/material.dart';
import 'imageSetScreen.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<String> _folders = [];

  @override
  void initState() {
    super.initState();
    _folders = ImagePathManager().folders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery'),
      ),
      body: ListView.builder(
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('Set ${path.basename(_folders[index])}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ImageSetScreen(folderPath: _folders[index]),
                ),
              );
            },
            onLongPress: () {
              _showContextMenu(context, _folders[index]);
            },
          );
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, String folderPath) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, folderPath);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(context, folderPath);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, String folderPath) {
    TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Folder'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _renameFolder(folderPath, _controller.text);
                Navigator.pop(context);
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _renameFolder(String folderPath, String newName) {
    final directory = path.dirname(folderPath);
    final newFolderPath = path.join(directory, newName);
    final folder = Directory(folderPath);
    folder.renameSync(newFolderPath);

    // Update the ImagePathManager
    final index = ImagePathManager().folders.indexOf(folderPath);
    if (index != -1) {
      ImagePathManager().folders[index] = newFolderPath;
    }

    // Refresh the screen
    setState(() {});
  }

  void _deleteFolder(BuildContext context, String folderPath) {
    final folder = Directory(folderPath);
    folder.deleteSync(recursive: true);

    // Update the ImagePathManager
    ImagePathManager().folders.remove(folderPath);

    // Refresh the screen
    setState(() {});
  }
}
