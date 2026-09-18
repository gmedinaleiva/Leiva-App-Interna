import 'package:flutter/material.dart';

void main() => runApp(const LeivaApp());

abstract final class AppColors {
  static const red = Color(0xFFDC1F26);
  static const darkRed = Color(0xFF980811);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const canvas = Color(0xFFF4F6F9);
  static const border = Color(0xFFDCE2EA);
}

class LeivaApp extends StatelessWidget {
  const LeivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leiva Interna',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.red,
          primary: AppColors.red,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: _inputBorder(AppColors.border),
          enabledBorder: _inputBorder(AppColors.border),
          focusedBorder: _inputBorder(AppColors.red, width: 1.6),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

class LeivaBrand extends StatelessWidget {
  const LeivaBrand({super.key, this.light = false, this.compact = false});

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            color: light ? Colors.white : AppColors.red,
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          alignment: Alignment.center,
          child: Text(
            'L',
            style: TextStyle(
              color: light ? AppColors.red : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 21 : 26,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEIVA',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 16 : 19,
                letterSpacing: 1.8,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'HERMANOS S.A.',
              style: TextStyle(
                color: foreground.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                fontSize: compact ? 7 : 8,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController(text: 'demo.leiva');
  final _passwordController = TextEditingController(text: 'demoleiva');
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _submitting = false;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final form = _LoginForm(
            formKey: _formKey,
            userController: _userController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            rememberMe: _rememberMe,
            submitting: _submitting,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onRememberChanged: (value) =>
                setState(() => _rememberMe = value ?? false),
            onLogin: _login,
          );
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBFCFF), Color(0xFFEEF2F7)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 32 : 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.12),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: wide
                            ? Row(
                                children: [
                                  const Expanded(child: _LoginHero()),
                                  Expanded(child: form),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(children: [_mobileHero(), form]),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mobileHero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFE11D25), Color(0xFFC70F19)]),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LeivaBrand(light: true, compact: true),
        SizedBox(height: 30),
        Text(
          'Todo Leiva, en un solo lugar.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 650),
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE11D25), Color(0xFFC70F19), AppColors.darkRed],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -30,
            child: Opacity(
              opacity: 0.10,
              child: const Icon(
                Icons.apartment_rounded,
                size: 310,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LeivaBrand(light: true),
              const Spacer(),
              Text(
                'Todo Leiva,\nen un solo lugar.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Accedé a tus herramientas y gestiones internas\nde forma simple y segura.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroChip(Icons.verified_user_outlined, 'Acceso seguro'),
                  _HeroChip(Icons.devices_outlined, 'Android y web'),
                  _HeroChip(Icons.bolt_outlined, 'Gestión ágil'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Colors.white),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.submitting,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool submitting;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 42),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresá con tu cuenta corporativa.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 30),
                const _FieldLabel('Usuario'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('usernameField'),
                  controller: userController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'nombre.apellido',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresá tu usuario'
                      : null,
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('passwordField'),
                  controller: passwordController,
                  obscureText: obscurePassword,
                  onFieldSubmitted: (_) => onLogin(),
                  decoration: InputDecoration(
                    hintText: 'Ingresá tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Ingresá tu contraseña'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: AppColors.red,
                        onChanged: onRememberChanged,
                      ),
                    ),
                    const Text(
                      'Recordarme',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            '¿Olvidaste tu clave?',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('loginButton'),
                  onPressed: submitting ? null : onLogin,
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Ingresar'),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'Demo visual · Sin conexión a datos reales',
                    style: TextStyle(color: Color(0xFF8A94A6), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            leadingWidth: desktop ? 190 : 56,
            leading: desktop
                ? const Padding(
                    padding: EdgeInsets.only(left: 24),
                    child: LeivaBrand(compact: true),
                  )
                : null,
            title: desktop ? null : const LeivaBrand(compact: true),
            actions: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: () {},
                icon: const Badge(
                  smallSize: 8,
                  child: Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFE4E6),
                child: Text(
                  'GM',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      label: 'Módulos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Gestiones',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Perfil',
                    ),
                  ],
                ),
          body: Row(
            children: [
              if (desktop)
                _DesktopNavigation(
                  selectedIndex: _selectedIndex,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                ),
              const Expanded(child: _DashboardContent()),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 22, 12, 18),
    child: NavigationRail(
      extended: true,
      backgroundColor: Colors.white,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      indicatorColor: const Color(0xFFFFE4E6),
      selectedIconTheme: const IconThemeData(color: AppColors.red),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.red,
        fontWeight: FontWeight.w700,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Inicio'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: Text('Módulos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: Text('Gestiones'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          label: Text('Mi perfil'),
        ),
      ],
    ),
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  static const modules = [
    (
      'Proveedores',
      'Documentos y aprobaciones',
      Icons.inventory_2_outlined,
      Color(0xFF2563EB),
    ),
    (
      'Mis rendiciones',
      'Gastos y comprobantes',
      Icons.receipt_long_outlined,
      Color(0xFF7C3AED),
    ),
    (
      'Subproductos',
      'Contratos y entregas',
      Icons.local_shipping_outlined,
      Color(0xFF059669),
    ),
    (
      'Mi movilidad',
      'Reservas y vehículos',
      Icons.directions_car_outlined,
      Color(0xFFEA580C),
    ),
    (
      'Interbanking',
      'Saldos y movimientos',
      Icons.account_balance_outlined,
      Color(0xFF0891B2),
    ),
    (
      'Salas',
      'Reserva de espacios',
      Icons.meeting_room_outlined,
      Color(0xFF475569),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hola, Gustavo',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Estas son tus herramientas y gestiones de hoy.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D25), Color(0xFFB70D16)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Portal interno Leiva',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Esta demo muestra la nueva experiencia móvil y web.',
                            style: TextStyle(
                              color: Color(0xFFFFD8DA),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const _SectionTitle('Mis accesos'),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 540
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: modules
                        .map(
                          (module) => SizedBox(
                            width: width,
                            child: _ModuleCard(
                              title: module.$1,
                              subtitle: module.$2,
                              icon: module.$3,
                              color: module.$4,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 30),
              const _SectionTitle('Pendientes'),
              const SizedBox(height: 14),
              const _PendingCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title estará disponible en la próxima etapa.'),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8ECF1)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8ECF1)),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          backgroundColor: Color(0xFFFFF7ED),
          child: Icon(Icons.schedule_rounded, color: Color(0xFFEA580C)),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rendición pendiente de completar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Viaje Rosario · vence mañana',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Chip(
          label: Text('Pendiente'),
          backgroundColor: Color(0xFFFFF7ED),
          side: BorderSide.none,
        ),
      ],
    ),
  );
}
