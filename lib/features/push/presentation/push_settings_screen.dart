import 'package:flutter/material.dart';

import 'push_coordinator.dart';

class PushSettingsScreen extends StatelessWidget {
  const PushSettingsScreen({required this.coordinator, super.key});

  final PushCoordinator coordinator;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: coordinator,
    builder: (context, _) {
      final status = coordinator.status;
      final installation = coordinator.installation;
      final busy = coordinator.state == PushClientState.loading;
      final enabled = installation?.notificationsEnabled ?? false;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          actions: [
            IconButton(
              tooltip: 'Actualizar estado',
              onPressed: busy
                  ? null
                  : () => coordinator.startAuthenticated(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PushStatusCard(
              state: coordinator.state,
              configured: status?.provider.configured ?? false,
              message: coordinator.message,
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: SwitchListTile(
                key: const Key('pushMasterSwitch'),
                value: enabled,
                onChanged: busy || !coordinator.canConfigure
                    ? null
                    : (value) => coordinator.updatePreferences(
                        enabled: value,
                        categories: coordinator.selectedCategories,
                      ),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Recibir notificaciones'),
                subtitle: const Text(
                  'Los avisos no incluyen documentos, credenciales ni datos sensibles.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tipos de avisos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (status == null)
              const Center(child: CircularProgressIndicator())
            else
              ...status.categories.map(
                (category) => CheckboxListTile(
                  value: coordinator.selectedCategories.contains(category),
                  onChanged: busy || !coordinator.canConfigure
                      ? null
                      : (selected) {
                          final categories = {
                            ...coordinator.selectedCategories,
                          };
                          if (selected == true) {
                            categories.add(category);
                          } else {
                            if (categories.length == 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Debe quedar al menos un tipo de aviso. Podés desactivar todas las notificaciones con el interruptor principal.',
                                  ),
                                ),
                              );
                              return;
                            }
                            categories.remove(category);
                          }
                          coordinator.updatePreferences(
                            enabled: enabled,
                            categories: categories,
                          );
                        },
                  title: Text(_categoryLabel(category)),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al tocar un aviso, la app vuelve a consultar el portal y aplica tus permisos actuales.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PushStatusCard extends StatelessWidget {
  const _PushStatusCard({
    required this.state,
    required this.configured,
    required this.message,
  });

  final PushClientState state;
  final bool configured;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final active = state == PushClientState.registered;
    final color = active
        ? const Color(0xFF047857)
        : configured
        ? const Color(0xFFB45309)
        : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Notificaciones activas' : _stateLabel(state),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (message != null) ...[
                  const SizedBox(height: 5),
                  Text(message!, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _stateLabel(PushClientState state) => switch (state) {
  PushClientState.loading => 'Verificando configuración',
  PushClientState.serverNotConfigured => 'Pendiente de activación en Sistemas',
  PushClientState.clientNotConfigured => 'Falta configurar Firebase en la app',
  PushClientState.permissionDenied => 'Permiso deshabilitado en Android',
  PushClientState.disabled => 'Notificaciones deshabilitadas',
  PushClientState.error => 'No se pudo consultar el servicio',
  _ => 'Notificaciones pendientes',
};

String _categoryLabel(String value) => switch (value) {
  'general' => 'Avisos generales',
  'room_reservation' => 'Reservas de salas',
  'vehicle_reservation' => 'Reservas de vehículos',
  'parking_status' => 'Estados de estacionamiento',
  'expense_status' => 'Estados de gastos',
  'vehicle_notice' => 'Avisos y multas de vehículos',
  _ => value,
};
