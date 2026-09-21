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
              child: ListTile(
                leading: const Icon(Icons.vibration_rounded),
                title: const Text('Probar sonido y vibración'),
                subtitle: const Text(
                  'Genera una prueba local en este teléfono. No utiliza Firebase ni el portal.',
                ),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await coordinator
                            .showLocalTestNotification();
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Prueba local enviada al teléfono.'
                                  : coordinator.message ??
                                        'No se pudo ejecutar la prueba.',
                            ),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Enviar prueba real desde el portal'),
                subtitle: Text(
                  installation == null
                      ? 'Primero debe registrarse este teléfono con Firebase.'
                      : 'Solicita al portal un aviso FCM fijo para esta instalación. Límite: una por minuto.',
                ),
                trailing: const Icon(Icons.send_outlined),
                onTap: busy || installation == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await coordinator.sendRealPushTest();
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'El portal aceptó la prueba FCM real.'
                                  : coordinator.message ??
                                        'No se pudo enviar la prueba real.',
                            ),
                          ),
                        );
                      },
              ),
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
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              child: SwitchListTile(
                key: const Key('persistentPushSwitch'),
                value: coordinator.persistentEnrollmentEnabled,
                onChanged: busy || installation == null
                    ? null
                    : (value) => _changePersistentEnrollment(
                        context,
                        coordinator,
                        value,
                      ),
                secondary: const Icon(Icons.phonelink_lock_rounded),
                title: const Text(
                  'Mantener avisos al cerrar sesión',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  coordinator.persistentEnrollmentEnabled
                      ? 'Este teléfono seguirá vinculado. Sin sesión sólo se muestra un aviso genérico.${_expirationText(coordinator.persistentEnrollmentExpiresAt)}'
                      : 'Requiere tu consentimiento. Los detalles se muestran únicamente después de iniciar sesión.',
                ),
              ),
            ),
            if (coordinator.persistentEnrollmentEnabled) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('unlinkPersistentDeviceButton'),
                  onPressed: busy
                      ? null
                      : () => _changePersistentEnrollment(
                          context,
                          coordinator,
                          false,
                        ),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Desvincular este dispositivo'),
                ),
              ),
            ],
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

  Future<void> _changePersistentEnrollment(
    BuildContext context,
    PushCoordinator coordinator,
    bool enabled,
  ) async {
    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Desvincular dispositivo'),
          content: const Text(
            'Si continuás, este teléfono dejará de recibir avisos cuando cierres sesión. Podrás volver a vincularlo después.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Desvincular'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final success = await coordinator.setPersistentEnrollment(enabled);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? enabled
                    ? 'Avisos sin sesión activados en este teléfono.'
                    : 'El teléfono fue desvinculado.'
              : coordinator.message ?? 'No se pudo actualizar el enrolamiento.',
        ),
      ),
    );
  }
}

String _expirationText(DateTime? value) {
  if (value == null) return '';
  final argentina = value.toUtc().subtract(const Duration(hours: 3));
  String two(int number) => number.toString().padLeft(2, '0');
  return ' Se renueva al ingresar y vence el ${two(argentina.day)}/${two(argentina.month)}/${argentina.year}.';
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
