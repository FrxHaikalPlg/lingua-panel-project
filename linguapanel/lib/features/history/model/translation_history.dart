import 'package:hive/hive.dart';

part 'translation_history.g.dart';

@HiveType(typeId: 1)
class TranslationHistory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final List<String> translatedImagePaths;

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
    required this.title,
    required this.translatedImagePaths,
    required this.timestamp,
    this.isFavorite = false,
    this.sourceLang = 'ja',
    this.orientation = 'vertical',
  });

  int get pageCount => translatedImagePaths.length;
  bool get isChapter => translatedImagePaths.length > 1;
}