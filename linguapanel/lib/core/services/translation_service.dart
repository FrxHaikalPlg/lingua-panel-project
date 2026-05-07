import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:linguapanel/core/config/app_config.dart';

/// Represents the current state of a translation job.
class JobStatus {
  final String jobId;
  final String status; // queued, running, done, failed
  final String message;
  final int progress;
  final int total;
  final int percent;
  final List<JobPageResult> results;
  final String? error;

  JobStatus({
    required this.jobId,
    required this.status,
    required this.message,
    required this.progress,
    required this.total,
    required this.percent,
    required this.results,
    this.error,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running' || status == 'queued';

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      jobId: json['job_id'] ?? '',
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      progress: json['progress'] ?? 0,
      total: json['total'] ?? 1,
      percent: json['percent'] ?? 0,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((r) => JobPageResult.fromJson(r))
          .toList(),
      error: json['error'],
    );
  }
}

class JobPageResult {
  final int page;
  final String filename;
  final String url;

  JobPageResult({
    required this.page,
    required this.filename,
    required this.url,
  });

  factory JobPageResult.fromJson(Map<String, dynamic> json) {
    return JobPageResult(
      page: json['page'] ?? 0,
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// API client for the LinguaPanel translation backend.
class TranslationService {
  /// Submit a single image for translation.
  /// Returns the job ID.
  static Future<String> submitImage(
    File imageFile, {
    String lang = 'ja',
    String orientation = 'vertical',
  }) async {
    final uri = Uri.parse(AppConfig.jobImageEndpoint).replace(
      queryParameters: {'lang': lang, 'orientation': orientation},
    );

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw TranslationException('Upload failed (${ response.statusCode}): $body');
    }

    final body = json.decode(await response.stream.bytesToString());
    return body['job_id'] as String;
  }

  /// Submit multiple images for chapter translation.
  /// Returns the job ID.
  static Future<String> submitChapter(
    List<File> imageFiles, {
    String lang = 'ja',
    String orientation = 'vertical',
  }) async {
    final uri = Uri.parse(AppConfig.jobChapterEndpoint).replace(
      queryParameters: {'lang': lang, 'orientation': orientation},
    );

    final request = http.MultipartRequest('POST', uri);
    for (final file in imageFiles) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw TranslationException('Upload failed (${response.statusCode}): $body');
    }

    final body = json.decode(await response.stream.bytesToString());
    return body['job_id'] as String;
  }

  /// Poll job status once.
  static Future<JobStatus> getJobStatus(String jobId) async {
    final uri = Uri.parse(AppConfig.jobStatusEndpoint(jobId));
    final response = await http.get(uri);

    if (response.statusCode == 404) {
      throw TranslationException('Job not found.');
    }
    if (response.statusCode != 200) {
      throw TranslationException('Failed to get status (${response.statusCode}).');
    }

    return JobStatus.fromJson(json.decode(response.body));
  }

  /// Stream job status updates by polling every [interval].
  /// Emits updates until the job is done or failed.
  static Stream<JobStatus> pollJobStatus(
    String jobId, {
    Duration interval = const Duration(seconds: 1),
  }) async* {
    while (true) {
      final status = await getJobStatus(jobId);
      yield status;

      if (status.isDone || status.isFailed) break;
      await Future.delayed(interval);
    }
  }

  /// Download a single translated page as bytes.
  static Future<Uint8List> downloadPage(String jobId, int page) async {
    final uri = Uri.parse(AppConfig.jobPageEndpoint(jobId, page));
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw TranslationException('Failed to download page $page (${response.statusCode}).');
    }

    return response.bodyBytes;
  }
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => message;
}
