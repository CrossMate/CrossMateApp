import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cross_mate/utils/memory_manager.dart';
import 'package:cross_mate/utils/tts_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import 'camera_view_singleton.dart';

/// [CameraView] sends each frame for inference
class CameraView extends StatefulWidget {
  /// Callback to pass results after inference to [HomeView]
  final Function(List<ResultObjectDetection> recognitions, Duration inferenceTime, Object? beforeMemoryUsage,
      Object? afterMemoryUsage) resultsCallback;
  final Function(String classification, Duration? inferenceTime) resultsCallbackClassification;

  /// Constructor
  const CameraView(this.resultsCallback, this.resultsCallbackClassification, {super.key});
  @override
  CameraViewState createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  /// List of available cameras
  late List<CameraDescription> cameras;

  /// Controller
  CameraController? cameraController;

  /// true when inference is ongoing
  bool predicting = false;

  /// true when inference is ongoing
  bool predictingObjectDetection = false;

  ModelObjectDetection? _objectModel;
  ClassificationModel? _imageModel;

  bool classification = false;
  int _camFrameRotation = 0;
  String errorMessage = "";
  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  //load your model
  Future loadModel() async {
    String pathImageModel = "assets/models/model_classification.pt";
    //String pathCustomModel = "assets/models/custom_model.ptl";
    String pathObjectDetectionModel = "assets/models/yolov8s.torchscript";
    try {
      _imageModel = await PytorchLite.loadClassificationModel(pathImageModel, 224, 224, 1000,
          labelPath: "assets/labels/label_classification_imageNet.txt");
      //_customModel = await PytorchLite.loadCustomModel(pathCustomModel);
      _objectModel = await PytorchLite.loadObjectDetectionModel(pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/labels_objectDetection_Coco.txt",
          objectDetectionModelType: ObjectDetectionModelType.yolov8);
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  void initStateAsync() async {
    WidgetsBinding.instance.addObserver(this);
    await loadModel();

    // Camera initialization
    try {
      initializeCamera();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          errorMessage = ('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          errorMessage = ('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          errorMessage = ('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          errorMessage = ('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          errorMessage = ('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          errorMessage = ('Audio access is restricted.');
          break;
        default:
          errorMessage = (e.toString());
          break;
      }
      setState(() {});
    }
    // Initially predicting = false
    setState(() {
      predicting = false;
    });
  }

  /// Initializes the camera by setting [cameraController]
  void initializeCamera() async {
    cameras = await availableCameras();

    var idx = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (idx < 0) {
      log("No Back camera found - weird");
      return;
    }

    var desc = cameras[idx];
    _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;
    // cameras[0] for rear-camera
    cameraController = CameraController(desc, ResolutionPreset.medium,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888, enableAudio: false);

    cameraController?.initialize().then((_) async {
      await cameraController?.startImageStream(onLatestImageAvailable);
      Size? previewSize = cameraController?.value.previewSize;
      CameraViewSingleton.inputImageSize = previewSize!;

      if (!mounted) return;
      Size screenSize = MediaQuery.of(context).size;
      CameraViewSingleton.screenSize = screenSize;
      CameraViewSingleton.ratio = cameraController!.value.aspectRatio;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container while the camera is not initialized
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return Container();
    }

    return CameraPreview(cameraController!);
    // return cameraController!.buildPreview();

    // return AspectRatio(
    //   aspectRatio: cameraController!.value.aspectRatio,
    //   child: CameraPreview(cameraController!),
    // );
  }

  runClassification(CameraImage cameraImage) async {
    if (predicting) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predicting = true;
    });
    if (_imageModel != null) {
      // Start the stopwatch
      // Stopwatch stopwatch = Stopwatch()..start();

      String imageClassification =
          await _imageModel!.getCameraImagePrediction(cameraImage, rotation: _camFrameRotation);
      // Stop the stopwatch
      // stopwatch.stop();
      // print("imageClassification $imageClassification");
      widget.resultsCallbackClassification(imageClassification, null);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predicting = false;
    });
  }

  final ttsManager = TtsManager.instance;

  Future<void> runObjectDetection(CameraImage cameraImage) async {
    if (predictingObjectDetection) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predictingObjectDetection = true;
    });
    if (_objectModel != null) {
      // Start the stopwatch
      Stopwatch stopwatch = Stopwatch()..start();
      final beforeMemory =
          Platform.isAndroid ? await MemoryManager.getMemoryUsage() : await MemoryManager.getResidentMemory();

      List<ResultObjectDetection> objDetect = await _objectModel!.getCameraImagePrediction(
        cameraImage,
        rotation: _camFrameRotation,
        minimumScore: 0.6,
        iOUThreshold: 0.3,
      );

      // Stop the stopwatch
      stopwatch.stop();
      final afterMemory =
          Platform.isAndroid ? await MemoryManager.getMemoryUsage() : await MemoryManager.getResidentMemory();

      if (objDetect.any((e) => (e).className == "laptop")) {
        print("laptop detected");
        ttsManager.speak("전방에 노트북입니다.");
      }

      // print("data outputted $objDetect");
      widget.resultsCallback(objDetect, stopwatch.elapsed, beforeMemory, afterMemory);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predictingObjectDetection = false;
    });
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  onLatestImageAvailable(CameraImage cameraImage) async {
    // Make sure we are still mounted, the background thread can return a response after we navigate away from this
    // screen but before bg thread is killed
    // if (!mounted) {
    //   return;
    // }

    // log("will start prediction");
    // log("Converted camera image");

    // runClassification(cameraImage);
    runObjectDetection(cameraImage);

    // log("done prediction camera image");
    // Make sure we are still mounted, the background thread can return a response after we navigate away from this
    // screen but before bg thread is killed
    // if (!mounted) {
    //   return;
    // }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
        cameraController?.stopImageStream();
        break;
      case AppLifecycleState.resumed:
        if (!cameraController!.value.isStreamingImages) {
          await cameraController?.startImageStream(onLatestImageAvailable);
        }
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    super.dispose();
  }
}
