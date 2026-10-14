import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../screens/user_session.dart';
import '../supabase_config.dart';

class BookCoverException implements Exception {
  const BookCoverException(this.message);
  final String message;
}

class PickedBookCover {
  const PickedBookCover({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

class BookCoverService {
  static const maxBytes = 20 * 1024 * 1024;
  final ImagePicker _picker = ImagePicker();

  Future<PickedBookCover?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file == null ? null : read(file);
  }

  Future<PickedBookCover?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final lost = await _picker.retrieveLostData();
    if (lost.isEmpty) return null;
    if (lost.exception != null) {
      throw const BookCoverException(
        'The selected image could not be recovered. Choose it again.',
      );
    }
    final files = lost.files;
    return files == null || files.isEmpty ? null : read(files.first);
  }

  Future<PickedBookCover> read(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const BookCoverException('Choose an image smaller than 20 MB.');
    }
    final bytes = await file.readAsBytes();
    return PickedBookCover(bytes: bytes, contentType: contentTypeFor(bytes));
  }

  static String contentTypeFor(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const BookCoverException('Choose an image smaller than 20 MB.');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255 &&
        bytes[bytes.length - 2] == 255 &&
        bytes[bytes.length - 1] == 217)
      return 'image/jpeg';
    if (bytes.length >= 33 &&
        List.generate(8, (index) => bytes[index]).join(',') ==
            '137,80,78,71,13,10,26,10' &&
        ascii.decode(bytes.sublist(12, 16), allowInvalid: true) == 'IHDR')
      return 'image/png';
    if (bytes.length >= 20 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP')
      return 'image/webp';
    throw const BookCoverException('Choose a JPG, PNG or WebP image.');
  }

  Future<String> upload(PickedBookCover cover) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        !user.emailVerified ||
        user.uid != UserSession.uid ||
        !UserSession.isAdmin) {
      throw const BookCoverException(
        'Sign in with an administrator account to upload covers.',
      );
    }
    final contentType = contentTypeFor(cover.bytes);
    final token = await user.getIdToken(true);
    if (token == null ||
        FirebaseAuth.instance.currentUser?.uid != user.uid ||
        user.uid != UserSession.uid) {
      throw const BookCoverException('Account changed. Sign in again.');
    }
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$supabaseProjectUrl/functions/v1/upload-book-cover'),
            headers: {
              'apikey': supabasePublishableKey,
              'Authorization': 'Bearer $token',
              'Content-Type': contentType,
            },
            body: cover.bytes,
          )
          .timeout(const Duration(seconds: 90));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw BookCoverException(
          data is Map && data['error'] is String
              ? data['error'] as String
              : 'Cover could not be uploaded. Please retry.',
        );
      }
      final url = data is Map ? data['url'] : null;
      if (url is! String ||
          !url.startsWith(
            '$supabaseProjectUrl/storage/v1/object/public/book-covers/${user.uid}/',
          )) {
        throw const BookCoverException(
          'Cover could not be uploaded. Please retry.',
        );
      }
      if (FirebaseAuth.instance.currentUser?.uid != user.uid ||
          user.uid != UserSession.uid) {
        throw const BookCoverException('Account changed. Sign in again.');
      }
      return url;
    } on TimeoutException {
      throw const BookCoverException(
        'Upload timed out. Check your connection and retry.',
      );
    } on BookCoverException {
      rethrow;
    } catch (_) {
      throw const BookCoverException(
        'Cover could not be uploaded. Check your connection and retry.',
      );
    } finally {
      client.close();
    }
  }
}
