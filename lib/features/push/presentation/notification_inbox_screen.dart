import 'package:flutter/material.dart';

import '../domain/push_models.dart';
import 'push_coordinator.dart';
import 'push_settings_screen.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({required this.coordinator, super.key});

  final PushCoordinator coordinator;

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  @override
  void initState() {
    super.initState();
    widget.coordinator.refreshInbox(force: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.coordinator,
    builder: (context, _) {
      final coordinator = widget.coordinator;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Avisos'),
          actions: [
            if (coordinator.unreadCount > 0)
              TextButton(
                onPressed: coordinator.inboxLoading
                    ? null
                    : coordinator.markAllNotificationsRead,
                child: const Text('Leer todos'),
              ),
            IconButton(
              tooltip: 'Configuración y pruebas',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      PushSettingsScreen(coordinator: widget.coordinator),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => coordinator.refreshInbox(force: true),
          child: _body(coordinator),
        ),
      );
    },
  );

  Widget _body(PushCoordinator coordinator) {
    if (coordinator.inboxLoading && coordinator.notifications.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (coordinator.inboxError != null && coordinator.notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(coordinator.inboxError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => coordinator.refreshInbox(force: true),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (coordinator.notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.notifications_none_rounded, size: 52),
          SizedBox(height: 12),
          Text(
            'No tenés avisos todavía.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Las actualizaciones del portal aparecerán acá aunque Firebase no esté activo.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      itemCount:
          coordinator.notifications.length +
          (coordinator.nextNotificationCursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == coordinator.notifications.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: coordinator.inboxLoading
                  ? null
                  : () => coordinator.refreshInbox(append: true),
              child: const Text('Cargar avisos anteriores'),
            ),
          );
        }
        final item = coordinator.notifications[index];
        return _NotificationCard(
          item: item,
          onTap: () => coordinator.openNotification(item),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: item.isRead ? Colors.white : const Color(0xFFFFF4F4),
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFF2B8BC),
      ),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE4E6),
        child: Icon(_icon(item.category), color: const Color(0xFFB4232F)),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900,
        ),
      ),
      subtitle: Text('${item.body}\n${_dateTime(item.createdAt)}'),
      isThreeLine: true,
      trailing: item.isRead
          ? const Icon(Icons.chevron_right_rounded)
          : const Icon(Icons.circle, size: 10, color: Color(0xFFDC1E2D)),
    ),
  );
}

IconData _icon(String category) => switch (category) {
  'room_reservation' => Icons.meeting_room_outlined,
  'vehicle_reservation' => Icons.directions_car_outlined,
  'parking_status' => Icons.local_parking_rounded,
  'expense_status' => Icons.receipt_long_outlined,
  'vehicle_notice' => Icons.warning_amber_rounded,
  _ => Icons.campaign_outlined,
};

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
