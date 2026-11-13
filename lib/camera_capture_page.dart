import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'l10n/app_localizations.dart';

/// Opens the in-app camera and returns the photo taken (JPEG bytes), or
/// null if the user backed out. A variable so widget tests, which have no
/// camera, can swap in a fake photo.
Future<Uint8List?> Function(BuildContext context) capturePhotoWithCamera = (context) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CameraCapturePage()),
  );
};

/// Add Event's built-in camera: a live viewfinder inside the app (the
/// `camera` plugin — no hand-off to another camera app), a shutter, a
/// front/back switch, then Retake or Use photo. Pops with the JPEG bytes.
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

enum _CameraProblem { none, noCamera, denied, failed }

class _CameraCapturePageState extends State<CameraCapturePage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  _CameraProblem _problem = _CameraProblem.none;
  bool _taking = false;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  // A phone takes the camera back when the app goes to the background, so
  // let it go and open it again on return. (On desktop, "inactive" just
  // means the window lost focus; keep the camera running there.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!mobile) return;
    final controller = _controller;
    if (state == AppLifecycleState.inactive && controller != null) {
      _controller = null;
      unawaited(controller.dispose());
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null && _cameras.isNotEmpty) {
      unawaited(_open(_cameraIndex));
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {
      if (mounted) setState(() => _problem = _CameraProblem.failed);
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _problem = _CameraProblem.noCamera);
      return;
    }
    // Back camera first: it's the one pointed at the event.
    final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    await _open(back < 0 ? 0 : back);
  }

  Future<void> _open(int index) async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      final denied = e.code.contains('Denied') || e.code.contains('denied') || e.code == 'permissionDenied';
      setState(() => _problem = denied ? _CameraProblem.denied : _CameraProblem.failed);
      return;
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _problem = _CameraProblem.failed);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _cameraIndex = index;
      _controller = controller;
      _problem = _CameraProblem.none;
    });
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cameraError)),
        );
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photo = _photo;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.takePhotoButton),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: photo != null ? Image.memory(photo, fit: BoxFit.contain) : _viewfinder(l10n))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: photo != null ? _reviewBar(l10n, photo) : _shutterBar(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder(AppLocalizations l10n) {
    if (_problem != _CameraProblem.none) {
      final text = switch (_problem) {
        _CameraProblem.noCamera => l10n.cameraNotFound,
        _CameraProblem.denied => l10n.cameraPermissionDenied,
        _ => l10n.cameraError,
      };
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.cameraRetro, size: 40, color: Colors.white54),
            const SizedBox(height: 16),
            Text(text, key: const Key('camera-problem'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return CameraPreview(controller);
  }

  Widget _shutterBar(AppLocalizations l10n) {
    final ready = _controller?.value.isInitialized == true && !_taking;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(width: 48),
        Semantics(
          button: true,
          label: l10n.cameraShutter,
          child: GestureDetector(
            key: const Key('camera-shutter'),
            onTap: ready ? () => unawaited(_takePicture()) : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: _cameras.length > 1
              ? IconButton(
                  tooltip: l10n.cameraSwitch,
                  color: Colors.white,
                  onPressed: ready ? () => unawaited(_open((_cameraIndex + 1) % _cameras.length)) : null,
                  icon: const FaIcon(FontAwesomeIcons.cameraRotate, size: 22),
                )
              : null,
        ),
      ],
    );
  }

  Widget _reviewBar(AppLocalizations l10n, Uint8List photo) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('camera-retake'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            onPressed: () => setState(() => _photo = null),
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14),
            label: Text(l10n.cameraRetake),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const Key('camera-use-photo'),
            onPressed: () => Navigator.of(context).pop(photo),
            icon: const FaIcon(FontAwesomeIcons.check, size: 14),
            label: Text(l10n.cameraUsePhoto),
          ),
        ),
      ],
    );
  }
}
