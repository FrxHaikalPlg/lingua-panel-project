import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutViewModel with ChangeNotifier {
  String _appName = '';
  String _version = '';

  String get appName => _appName;
  String get version => _version;

  AboutViewModel() {
    _init();
  }

  Future<void> _init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _appName = packageInfo.appName;
    _version = packageInfo.version;
    notifyListeners();
  }

  Future<void> launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'haikalashshiddiq12@gmail.com',
      queryParameters: {
        'subject': 'Feedback for $_appName',
      },
    );

    if (!await launchUrl(emailLaunchUri)) {
      throw 'Could not launch email client';
    }
  }
}