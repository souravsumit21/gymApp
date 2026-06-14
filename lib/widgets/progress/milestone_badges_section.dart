import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/progress_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/share_config.dart';
import 'badge_share_card.dart';

class MilestoneBadgesSection extends StatelessWidget {
  final List<MilestoneBadge> badges;

  const MilestoneBadgesSection({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Milestone Badges',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '$unlocked of ${badges.length} unlocked',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: badges.length,
          itemBuilder: (context, i) => _BadgeCard(badge: badges[i]),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final MilestoneBadge badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: unlocked ? () => _showBadgeDetail(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unlocked
                ? AppTheme.cardBg
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unlocked ? AppTheme.primary.withOpacity(0.25) : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badge.emoji,
                style: TextStyle(
                  fontSize: 24,
                  color: unlocked ? null : Colors.black26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                badge.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: unlocked ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontSize: AppTheme.textLabel,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badge.subtitle,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: AppTheme.textLabel,
                ),
              ),
              const Spacer(),
              if (unlocked)
                Text(
                  'Tap to share',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: AppTheme.textLabel,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: badge.progressFraction,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${badge.current}/${badge.target}',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: AppTheme.textLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(badge.title,
                style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(badge.subtitle,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _shareBadge(ctx),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Badge'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareBadge(BuildContext context) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -1200,
        child: RepaintBoundary(
          key: key,
          child: BadgeShareCard(badge: badge),
        ),
      ),
    );
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final bytes = await _capture(key);
      final text =
          'I unlocked "${badge.title}" on ${ShareConfig.appName}! ${badge.emoji}';
      if (bytes != null) {
        final file = await _writeTemp(bytes, badge.id);
        await SharePlus.instance.share(
          ShareParams(text: text, files: [XFile(file.path)]),
        );
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } finally {
      entry.remove();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<Uint8List?> _capture(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<File> _writeTemp(Uint8List bytes, String id) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/badge_$id.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}
