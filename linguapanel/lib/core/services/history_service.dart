import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Local history storage using Hive.
class HistoryService {
  static const String _boxName = 'translation_history_v2';
  static Box<TranslationHistory>? _box;

  /// Initialize Hive and register adapters. Call once at app startup.
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
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

  /// Get the next translation number for auto-naming.
  static int get _nextNumber => _historyBox.length + 1;

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

  /// Save a translation (single or chapter) to history.
  /// [translatedPages] is a list of image bytes — 1 for single, N for chapter.
  static Future<TranslationHistory> saveTranslation({
    required List<Uint8List> translatedPages,
    required String sourceLang,
    required String orientation,
    String? title,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${appDir.path}/history');
    await historyDir.create(recursive: true);

    final id = const Uuid().v4();
    final paths = <String>[];

    for (int i = 0; i < translatedPages.length; i++) {
      final path = '${historyDir.path}/${id}_page${i + 1}.jpg';
      await File(path).writeAsBytes(translatedPages[i]);
      paths.add(path);
    }

    final pageCount = translatedPages.length;
    final autoTitle = title ??
        'Translation-${_nextNumber} ($pageCount ${pageCount == 1 ? "image" : "images"})';

    final history = TranslationHistory(
      id: id,
      title: autoTitle,
      translatedImagePaths: paths,
      timestamp: DateTime.now(),
      sourceLang: sourceLang,
      orientation: orientation,
    );

    await _historyBox.put(id, history);
    return history;
  }

  /// Rename a history item.
  static Future<void> rename(String id, String newTitle) async {
    final item = _historyBox.get(id);
    if (item != null) {
      item.title = newTitle;
      await item.save();
    }
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
      for (final path in item.translatedImagePaths) {
        _tryDeleteFile(path);
      }
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
