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
  bool _responseLoading = false;

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
      _botResponse = "";
      _imageFile = pickedFile;
    });

    askGemini(_imageFile);
  }

  void askGemini(XFile? imageFile) async {
    final API_KEY = "AIzaSyDwCk63cbbiltyi7CW9X4pPp1f03Kdk9mc";
    if (API_KEY == null) {
      print("No API Key");
    }

    setState(() {
      _responseLoading = true;
    });

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

    setState(() {
      _responseLoading = false;
      _botResponse = response.text;
    });
  }

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
        shadowColor: Colors.black12,
        backgroundColor: Color(0xFF222831),
        // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0), // Border radius
                child: Image(
                    height: 35, image: AssetImage("assets/geogeminiicon.jpg")),
              ),
            ),
            Text('GeoGemini', style: TextStyle(color: Colors.white)),
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
                        padding: const EdgeInsets.fromLTRB(32, 16, 8, 16),
                        child: Container(
                            decoration: const BoxDecoration(
                                color: Color.fromRGBO(102, 87, 116, 0.675),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0))),
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(_botResponse ?? "Thinking...",
                                    style:
                                        const TextStyle(color: Colors.white)))))
                    : _responseLoading
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(32, 16, 8, 16),
                            child: Container(
                                decoration: const BoxDecoration(
                                    color: Color.fromRGBO(102, 87, 116, 0.675),
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(10.0))),
                                child: const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text("Thinking...",
                                        style:
                                            TextStyle(color: Colors.white)))))
                        : Container(),
                _imageFile != null
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(8, 16, 32, 16),
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
                Visibility(
                  visible: !_isTyping,
                  child: Row(children: [
                    Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            color: Colors.white,
                            onPressed: () {
                              takePhoto(ImageSource.camera);
                            },
                          ),
                          IconButton(
                              icon: const Icon(Icons.image),
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
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
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
                _isTyping
                    ? IconButton(
                        icon: Icon(Icons.send),
                        color: Colors.white,
                        onPressed: () {},
                      )
                    : Container(),
              ],
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
