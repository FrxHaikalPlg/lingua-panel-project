import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguapanel/core/services/history_service.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryViewModel extends ChangeNotifier {
  final HistoryService _historyService = HistoryService();
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Stream<List<TranslationHistory>> get historyStream {
    try {
      return _historyService.getHistoryStream().handleError((error) {
        if (error is FirebaseException) {
          setErrorMessage('Error fetching history: ${error.message}');
        } else {
          setErrorMessage('An unknown error occurred while fetching history.');
        }
      });
    } catch (e) {
      setErrorMessage('An unexpected error occurred.');
      return Stream.value([]);
    }
  }

  Future<void> toggleFavorite(String historyId, bool currentStatus) async {
    try {
      await _historyService.toggleFavorite(historyId, currentStatus);
    } on FirebaseException catch (e) {
      setErrorMessage('Error updating favorite status: ${e.message}');
    } catch (e) {
      setErrorMessage('An unknown error occurred.');
    }
  }

  Future<void> deleteHistoryItem(String historyId) async {
    try {
      await _historyService.deleteHistory(historyId);
    } on FirebaseException catch (e) {
      setErrorMessage('Error deleting history item: ${e.message}');
    } catch (e) {
      setErrorMessage('An unknown error occurred.');
    }
  }
}