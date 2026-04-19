import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/core/config/app_config.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:uuid/uuid.dart';

class HomeViewModel extends ChangeNotifier {
  File? _selectedImage;
  Uint8List? _translatedImageBytes;
  bool _isLoading = false;
  String? _errorMessage;

  File? get selectedImage => _selectedImage;
  Uint8List? get translatedImageBytes => _translatedImageBytes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ImagePicker _picker = ImagePicker();

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> pickImage() async {
    setErrorMessage(null);
    _translatedImageBytes = null;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
    } else {
      setErrorMessage("No image selected.");
    }
    notifyListeners();
  }

  Future<void> translateImage() async {
    if (_selectedImage == null) {
      setErrorMessage("Please select an image first.");
      notifyListeners();
      return;
    }

    _isLoading = true;
    setErrorMessage(null);
    _translatedImageBytes = null;
    notifyListeners();

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        setErrorMessage("No internet connection. Please check your network.");
        _isLoading = false;
        notifyListeners();
        return;
      }

      var uri = Uri.parse(AppConfig.translateImageEndpoint);
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBytes = await response.stream.toBytes();
        _translatedImageBytes = responseBytes;
        _isLoading = false;
        notifyListeners(); 

        await _saveHistory(responseBytes);
      } else {
        final responseBody = await response.stream.bytesToString();
        _handleErrorResponse(response.statusCode, responseBody);
      }
    } on SocketException {
      setErrorMessage("Network error. Please check your internet connection.");
    } on FirebaseException catch (e) {
      setErrorMessage("Firebase error: ${e.message}");
    } catch (e) {
      setErrorMessage("An unexpected error occurred. Please try again later.");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleErrorResponse(int statusCode, String responseBody) {
    switch (statusCode) {
      case 400:
        setErrorMessage("Bad request. Please check the selected image and try again.");
        break;
      case 404:
        setErrorMessage("Translation service not found. Please try again later.");
        break;
      case 500:
        setErrorMessage("Server error. Please try again later.");
        break;
      default:
        setErrorMessage("Error: $statusCode - $responseBody");
    }
  }

  Future<void> _saveHistory(Uint8List translatedImageBytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in, cannot save to history.");
      return;
    }

    final historyId = const Uuid().v4();

    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now();

      final originalImagePath = 'images/${user.uid}/$historyId-original.jpg';
      final translatedImagePath = 'images/${user.uid}/$historyId-translated.jpg';

      final originalImageRef = storage.ref().child(originalImagePath);
      await originalImageRef.putFile(_selectedImage!);
      final originalImageUrl = await originalImageRef.getDownloadURL();

      final translatedImageRef = storage.ref().child(translatedImagePath);
      await translatedImageRef.putData(translatedImageBytes);
      final translatedImageUrl = await translatedImageRef.getDownloadURL();

      final newHistory = TranslationHistory(
        id: historyId,
        originalImageUrl: originalImageUrl,
        translatedImageUrl: translatedImageUrl,
        timestamp: timestamp,
      );

      await HistoryService().addHistory(newHistory);
    } on FirebaseException catch (e) {
      print("Error saving history to Firebase: ${e.message}");
      setErrorMessage("Could not save translation to history. Please check your connection.");
      notifyListeners();
    } catch (e) {
      print("Error saving history: $e");
    }
  }

  void clearState() {
    _selectedImage = null;
    _translatedImageBytes = null;
    setErrorMessage(null);
    _isLoading = false;
    notifyListeners();
  }
}
