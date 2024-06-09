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
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  String _textSend = "";
  final TextEditingController _textController = TextEditingController();

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
    _speech = stt.SpeechToText();
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

  void _listen() async {
    if (!_isListening) {
      setState(() {
        // _responseLoading = false;
        _botResponse = "Listening!!";
      });
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      // print(_isListening);
      // print(available);
      if (available) {
        // print("hi there");
        setState(() {
          _isListening = true;
          _isTyping = true;
        });
        // print(_isListening);
        _speech.listen(
          onResult: (val) => setState(() {
            // _textSend = val.recognizedWords;
            // _text = val.recognizedWords;

            _textController.text = val.recognizedWords;
            // );
            // print(_text);
            // _text = val.recognizedWords;
          }),
        );
        setState(() {
          _isListening = false;
        });
      }
    } else {
      // print("hi");
      setState(() => _isListening = false);
      _speech.stop();
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

    final prompt = TextPart(
        "Solve the Mathematical Question in the image (If it is not a Mathematical Question, return 'Not a Mathematical Question'):");

    final imageParts = [DataPart('image/jpeg', image)];

    final response = await model.generateContent([
      Content.multi([prompt, ...imageParts])
    ]);

    setState(() {
      _responseLoading = false;
      _botResponse = response.text;
    });
  }

  void askGeminitext(String textMessage) async {
    const API_KEY = "AIzaSyDwCk63cbbiltyi7CW9X4pPp1f03Kdk9mc";
    setState(() {
      _botResponse = "";
      _imageFile = null;
      _responseLoading = true;
    });

    final model = GenerativeModel(model: 'gemini-pro', apiKey: API_KEY);

    final prompt =
        "Solve the following Mathematical Question (If it is not a Mathematical Question, return 'Not a Mathematical Question'): $textMessage";

    try {
      // final prompt = [Content.text(textMessage ?? "")];
      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _responseLoading = false;
        _botResponse = response.text;
      });
    } catch (e) {
      print("Error generating response: $e");
      setState(() {
        _responseLoading = false;
        _botResponse = "Error generating response";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recorder.closeRecorder();
    _textController.dispose();
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
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0), // Border radius
                child: const Image(
                    height: 35, image: AssetImage("assets/geogeminiicon.jpg")),
              ),
            ),
            const Text('GeoGemini', style: TextStyle(color: Colors.white)),
          ],
        ),
        // title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: const Color(0xFF31363F),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              children: [
                Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(172, 63, 54, 72),
                        border: Border.all(
                            width: 2,
                            color: const Color.fromRGBO(70, 70, 70, 1.0)),
                        boxShadow: const [
                          BoxShadow(
                            color:
                                Color.fromRGBO(40, 40, 40, 0.5), // Shadow color
                            blurRadius: 10.0, // Adjust blur for softness
                            offset: Offset(
                                -5, -5), // Negative offset for inset effect
                          )
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "RESPONSE",
                            style: TextStyle(
                                color: Color.fromRGBO(100, 100, 100, 1.0),
                                fontWeight: FontWeight.bold),
                          ),
                          _botResponse != ""
                              ? Container(
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10.0))),
                                  child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(_botResponse ?? "Thinking...",
                                          style: const TextStyle(
                                              color: Colors.white))))
                              : _responseLoading
                                  ? Container(
                                      decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(10.0))),
                                      child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text("Thinking...",
                                              style: TextStyle(
                                                  color: Colors.white))))
                                  : Container()
                        ])),
                Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                        border: Border.all(
                            width: 2,
                            color: const Color.fromRGBO(70, 70, 70, 1.0)),
                        boxShadow: const [
                          BoxShadow(
                            color:
                                Color.fromRGBO(40, 40, 40, 0.5), // Shadow color
                            blurRadius: 10.0, // Adjust blur for softness
                            offset: Offset(
                                -5, -5), // Negative offset for inset effect
                          )
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "QUESTION",
                            style: TextStyle(
                                color: Color.fromRGBO(100, 100, 100, 1.0),
                                fontWeight: FontWeight.bold),
                          ),
                          _imageFile != null
                              ? Container(
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10.0))),
                                  child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.file(
                                          File(_imageFile?.path ?? ""))))
                              : _textSend != ""
                                  ? Container(
                                      decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(10.0))),
                                      child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(_textSend,
                                              style: const TextStyle(
                                                  color: Colors.white))))
                                  : Container()
                        ]))
              ],
            ),
          ),
          // if (_isSendingAudio)
          //   Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: Row(
          //       children: [
          //         Text('Audio recorded', style: TextStyle(color: Colors.white)),
          //         IconButton(
          //           icon: Icon(Icons.send),
          //           color: Colors.white,
          //           onPressed: sendAudio,
          //         ),
          //       ],
          //     ),
          //   ),
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
                          // FloatingActionButton(
                          //   onPressed: _listen,
                          //   child:
                          //       Icon(_isListening ? Icons.mic : Icons.mic_none),
                          // ),
                          IconButton(
                            icon:
                                Icon(_isListening ? Icons.mic : Icons.mic_none),
                            color: Colors.white,
                            onPressed: () {
                              _listen();
                            },
                            // onPressed: _isRecording ? stopRecording : startRecording,
                          ),
                        ],
                      ),
                    )
                  ]),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        setState(() {
                          _isTyping = true;
                          _text = text;
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
                        onPressed: () {
                          setState(() {
                            _textSend = _text;
                          });
                          _textController.clear(); // Clear the text field
                          askGeminitext(_text);
                          setState(() {
                            _isTyping = false;
                          });
                        },
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
