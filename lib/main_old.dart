import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

List<CameraDescription>? cameras; // adding null temporarly to avoid error

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  CameraImage? img;
  late CameraController controller;
  bool isBusy = false;
  String result = "";
  late ImageLabeler imageLabeler;

  @override
  void initState() {
    super.initState();
    imageLabeler = GoogleMlKit.vision.imageLabeler();
  }

  //Initialize camera
  initializeCamera() async {
    controller = CameraController(cameras![0], ResolutionPreset.max);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy) {isBusy = true, img = image, doImageLabeling()}
          });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  //Write image labeling code
  doImageLabeling() async {
    result = "";
    InputImage inputImg = getInputImage();
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImg);
    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final double confidence = label.confidence;
      result += "$text   ${confidence.toStringAsFixed(2)}\n";
    }
    setState(() {
      result;
      isBusy = false;
    });
  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(cameras![0].sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(img?.format.raw) ??
            InputImageFormat.nv21;

    final planeData = img?.planes.map(
      (var plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('images/app-background.jpg'), fit: BoxFit.fill),
        ),
        child: Column(children: [
          Stack(
            children: [
              Center(
                child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Image.asset('images/no-signal.jpg')),
              ),
              Center(
                child: TextButton(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: img == null
                        ? Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white,
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: CameraPreview(controller),
                          ),
                  ),
                  onPressed: () {
                    initializeCamera();
                  },
                ),
              )
            ],
          ),
          Center(
            child: Container(
              height: MediaQuery.of(context).size.width * 0.3,
              child: SingleChildScrollView(
                  child: Text(
                '$result',
                style: TextStyle(
                  fontSize: 25,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              )),
            ),
          ),
        ]),
      ),
    );
  }
}
