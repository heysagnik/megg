import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_analysis_result.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _baseUrl = 'https://image-recognise.vercel.app';
  final Dio _dio = Dio();

  /// Analyze an image using AI recognition
  /// Compresses the image before upload
  Future<AIAnalysisResult> analyzeImage(File imageFile) async {
    try {
      // Compress image
      final compressedFile = await _compressImage(imageFile);
      
      debugPrint('[AI] Uploading image to API...');
      
      // Create form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'image.jpg',
        ),
      });

      // Upload to API
      final response = await _dio.post(
        '$_baseUrl/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint('[AI] Response: ${response.data}');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return AIAnalysisResult.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Failed to analyze image');
      }
    } on DioException catch (e) {
      debugPrint('[AI] Dio error: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Connection timeout. Please try again.');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('[AI] Error: $e');
      rethrow;
    }
  }

  /// Compress image to reduce upload size
  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        debugPrint('[AI] Compressed: ${file.lengthSync()} -> ${compressedFile.lengthSync()} bytes');
        return compressedFile;
      }
      
      return file;
    } catch (e) {
      debugPrint('[AI] Compression failed, using original: $e');
      return file;
    }
  }
}
