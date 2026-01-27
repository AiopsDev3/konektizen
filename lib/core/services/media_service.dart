import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:konektizen/core/api/api_service.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission (for video)
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Capture photo from camera
  Future<File?> capturePhoto() async {
    try {
      final hasPermission = await Permission.camera.isGranted;
      if (!hasPermission) {
        final granted = await requestCameraPermission();
        if (!granted) return null;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      print('Error capturing photo: $e');
      return null;
    }
  }

  /// Record video from camera
  Future<File?> recordVideo() async {
    try {
      final hasCamera = await Permission.camera.isGranted;
      final hasMic = await Permission.microphone.isGranted;

      if (!hasCamera) {
        final granted = await requestCameraPermission();
        if (!granted) return null;
      }

      if (!hasMic) {
        final granted = await requestMicrophonePermission();
        if (!granted) return null;
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );

      if (video == null) return null;
      return File(video.path);
    } catch (e) {
      print('Error recording video: $e');
      return null;
    }
  }

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      print('Error picking from gallery: $e');
      return null;
    }
  }

  /// Upload media file to server
  /// Returns the public URL of the uploaded file
  Future<String?> uploadMedia(File file, String type) async {
    try {
      // For now, we'll use a simple approach
      // In production, you'd upload to Firebase Storage, AWS S3, etc.
      
      final uri = Uri.parse('${ApiService.baseUrl}/upload');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: path.basename(file.path),
        ),
      );
      
      request.fields['type'] = type;
      
      final response = await request.send();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);
        final String relativeUrl = data['url'];
        
        // Derive host from ApiService.baseUrl (remove /api)
        final String serverUrl = ApiService.baseUrl.replaceAll('/api', '');
        return '$serverUrl$relativeUrl';
      }
      
      return null;
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  /// Get file size in MB
  double getFileSizeMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Check if file size is acceptable (< 10MB for photos, < 50MB for videos)
  bool isFileSizeAcceptable(File file, String type) {
    final sizeMB = getFileSizeMB(file);
    if (type == 'photo') {
      return sizeMB < 10;
    } else if (type == 'video') {
      return sizeMB < 50;
    }
    return false;
  }
}

final mediaService = MediaService();
