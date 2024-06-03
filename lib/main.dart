import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GeoGemini App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'GeoGemini Chat Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  late FlutterSoundRecorder _recorder;
  String? _audioFilePath;
  bool _isRecording = false;
  bool _isSendingAudio = false;
  bool _isTyping = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? _botResponse = "";

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
    _recorder = FlutterSoundRecorder();
    _recorder.openRecorder();
  }

  Future<void> initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras[0], ResolutionPreset.high);
    await _cameraController?.initialize();
    setState(() {});
  }

  Future<void> startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final directory = await getApplicationDocumentsDirectory();
      _audioFilePath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: _audioFilePath);
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _isSendingAudio = true;
    });
  }

  void sendAudio() {
    // Implement sending audio logic here
    setState(() {
      _isSendingAudio = false;
    });
  }

  Future<void> takePicture() async {
    if (_cameraController != null) {
      final image = await _cameraController!.takePicture();
      // Implement sending picture logic here using image.path
    }
  }

  Future<void> takePhoto(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  void askGemini(XFile? imageFile) async {
    final API_KEY = "AIzaSyDwCk63cbbiltyi7CW9X4pPp1f03Kdk9mc";
    if (API_KEY == null) {
      print("No API Key");
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: API_KEY);
    final image;

    try {
      if (imageFile != null) {
        print(imageFile.path);
        print("hi");
        image = await File(imageFile.path).readAsBytes();
      } else {
        image =
            (await rootBundle.load('assets/image1.jpg')).buffer.asUint8List();
      }
    } catch (e) {
      print("Error loading image: $e");
      return;
    }

    final prompt = TextPart("Solve the question in this image");

    final imageParts = [DataPart('image/jpeg', image)];

    final response = await model.generateContent([
      Content.multi([prompt, ...imageParts])
    ]);

    print(response.text);
    setState(() {
      _botResponse = response.text;
    });
  }

// void askGemini(String imageSource) async {
//   final API_KEY = ""; // Add your actual API key here
//   if (API_KEY.isEmpty) {
//     print("No API Key");
//     return;
//   }

//   final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: API_KEY);

//   Uint8List image;
//   if (imageSource != null && imageSource.isNotEmpty) {
//     image = (await rootBundle.load(imageSource)).buffer.asUint8List();
//   } else {
//     image = (await rootBundle.load('assets/image1.jpg')).buffer.asUint8List();
//   }

//   final prompt = TextPart("Solve the question in this image");
//   final imageParts = [DataPart('image/jpeg', image)];

//   final response = await model.generateContent([
//     Content.multi([prompt, ...imageParts])
//   ]);

//   print(response.text);
// }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF222831),
        // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white, // Background color of the container
                borderRadius: BorderRadius.circular(8.0), // Border radius
              ),
              child: IconButton(
                icon: const ImageIcon(
                  AssetImage(
                      'assets/geogeminiicon.jpg'), // Use your custom image
                  color: Colors.white,
                ),
                color: Colors.white,
                onPressed: sendAudio,
              ),
            ),
            Text('GeoGemini Chat Page', style: TextStyle(color: Colors.white)),
          ],
        ),
        // title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: Color(0xFF31363F),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              children: [
                _botResponse != ""
                    ? Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Container(
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(100, 100, 100, 0.7),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0))),
                            child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(_botResponse ?? "Thinking...",
                                    style: TextStyle(color: Colors.white)))))
                    : Container(),
                _imageFile != null
                    ? Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Container(
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(100, 100, 100, 0.7),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0))),
                            child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child:
                                    Image.file(File(_imageFile?.path ?? "")))))
                    : Container(),
              ],
            ),
          ),
          if (_isSendingAudio)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text('Audio recorded', style: TextStyle(color: Colors.white)),
                  IconButton(
                    icon: Icon(Icons.send),
                    color: Colors.white,
                    onPressed: sendAudio,
                  ),
                ],
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              // color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
                // bottom: BorderSide(color: Colors.grey, width: 1.0),
              ),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // IconButton(
                //     icon: Icon(Icons.add_circle_rounded),
                //     color: Colors.white,
                //     onPressed: () {
                //       setState(() {
                //         if (_isTyping == true) {
                //           setState(() {
                //             _isTyping = true;
                //           });
                //         } else {
                //           setState(() {
                //             _isTyping = false;
                //           });
                //         }
                //       });
                //     }
                //     // onPressed: _isRecording ? stopRecording : startRecording,
                //     ),
                Visibility(
                  visible: !_isTyping,
                  child: Row(children: [
                    Container(
                      // padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.camera_alt),
                            color: Colors.white,
                            onPressed: () {
                              takePhoto(ImageSource.camera);
                            },
                          ),
                          IconButton(
                              icon: Icon(Icons.add_a_photo),
                              color: Colors.white,
                              onPressed: () {
                                takePhoto(ImageSource.gallery);
                              }
                              // onPressed: _isRecording ? stopRecording : startRecording,
                              ),
                          IconButton(
                              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                              color: Colors.white,
                              onPressed: () {
                                takePhoto(ImageSource.gallery);
                              }
                              // onPressed: _isRecording ? stopRecording : startRecording,
                              ),
                        ],
                      ),
                    )
                  ]),
                ),
                // IconButton(
                //   icon: Icon(Icons.camera_alt),
                //   color: Colors.white,
                //   onPressed: () {
                //     takePhoto(ImageSource.camera);
                //   },
                // ),
                // IconButton(
                //     icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                //     color: Colors.white,
                //     onPressed: () {
                //       takePhoto(ImageSource.gallery);
                //     }
                //     // onPressed: _isRecording ? stopRecording : startRecording,
                //     ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: TextStyle(color: Colors.white),
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        setState(() {
                          _isTyping = true;
                        });
                      } else {
                        setState(() {
                          _isTyping = false;
                        });
                      }
                    },
                    onSubmitted: (text) {
                      // We will be sending message logic here
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Colors.white,
                  onPressed: () {
                    askGemini(_imageFile);
                  },
                ),
              ],
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
