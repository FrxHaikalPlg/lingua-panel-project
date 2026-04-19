import 'package:cloud_firestore/cloud_firestore.dart';

class TranslationHistory {
  final String id;
  final String originalImageUrl;
  final String translatedImageUrl;
  final DateTime timestamp;
  bool isFavorite;

  TranslationHistory({
    required this.id,
    required this.originalImageUrl,
    required this.translatedImageUrl,
    required this.timestamp,
    this.isFavorite = false,
  });

  factory TranslationHistory.fromMap(Map<String, dynamic> map) {
    return TranslationHistory(
      id: map['id'] ?? '',
      originalImageUrl: map['originalImageUrl'] ?? '',
      translatedImageUrl: map['translatedImageUrl'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isFavorite: map['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalImageUrl': originalImageUrl,
      'translatedImageUrl': translatedImageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFavorite': isFavorite,
    };
  }

  TranslationHistory copyWith({
    String? id,
    String? originalImageUrl,
    String? translatedImageUrl,
    DateTime? timestamp,
    bool? isFavorite,
  }) {
    return TranslationHistory(
      id: id ?? this.id,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      translatedImageUrl: translatedImageUrl ?? this.translatedImageUrl,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}