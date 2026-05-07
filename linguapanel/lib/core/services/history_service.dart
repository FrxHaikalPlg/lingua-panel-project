import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Local history storage using Hive.
class HistoryService {
  static const String _boxName = 'translation_history';
  static Box<TranslationHistory>? _box;

  /// Initialize Hive and register adapters. Call once at app startup.
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TranslationHistoryAdapter());
    }
    _box = await Hive.openBox<TranslationHistory>(_boxName);
  }

  static Box<TranslationHistory> get _historyBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('HistoryService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Get all history items sorted by timestamp (newest first).
  static List<TranslationHistory> getAll() {
    final items = _historyBox.values.toList();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// Get only favorite items.
  static List<TranslationHistory> getFavorites() {
    return getAll().where((item) => item.isFavorite).toList();
  }

  /// Save a new translation to history.
  /// Copies original and translated images to app-local storage.
  static Future<TranslationHistory> saveTranslation({
    required File originalImage,
    required Uint8List translatedImageBytes,
    required String sourceLang,
    required String orientation,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${appDir.path}/history');
    await historyDir.create(recursive: true);

    final id = const Uuid().v4();

    // Determine extension from original file
    final ext = originalImage.path.split('.').last.toLowerCase();

    // Copy original image
    final originalPath = '${historyDir.path}/${id}_original.$ext';
    await originalImage.copy(originalPath);

    // Save translated image
    final translatedPath = '${historyDir.path}/${id}_translated.$ext';
    await File(translatedPath).writeAsBytes(translatedImageBytes);

    final history = TranslationHistory(
      id: id,
      originalImagePath: originalPath,
      translatedImagePath: translatedPath,
      timestamp: DateTime.now(),
      sourceLang: sourceLang,
      orientation: orientation,
    );

    await _historyBox.put(id, history);
    return history;
  }

  /// Toggle favorite status of a history item.
  static Future<void> toggleFavorite(String id) async {
    final item = _historyBox.get(id);
    if (item != null) {
      item.isFavorite = !item.isFavorite;
      await item.save();
    }
  }

  /// Delete a history item and its associated image files.
  static Future<void> delete(String id) async {
    final item = _historyBox.get(id);
    if (item != null) {
      // Delete image files
      _tryDeleteFile(item.originalImagePath);
      _tryDeleteFile(item.translatedImagePath);
      await _historyBox.delete(id);
    }
  }

  static void _tryDeleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
