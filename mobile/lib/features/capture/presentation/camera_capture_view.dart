import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../data/face_capture_service.dart';
import '../domain/capture_session_payload.dart';

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({super.key, this.session, this.captureToken});

  final CaptureSessionPayload? session;
  final String? captureToken;

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView> {
  CameraController? _cameraController;
  bool _initializing = true;
  bool _isCapturing = false;
  bool _isUploading = false;
  XFile? _lastCapture;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _initializing = true;
      _statusMessage = 'Starting camera...';
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'No camera detected on this device.';
          _initializing = false;
        });
        return;
      }

      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await _cameraController?.dispose();
      final controller = CameraController(
        preferredCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializing = false;
        _statusMessage = null;
      });
    } catch (error) {
      debugPrint('Camera initialization failed: $error');
      setState(() {
        _statusMessage = 'Unable to start camera. Please try again.';
        _initializing = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing photo...';
    });

    try {
      final rawCapture = await controller.takePicture();

      if (!mounted) {
        return;
      }

      final processedPath = await _detectAndCropFace(rawCapture.path);

      if (!mounted) {
        return;
      }

      if (processedPath == null) {
        setState(() {
          _lastCapture = rawCapture;
          _statusMessage = 'No face detected. Please retry.';
        });
        return;
      }

      setState(() {
        _lastCapture = XFile(processedPath);
        _statusMessage = 'Face ready. Tap upload when ready.';
      });
    } catch (error) {
      debugPrint('Photo capture failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Failed to capture photo. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _uploadCapturedPhoto() async {
    final capture = _lastCapture;
    final session = widget.session;

    if (capture == null) {
      setState(() {
        _statusMessage = 'Capture a photo first.';
      });
      return;
    }

    if (session == null) {
      setState(() {
        _statusMessage = 'Select a session before uploading.';
      });
      return;
    }

    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading photo...';
    });

    try {
      final service = context.read<FaceCaptureService>();
      final bytes = await File(capture.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final payloadImage = 'data:image/jpeg;base64,$base64Image';

      if (widget.captureToken != null) {
        try {
          await service.notifyCapturePreview(
            token: widget.captureToken!,
            base64Image: payloadImage,
          );
        } catch (error) {
          debugPrint('Preview notification failed: $error');
        }
      }

      final message = await service.uploadFaceImageBytes(
        base64Image: payloadImage,
        session: session,
        captureToken: widget.captureToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = message;
      });
    } on FaceCaptureException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error.message;
      });
    } catch (error) {
      debugPrint('Photo upload failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Upload failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _detectAndCropFace(String filePath) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      final largestFace = faces.reduce((current, next) {
        final currentArea =
            current.boundingBox.width * current.boundingBox.height;
        final nextArea = next.boundingBox.width * next.boundingBox.height;
        return nextArea > currentArea ? next : current;
      });

      final bytes = await File(filePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        return null;
      }

      final bounds = largestFace.boundingBox;

      final expandX = bounds.width * 0.35;
      final expandY = bounds.height * 0.55;

      var left = (bounds.left - expandX).floor();
      var top = (bounds.top - expandY * 0.6).floor();
      var width = (bounds.width + expandX * 2).ceil();
      var height = (bounds.height + expandY * 1.6).ceil();

      left = max(0, min(left, original.width - 1));
      top = max(0, min(top, original.height - 1));
      width = max(1, min(width, original.width - left));
      height = max(1, min(height, original.height - top));

      final cropped = img.copyCrop(
        original,
        x: left,
        y: top,
        width: width,
        height: height,
      );

      final croppedBytes = img.encodeJpg(cropped, quality: 95);
      final outputPath = p.join(
        File(filePath).parent.path,
        '${p.basenameWithoutExtension(filePath)}_cropped.jpg',
      );

      final output = await File(
        outputPath,
      ).writeAsBytes(croppedBytes, flush: true);

      return output.path;
    } catch (error) {
      debugPrint('Face detection failed: $error');
      return null;
    } finally {
      await faceDetector.close();
    }
  }

  Widget _buildPreview(ThemeData theme, double previewHeight) {
    final controller = _cameraController;

    if (_initializing) {
      return Container(
        height: previewHeight,
        alignment: Alignment.center,
        child: const CircularProgressIndicator.adaptive(),
      );
    }

    if (controller != null && controller.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: previewHeight,
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                const FaceAlignmentOverlay(),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: previewHeight,
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        _statusMessage ?? 'Camera preview unavailable.',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _cameraController;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.vertical;
    const controlsReserve = 220.0; // Approximate space needed for controls.
    const minPreviewHeight = 340.0;
    const minButtonClearance = 120.0;

    double previewHeight;
    if (availableHeight.isFinite && availableHeight > 0) {
      if (availableHeight <= minPreviewHeight + minButtonClearance) {
        previewHeight = availableHeight * 0.7;
      } else {
        final desiredHeight = availableHeight - controlsReserve;
        final maxAllowed = availableHeight - minButtonClearance;
        final clampedHeight =
            desiredHeight.clamp(minPreviewHeight, maxAllowed) as num;
        previewHeight = clampedHeight.toDouble();
      }
    } else {
      previewHeight = 420;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPreview(theme, previewHeight),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                _initializing ||
                        _isCapturing ||
                        _isUploading ||
                        controller == null
                    ? null
                    : _capturePhoto,
            icon:
                _isCapturing
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                    : const Icon(Icons.camera_alt_outlined),
            label: Text(_isCapturing ? 'Capturing...' : 'Capture Photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _initializing || _isUploading || _lastCapture == null
                    ? null
                    : _uploadCapturedPhoto,
            icon:
                _isUploading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                    : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (_lastCapture != null) ...[
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last capture preview',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_lastCapture!.path),
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FaceAlignmentOverlay extends StatelessWidget {
  const FaceAlignmentOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: CustomPaint(painter: _FaceGuidancePainter()),
    );
  }
}

class _FaceGuidancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x66000000);

    final fullRect = Offset.zero & size;
    final guideSide = min(size.width, size.height) * 0.78;
    final guideRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: guideSide,
      height: guideSide,
    );

    final fullPath = Path()..addRect(fullRect);
    final squarePath = Path()..addRRect(RRect.fromRectXY(guideRect, 18, 18));
    final maskPath = Path.combine(
      PathOperation.difference,
      fullPath,
      squarePath,
    );
    canvas.drawPath(maskPath, overlayPaint);

    final borderPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectXY(guideRect, 18, 18), borderPaint);

    final pointPaint =
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.fill;
    final pointRadius = max(3.0, guideRect.width * 0.018);

    for (final point in _landmarkPoints(guideRect)) {
      canvas.drawCircle(point, pointRadius, pointPaint);
    }
  }

  List<Offset> _landmarkPoints(Rect guideRect) {
    const normalized = <Offset>[
      Offset(0.32, 0.38), // left eye
      Offset(0.68, 0.38), // right eye
      Offset(0.50, 0.56), // nose tip
      Offset(0.36, 0.72), // mouth left
      Offset(0.50, 0.76), // mouth center
      Offset(0.64, 0.72), // mouth right
      Offset(0.42, 0.82), // lower lip left
      Offset(0.58, 0.82), // lower lip right
    ];

    return normalized
        .map(
          (relative) => Offset(
            guideRect.left + relative.dx * guideRect.width,
            guideRect.top + relative.dy * guideRect.height,
          ),
        )
        .toList(growable: false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
