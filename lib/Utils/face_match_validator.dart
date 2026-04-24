import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FaceSignature {
  const FaceSignature({
    required this.eyeDistanceRatio,
    required this.mouthWidthRatio,
    required this.noseToMouthRatio,
    required this.eyeToNoseRatio,
  });

  final double eyeDistanceRatio;
  final double mouthWidthRatio;
  final double noseToMouthRatio;
  final double eyeToNoseRatio;

  Map<String, dynamic> toJson() => {
    'eyeDistanceRatio': eyeDistanceRatio,
    'mouthWidthRatio': mouthWidthRatio,
    'noseToMouthRatio': noseToMouthRatio,
    'eyeToNoseRatio': eyeToNoseRatio,
  };

  factory FaceSignature.fromJson(Map<String, dynamic> map) {
    return FaceSignature(
      eyeDistanceRatio: (map['eyeDistanceRatio'] as num?)?.toDouble() ?? 0,
      mouthWidthRatio: (map['mouthWidthRatio'] as num?)?.toDouble() ?? 0,
      noseToMouthRatio: (map['noseToMouthRatio'] as num?)?.toDouble() ?? 0,
      eyeToNoseRatio: (map['eyeToNoseRatio'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FaceValidationResult {
  const FaceValidationResult({
    required this.success,
    this.message,
    this.signature,
  });

  final bool success;
  final String? message;
  final FaceSignature? signature;
}

class FaceMatchValidator {
  FaceMatchValidator._();

  static const selfieSignatureKey = 'selfie_face_signature_v1';

  static FaceDetector buildDetector() {
    return FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
        minFaceSize: 0.12,
      ),
    );
  }

  static Future<FaceValidationResult> validatePhoto({
    required FaceDetector detector,
    required String imagePath,
    required bool isSelfieSlot,
    FaceSignature? reference,
  }) async {
    if (!await File(imagePath).exists()) {
      return const FaceValidationResult(
        success: false,
        message: 'Could not read selected photo.',
      );
    }

    try {
      final input = InputImage.fromFilePath(imagePath);
      final faces = await detector.processImage(input);
      if (faces.isEmpty) {
        return const FaceValidationResult(
          success: false,
          message: 'No face detected. Please use a clear face photo.',
        );
      }
      if (faces.length != 1) {
        return const FaceValidationResult(
          success: false,
          message: 'Please use a photo with exactly one face.',
        );
      }

      final face = faces.first;
      final box = face.boundingBox;
      if (box.width < 120 || box.height < 120) {
        return const FaceValidationResult(
          success: false,
          message: 'Move closer and use a clearer face photo.',
        );
      }

      final signature = _extractSignature(face);
      if (signature == null) {
        return const FaceValidationResult(
          success: false,
          message: 'Face landmarks not clear enough. Retake in better light.',
        );
      }

      if (isSelfieSlot) {
        return FaceValidationResult(success: true, signature: signature);
      }

      if (reference == null) {
        return const FaceValidationResult(
          success: false,
          message:
              'Selfie verification reference missing. Retake main selfie first.',
        );
      }

      if (!_looksLikeSamePerson(reference, signature)) {
        return const FaceValidationResult(
          success: false,
          message:
              'This face does not match your verified selfie. Use your own face photo.',
        );
      }

      return FaceValidationResult(success: true, signature: signature);
    } catch (_) {
      return const FaceValidationResult(
        success: false,
        message: 'Face check failed. Please retake the photo.',
      );
    }
  }

  static FaceSignature? _extractSignature(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    if (leftEye == null ||
        rightEye == null ||
        nose == null ||
        leftMouth == null ||
        rightMouth == null) {
      return null;
    }

    final width = face.boundingBox.width;
    final height = face.boundingBox.height;
    if (width <= 0 || height <= 0) return null;

    final eyeDistance = _distance(leftEye.x, leftEye.y, rightEye.x, rightEye.y);
    final mouthWidth = _distance(
      leftMouth.x,
      leftMouth.y,
      rightMouth.x,
      rightMouth.y,
    );
    final mouthCenterX = (leftMouth.x + rightMouth.x) / 2;
    final mouthCenterY = (leftMouth.y + rightMouth.y) / 2;
    final noseToMouth = _distance(nose.x, nose.y, mouthCenterX, mouthCenterY);
    final eyeCenterX = (leftEye.x + rightEye.x) / 2;
    final eyeCenterY = (leftEye.y + rightEye.y) / 2;
    final eyeToNose = _distance(eyeCenterX, eyeCenterY, nose.x, nose.y);

    return FaceSignature(
      eyeDistanceRatio: eyeDistance / width,
      mouthWidthRatio: mouthWidth / width,
      noseToMouthRatio: noseToMouth / height,
      eyeToNoseRatio: eyeToNose / height,
    );
  }

  static bool _looksLikeSamePerson(FaceSignature a, FaceSignature b) {
    final eyeDiff = (a.eyeDistanceRatio - b.eyeDistanceRatio).abs();
    final mouthDiff = (a.mouthWidthRatio - b.mouthWidthRatio).abs();
    final noseMouthDiff = (a.noseToMouthRatio - b.noseToMouthRatio).abs();
    final eyeNoseDiff = (a.eyeToNoseRatio - b.eyeToNoseRatio).abs();

    final weighted =
        eyeDiff * 0.3 +
        mouthDiff * 0.3 +
        noseMouthDiff * 0.2 +
        eyeNoseDiff * 0.2;

    return weighted <= 0.16 &&
        eyeDiff <= 0.22 &&
        mouthDiff <= 0.22 &&
        noseMouthDiff <= 0.22 &&
        eyeNoseDiff <= 0.22;
  }

  static double _distance(num x1, num y1, num x2, num y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  static Future<void> saveSelfieSignature(FaceSignature signature) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selfieSignatureKey, jsonEncode(signature.toJson()));
  }

  static Future<FaceSignature?> loadSelfieSignature() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(selfieSignatureKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FaceSignature.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSelfieSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(selfieSignatureKey);
  }
}
