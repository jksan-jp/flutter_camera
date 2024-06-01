import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:logger/web.dart';
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

  const CameraApp({super.key, required this.camera});

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final logger = Logger();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();

    _loadImage();
    _aaa();
  }

  Future<void> _loadImage() async {
    final File f = await getImageFileFromAssets('IMG_3201.PNG');
    print(f.path);
    final inputImage = InputImage.fromFilePath(f.path);
    final faceDetector = GoogleMlKit.vision.faceDetector();
    final faces = await faceDetector.processImage(inputImage);
    print('検出された顔の数: ${faces.length}\n\n');
  }

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load('assets/$path');

    final file =
        File('${(await getApplicationDocumentsDirectory()).path}/$path');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
  }

  Future<void> _aaa() async {
    try {
      await _initializeControllerFuture;
      //final image = await _controller.takePicture();

      //final imageFile = File(image.path);
      //print(image.path);

      final File f = await getImageFileFromAssets('IMG_3201.PNG');
      print(f.path);
      final inputImage = InputImage.fromFilePath(f.path);
      final faceDetector = GoogleMlKit.vision.faceDetector();
      final faces = await faceDetector.processImage(inputImage);
      print('検出された顔の数: ${faces.length}\n\n');

      String imagePathToDisplay;
      print(faces.isNotEmpty);
      if (faces.isNotEmpty) {
        final imageFile = File(f.path);
        final img.Image capturedImage =
            img.decodeImage(imageFile.readAsBytesSync())!;
        for (final face in faces) {
          final rect = face.boundingBox;
          final faceRegion = img.copyCrop(capturedImage, rect.left.toInt(),
              rect.top.toInt(), rect.width.toInt(), rect.height.toInt());
          final blurredFace = img.gaussianBlur(
              faceRegion, 25); // ここで強さ。10だとちょっと弱い、100だとちょっと主張感。
          img.copyInto(capturedImage, blurredFace,
              dstX: rect.left.toInt(), dstY: rect.top.toInt());
        }
        final Directory directory = await getApplicationDocumentsDirectory();
        final blurredImagePath =
            '${directory.path}/blurred_${DateTime.now().millisecondsSinceEpoch}.png';
        File(blurredImagePath).writeAsBytesSync(img.encodePng(capturedImage));
        imagePathToDisplay = blurredImagePath;
      } else {
        // imagePathToDisplay = image.path;
        imagePathToDisplay = f.path;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(imagePath: imagePathToDisplay),
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Title')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _aaa();
        },
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class PreviewScreen extends StatelessWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレビュー')),
      body: Column(
        children: [
          Expanded(child: Image.file(File(imagePath))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  Navigator.pop(context);
                  File(imagePath).delete();
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
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
