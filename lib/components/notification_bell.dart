import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/notification_model.dart';
import 'package:anis_crm/services/notification_service.dart';

/// Notification bell icon with badge + dropdown panel.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    NotificationService.instance.addListener(_onUpdate);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = NotificationService.instance.unreadCount;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (_) => _NotificationOverlay(
          link: _link,
          onClose: () => _overlayController.hide(),
        ),
        child: IconButton(
          onPressed: () {
            if (_overlayController.isShowing) {
              _overlayController.hide();
            } else {
              _overlayController.show();
            }
          },
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count', style: const TextStyle(fontSize: 10)),
            child: Icon(Icons.notifications_outlined, size: 22, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          tooltip: 'Notifications',
        ),
      ),
    );
  }
}

class _NotificationOverlay extends StatelessWidget {
  final LayerLink link;
  final VoidCallback onClose;
  const _NotificationOverlay({required this.link, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Stack(children: [
      // Dismiss backdrop
      Positioned.fill(
        child: GestureDetector(onTap: onClose, child: const ColoredBox(color: Colors.transparent)),
      ),
      CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, 8),
        child: Material(
          color: dk ? cs.surface : cs.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 440),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                child: Row(children: [
                  Icon(Icons.notifications_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Notifications',
                      style: tt.bodyLarge?.semiBold.withColor(cs.onSurface)),
                  const Spacer(),
                  if (NotificationService.instance.unreadCount > 0)
                    TextButton(
                      onPressed: () => NotificationService.instance.markAllRead(),
                      child: Text('Mark all read',
                          style: tt.labelMedium),
                    ),
                ]),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
              // List
              Expanded(
                child: ListenableBuilder(
                  listenable: NotificationService.instance,
                  builder: (_, __) {
                    final notifs = NotificationService.instance.notifications;
                    if (notifs.isEmpty) {
                      return Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.notifications_none, size: 36, color: cs.onSurface.withValues(alpha: 0.15)),
                          const SizedBox(height: 8),
                          Text('All caught up!',
                              style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.4))),
                        ]),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.05)),
                      itemBuilder: (_, i) => _NotifTile(
                        notif: notifs[i],
                        cs: cs,
                        dk: dk,
                        onTap: () {
                          NotificationService.instance.markRead(notifs[i].id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final ColorScheme cs;
  final bool dk;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.cs, required this.dk, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(notif.type);
    final color = _colorForType(notif.type, cs);
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: notif.read ? null : cs.primary.withValues(alpha: 0.03),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notif.title,
                  style: tt.bodyMedium?.copyWith(
                      fontWeight: notif.read ? FontWeight.w400 : FontWeight.w600,
                      color: cs.onSurface)),
              if (notif.body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notif.body,
                    style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text(_timeAgo(notif.ts),
                  style: tt.labelSmall?.copyWith(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.3))),
            ]),
          ),
          if (!notif.read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'lead_assigned':
        return Icons.person_add_outlined;
      case 'task_assigned':
        return Icons.task_alt_outlined;
      case 'chat_message':
        return Icons.chat_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type, ColorScheme cs) {
    switch (type) {
      case 'lead_assigned':
        return cs.tertiary;
      case 'task_assigned':
        return cs.primary;
      case 'chat_message':
        return const Color(0xFF2E7D32);
      default:
        return cs.primary;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
