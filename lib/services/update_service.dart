import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for MethodChannel
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String updateUrl = 'http://192.168.1.8:8000/latest.json';
  static const MethodChannel _platform = MethodChannel('com.example.quantum/installer'); // Platform channel

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(updateUrl));
      if (response.statusCode == 200) {
        final updateInfo = jsonDecode(response.body);
        final latestVersion = updateInfo['version'];
        final downloadUrl = updateInfo['url'];

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (latestVersion != currentVersion) {
          showDialog(
            context: context,
            barrierDismissible: false, // User must tap button to close
            builder: (context) => _UpdateDialog(downloadUrl: downloadUrl),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to check for update: $e');
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String downloadUrl;

  const _UpdateDialog({required this.downloadUrl});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String? _filePath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A new version of the app is available. Would you like to update?'),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 10),
            Text('${(_downloadProgress * 100).toStringAsFixed(0)}% downloaded'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: _isDownloading
              ? null
              : (_filePath != null ? _installUpdate : _startDownload),
          child: Text(_filePath != null ? 'Install' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await request.send();

      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/app-release.apk';
        final file = File(filePath);
        final sink = file.openWrite();

        int bytesReceived = 0;
        await for (var chunk in response.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          if (contentLength != null) {
            setState(() {
              _downloadProgress = bytesReceived / contentLength;
            });
          }
        }
        await sink.close();

        setState(() {
          _isDownloading = false;
          _filePath = filePath;
        });
        debugPrint('Download complete: $filePath');
      } else {
        debugPrint('Failed to download update: ${response.statusCode}');
        _showErrorDialog('Failed to download update. Status code: ${response.statusCode}');
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint('Error during download: $e');
      _showErrorDialog('Error during download: $e');
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _installUpdate() async {
    if (_filePath != null) {
      try {
        await UpdateService._platform.invokeMethod('installApk', {'filePath': _filePath});
        Navigator.of(context).pop(); // Close the dialog after initiating install
      } catch (e) {
        debugPrint('Error installing APK via platform channel: $e');
        _showErrorDialog('Error installing update: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
