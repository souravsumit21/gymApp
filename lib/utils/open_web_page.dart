import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openWebPage(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  final uri = Uri.parse(url);
  final openedInApp = await launchUrl(
    uri,
    mode: LaunchMode.inAppWebView,
    webViewConfiguration: const WebViewConfiguration(
      enableJavaScript: true,
      enableDomStorage: true,
    ),
  );

  if (!openedInApp) {
    final openedExternally = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!openedExternally && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $title')),
      );
    }
  }
}
