import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for uploading documents to Cloudinary
/// Uses unsigned uploads (no API secret needed in app)
class CloudinaryService {
  // Cloudinary configuration - get from your Cloudinary dashboard
  static const String _cloudinaryUrl =
      'https://api.cloudinary.com/v1_1/rentdone/image/upload';

  // Unsigned upload preset (create in Cloudinary dashboard)
  static const String _uploadPreset = 'rentdone_unsigned';

  // Folder structure in Cloudinary
  static const String _tenantFolder = 'rentdone/tenants';
  static const String _documentsFolder = '$_tenantFolder/documents';

  /// Upload profile image to Cloudinary
  /// Returns the secure URL of uploaded image
  Future<String> uploadProfileImage({
    required File imageFile,
    required String tenantId,
  }) async {
    return _uploadFile(
      file: imageFile,
      folder: _tenantFolder,
      publicId: 'profile_$tenantId',
      resourceType: 'image',
    );
  }

  /// Upload ID proof document
  /// Returns the secure URL of uploaded document
  Future<String> uploadIdProof({
    required File documentFile,
    required String tenantId,
    required String idType, // aadhar, pan, passport, etc
  }) async {
    return _uploadFile(
      file: documentFile,
      folder: _documentsFolder,
      publicId: '${idType}_${tenantId}',
      resourceType: 'auto',
    );
  }

  /// Upload lease agreement
  /// Returns the secure URL of uploaded document
  Future<String> uploadAgreement({
    required File documentFile,
    required String tenantId,
  }) async {
    return _uploadFile(
      file: documentFile,
      folder: _documentsFolder,
      publicId: 'agreement_$tenantId',
      resourceType: 'auto',
    );
  }

  /// Upload additional documents
  /// Returns the secure URL of uploaded document
  Future<String> uploadDocument({
    required File documentFile,
    required String tenantId,
    required String documentType, // address_proof, bank_statement, etc
  }) async {
    return _uploadFile(
      file: documentFile,
      folder: _documentsFolder,
      publicId:
          '${documentType}_${tenantId}_${DateTime.now().millisecondsSinceEpoch}',
      resourceType: 'auto',
    );
  }

  /// Core upload method
  /// Handles the actual HTTP upload to Cloudinary
  Future<String> _uploadFile({
    required File file,
    required String folder,
    required String publicId,
    required String resourceType,
  }) async {
    try {
      // Validate file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      // Validate file size (max 50MB)
      final fileSize = await file.length();
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (fileSize > maxSize) {
        throw Exception('File size exceeds 50MB limit');
      }

      // Prepare multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_cloudinaryUrl));

      // Add form fields
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;
      request.fields['public_id'] = publicId;
      request.fields['resource_type'] = resourceType;
      request.fields['overwrite'] = 'true'; // Replace if exists
      request.fields['unique_filename'] = 'false';

      // Add file
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timed out after 30 seconds');
        },
      );

      // Handle response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }

      // Parse response and extract secure URL
      final Map<String, dynamic> responseData = _parseJsonResponse(
        response.body,
      );
      final secureUrl = responseData['secure_url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('No secure_url in Cloudinary response');
      }

      return secureUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Parse JSON response - simple implementation
  /// In production, use json dependency
  Map<String, dynamic> _parseJsonResponse(String jsonString) {
    try {
      // Extract secure_url using regex for simplicity
      final regex = RegExp(r'"secure_url":"([^"]+)"');
      final match = regex.firstMatch(jsonString);

      if (match != null) {
        return {'secure_url': match.group(1)};
      }

      throw Exception('Could not parse secure_url from response');
    } catch (e) {
      rethrow;
    }
  }

  /// Delete document from Cloudinary
  /// Requires public_id of the document
  Future<void> deleteDocument(String publicId) async {
    try {
      // Note: Deletion requires signature, use backend endpoint instead
      throw UnimplementedError(
        'Use backend endpoint for deletion (requires signature)',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get optimized URL for image display
  /// Applies transformations for better performance
  static String getOptimizedImageUrl(
    String cloudinaryUrl, {
    int maxWidth = 500,
    int quality = 80,
  }) {
    if (!cloudinaryUrl.contains('cloudinary.com')) {
      return cloudinaryUrl;
    }

    // Insert transformation parameters before filename
    // Format: /upload/w_500,q_80/...
    return cloudinaryUrl.replaceFirst(
      '/upload/',
      '/upload/w_$maxWidth,q_$quality/',
    );
  }
}

/// Riverpod Provider for CloudinaryService
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
