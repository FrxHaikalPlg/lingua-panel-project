import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/core/services/translation_service.dart';

class HomeViewModel extends ChangeNotifier {
  // --- State ---
  File? _selectedImage;
  Uint8List? _translatedImageBytes;
  bool _isLoading = false;
  String? _errorMessage;
  String _progressMessage = '';
  int _progressPercent = 0;

  // --- Settings ---
  String _selectedLang = 'ja';
  String _selectedOrientation = 'vertical';

  // --- Getters ---
  File? get selectedImage => _selectedImage;
  Uint8List? get translatedImageBytes => _translatedImageBytes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get progressMessage => _progressMessage;
  int get progressPercent => _progressPercent;
  String get selectedLang => _selectedLang;
  String get selectedOrientation => _selectedOrientation;

  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _pollSubscription;

  // --- Available options ---
  static const Map<String, String> languageOptions = {
    'ja': 'Japanese',
    'ko': 'Korean',
    'ch_sim': 'Chinese (Simplified)',
    'en': 'English',
  };

  static const Map<String, String> orientationOptions = {
    'vertical': 'Vertical (Manga / Manhua)',
    'horizontal': 'Horizontal (Manhwa)',
  };

  // --- Setters ---
  void setLanguage(String lang) {
    _selectedLang = lang;
    notifyListeners();
  }

  void setOrientation(String orientation) {
    _selectedOrientation = orientation;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // --- Pick Image ---
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

  // --- Translate ---
  Future<void> translateImage() async {
    if (_selectedImage == null) {
      setErrorMessage("Please select an image first.");
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _translatedImageBytes = null;
    _progressMessage = 'Uploading...';
    _progressPercent = 0;
    notifyListeners();

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw TranslationException("No internet connection.");
      }

      // Submit job
      _progressMessage = 'Submitting...';
      notifyListeners();

      final jobId = await TranslationService.submitImage(
        _selectedImage!,
        lang: _selectedLang,
        orientation: _selectedOrientation,
      );

      // Poll for progress
      await for (final status in TranslationService.pollJobStatus(jobId)) {
        _progressMessage = status.message;
        _progressPercent = status.percent;
        notifyListeners();

        if (status.isFailed) {
          throw TranslationException(status.error ?? 'Translation failed.');
        }

        if (status.isDone && status.results.isNotEmpty) {
          // Download the translated page
          _progressMessage = 'Downloading result...';
          notifyListeners();

          _translatedImageBytes = await TranslationService.downloadPage(jobId, 1);

          // Save to local history
          if (_translatedImageBytes != null && _selectedImage != null) {
            try {
              await HistoryService.saveTranslation(
                originalImage: _selectedImage!,
                translatedImageBytes: _translatedImageBytes!,
                sourceLang: _selectedLang,
                orientation: _selectedOrientation,
              );
            } catch (_) {
              // Don't fail the translation if history save fails
            }
          }
        }
      }
    } on TranslationException catch (e) {
      setErrorMessage(e.message);
    } on SocketException {
      setErrorMessage("Network error. Please check your connection.");
    } catch (e) {
      setErrorMessage("An unexpected error occurred. Please try again.");
    } finally {
      _isLoading = false;
      _progressMessage = '';
      _progressPercent = 0;
      notifyListeners();
    }
  }

  void clearState() {
    _selectedImage = null;
    _translatedImageBytes = null;
    _errorMessage = null;
    _isLoading = false;
    _progressMessage = '';
    _progressPercent = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollSubscription?.cancel();
    super.dispose();
  }
}
