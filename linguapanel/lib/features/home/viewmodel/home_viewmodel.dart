import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/core/services/translation_service.dart';

enum TranslationMode { single, chapter }

class HomeViewModel extends ChangeNotifier {
  // --- State ---
  File? _selectedImage;
  List<File> _selectedChapterImages = [];
  Uint8List? _translatedImageBytes;
  List<Uint8List> _translatedChapterPages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _progressMessage = '';
  int _progressPercent = 0;
  TranslationMode _mode = TranslationMode.single;

  // --- Settings ---
  String _selectedLang = 'ja';
  String _selectedOrientation = 'vertical';

  // --- Getters ---
  File? get selectedImage => _selectedImage;
  List<File> get selectedChapterImages => _selectedChapterImages;
  Uint8List? get translatedImageBytes => _translatedImageBytes;
  List<Uint8List> get translatedChapterPages => _translatedChapterPages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get progressMessage => _progressMessage;
  int get progressPercent => _progressPercent;
  String get selectedLang => _selectedLang;
  String get selectedOrientation => _selectedOrientation;
  TranslationMode get mode => _mode;

  final ImagePicker _picker = ImagePicker();

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
  void setMode(TranslationMode mode) {
    _mode = mode;
    clearState();
  }

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

  // --- Pick Single Image ---
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

  // --- Pick Multiple Images for Chapter ---
  Future<void> pickChapterImages() async {
    setErrorMessage(null);
    _translatedChapterPages = [];

    final pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      _selectedChapterImages = pickedFiles.map((xf) => File(xf.path)).toList();
    } else {
      setErrorMessage("No images selected.");
    }
    notifyListeners();
  }

  // --- Pick ZIP File for Chapter ---
  Future<void> pickZipFile() async {
    setErrorMessage(null);
    _translatedChapterPages = [];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null && result.files.single.path != null) {
      // For ZIP, we store a single file and use submitChapter with it
      _selectedChapterImages = [File(result.files.single.path!)];
    } else {
      setErrorMessage("No file selected.");
    }
    notifyListeners();
  }

  // --- Connectivity check ---
  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw TranslationException("No internet connection.");
    }
  }

  // --- Translate Single Image ---
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
      await _checkConnectivity();

      _progressMessage = 'Submitting...';
      notifyListeners();

      final jobId = await TranslationService.submitImage(
        _selectedImage!,
        lang: _selectedLang,
        orientation: _selectedOrientation,
      );

      await for (final status in TranslationService.pollJobStatus(jobId)) {
        _progressMessage = status.message;
        _progressPercent = status.percent;
        notifyListeners();

        if (status.isFailed) {
          throw TranslationException(status.error ?? 'Translation failed.');
        }

        if (status.isDone && status.results.isNotEmpty) {
          _progressMessage = 'Downloading result...';
          notifyListeners();

          _translatedImageBytes = await TranslationService.downloadPage(jobId, 1);

          // Save to local history
          if (_translatedImageBytes != null) {
            try {
              await HistoryService.saveTranslation(
                translatedPages: [_translatedImageBytes!],
                sourceLang: _selectedLang,
                orientation: _selectedOrientation,
              );
            } catch (_) {}
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

  // --- Translate Chapter ---
  Future<void> translateChapter() async {
    if (_selectedChapterImages.isEmpty) {
      setErrorMessage("Please select images or a ZIP file first.");
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _translatedChapterPages = [];
    _progressMessage = 'Uploading ${_selectedChapterImages.length} file(s)...';
    _progressPercent = 0;
    notifyListeners();

    try {
      await _checkConnectivity();

      _progressMessage = 'Submitting chapter...';
      notifyListeners();

      final jobId = await TranslationService.submitChapter(
        _selectedChapterImages,
        lang: _selectedLang,
        orientation: _selectedOrientation,
      );

      int downloadedPages = 0;

      await for (final status in TranslationService.pollJobStatus(jobId)) {
        _progressMessage = status.message;
        _progressPercent = status.percent;
        notifyListeners();

        if (status.isFailed) {
          throw TranslationException(status.error ?? 'Translation failed.');
        }

        // Progressive download: fetch new pages as they become available
        while (downloadedPages < status.results.length) {
          final pageNum = status.results[downloadedPages].page;
          final pageBytes = await TranslationService.downloadPage(jobId, pageNum);
          _translatedChapterPages.add(pageBytes);
          downloadedPages++;
          _progressMessage = 'Downloaded page $downloadedPages of ${status.total}...';
          notifyListeners();
        }

        if (status.isDone) {
          // Download any remaining pages
          while (downloadedPages < status.results.length) {
            final pageNum = status.results[downloadedPages].page;
            final pageBytes = await TranslationService.downloadPage(jobId, pageNum);
            _translatedChapterPages.add(pageBytes);
            downloadedPages++;
          }

          // Save all pages as one history entry
          _progressMessage = 'Saving to history...';
          notifyListeners();
          try {
            await HistoryService.saveTranslation(
              translatedPages: _translatedChapterPages,
              sourceLang: _selectedLang,
              orientation: _selectedOrientation,
            );
          } catch (_) {}
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
    _selectedChapterImages = [];
    _translatedImageBytes = null;
    _translatedChapterPages = [];
    _errorMessage = null;
    _isLoading = false;
    _progressMessage = '';
    _progressPercent = 0;
    notifyListeners();
  }

}
