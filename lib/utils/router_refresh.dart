import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/auth_service.dart';

/// Keeps a single [GoRouter] instance alive while auth/profile changes
/// re-run redirects — avoids remounting splash on every auth tick.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, next) {
      _listenToProfile(next.valueOrNull?.uid);
      notifyListeners();
    });
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<UserProfile?>>? _profileSub;
  String? _profileUid;

  void _listenToProfile(String? uid) {
    if (uid == _profileUid) return;
    _profileSub?.close();
    _profileSub = null;
    _profileUid = uid;
    if (uid == null) return;
    _profileSub = _ref.listen(userProfileProvider(uid), (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _profileSub?.close();
    super.dispose();
  }
}

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
