import 'package:hive/hive.dart';

part 'translation_history.g.dart';

@HiveType(typeId: 0)
class TranslationHistory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String originalImagePath;

  @HiveField(2)
  final String translatedImagePath;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  bool isFavorite;

  @HiveField(5)
  final String sourceLang;

  @HiveField(6)
  final String orientation;

  TranslationHistory({
    required this.id,
    required this.originalImagePath,
    required this.translatedImagePath,
    required this.timestamp,
    this.isFavorite = false,
    this.sourceLang = 'ja',
    this.orientation = 'vertical',
  });
}