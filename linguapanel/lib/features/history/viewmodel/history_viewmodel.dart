import 'dart:io';
import 'package:flutter/material.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:share_plus/share_plus.dart';

class HistoryViewModel extends ChangeNotifier {
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Get all history items (sorted newest first).
  List<TranslationHistory> get historyItems {
    try {
      return HistoryService.getAll();
    } catch (e) {
      setErrorMessage('Error loading history.');
      return [];
    }
  }

  /// Get only favorite items.
  List<TranslationHistory> get favoriteItems {
    try {
      return HistoryService.getFavorites();
    } catch (e) {
      return [];
    }
  }

  /// Force UI refresh (call when switching tabs).
  void refresh() {
    notifyListeners();
  }

  Future<void> toggleFavorite(String historyId) async {
    try {
      await HistoryService.toggleFavorite(historyId);
      notifyListeners();
    } catch (e) {
      setErrorMessage('Error updating favorite status.');
    }
  }

  Future<void> renameItem(String historyId, String newTitle) async {
    try {
      await HistoryService.rename(historyId, newTitle);
      notifyListeners();
    } catch (e) {
      setErrorMessage('Error renaming item.');
    }
  }

  Future<void> deleteHistoryItem(String historyId) async {
    try {
      await HistoryService.delete(historyId);
      notifyListeners();
    } catch (e) {
      setErrorMessage('Error deleting history item.');
    }
  }

  /// Share all translated images from a history item.
  Future<void> shareItem(TranslationHistory item) async {
    try {
      final files = <XFile>[];
      for (final path in item.translatedImagePaths) {
        final file = File(path);
        if (file.existsSync()) {
          files.add(XFile(path));
        }
      }
      if (files.isEmpty) {
        setErrorMessage('No images to share.');
        return;
      }
      await Share.shareXFiles(
        files,
        text: item.title,
      );
    } catch (e) {
      setErrorMessage('Error sharing images.');
    }
  }
}