import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';
import 'utils/deep_link_handler.dart';
import 'utils/router.dart';
import 'utils/share_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: ReppUpApp()));
}

class ReppUpApp extends ConsumerStatefulWidget {
  const ReppUpApp({super.key});

  @override
  ConsumerState<ReppUpApp> createState() => _ReppUpAppState();
}

class _ReppUpAppState extends ConsumerState<ReppUpApp> {
  final _deepLinkHandler = DeepLinkHandler();

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final uid = next.valueOrNull?.uid;
      if (uid != null) {
        PurchaseService.initialize(uid);
      }
    });

    final router = ref.watch(routerProvider);
    _deepLinkHandler.startListening(router);
    return MaterialApp.router(
      title: ShareConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
