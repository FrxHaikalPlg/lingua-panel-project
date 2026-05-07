import 'package:flutter/material.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';

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

  /// Refresh the list (call after save/delete/toggle).
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

  Future<void> deleteHistoryItem(String historyId) async {
    try {
      await HistoryService.delete(historyId);
      notifyListeners();
    } catch (e) {
      setErrorMessage('Error deleting history item.');
    }
  }
}