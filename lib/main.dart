import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(
    home: CameraApp(camera: firstCamera),
  ));
}

class CameraApp extends StatefulWidget {
  final CameraDescription camera;

  const CameraApp({required this.camera});

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('カメラアプリ')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();

            final imageFile = File(image.path);
            final inputImage = InputImage.fromFile(imageFile);

            final faceDetector = GoogleMlKit.vision.faceDetector();
            final faces = await faceDetector.processImage(inputImage);

            if (faces.isNotEmpty) {
              final img.Image capturedImage =
                  img.decodeImage(imageFile.readAsBytesSync())!;
              for (final face in faces) {
                img.drawRect(
                    capturedImage,
                    face.boundingBox.left.toInt(),
                    face.boundingBox.top.toInt(),
                    face.boundingBox.right.toInt(),
                    face.boundingBox.bottom.toInt(),
                    img.getColor(0, 0, 0, 0.5 as int));
              }
              final Directory directory =
                  await getApplicationDocumentsDirectory();
              final blurredImagePath =
                  '${directory.path}/blurred_${DateTime.now().millisecondsSinceEpoch}.png';
              File(blurredImagePath)
                ..writeAsBytesSync(img.encodePng(capturedImage));

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PreviewScreen(imagePath: blurredImagePath),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PreviewScreen(imagePath: image.path),
                ),
              );
            }
          } catch (e) {
            print(e);
          }
        },
        child: Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class PreviewScreen extends StatelessWidget {
  final String imagePath;

  const PreviewScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('プレビュー')),
      body: Column(
        children: [
          Expanded(child: Image.file(File(imagePath))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  Navigator.pop(context);
                  File(imagePath).delete();
                },
              ),
              IconButton(
                icon: Icon(Icons.save),
                onPressed: () {
                  // 保存機能の実装
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
