import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/security/local_access.dart';
import 'core/security/secure_session_store.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/expenses/data/expenses_api.dart';
import 'features/expenses/data/expenses_repository.dart';
import 'features/expenses/presentation/expenses_screen.dart';
import 'features/parking/data/parking_api.dart';
import 'features/parking/data/parking_repository.dart';
import 'features/parking/presentation/parking_screen.dart';
import 'features/push/data/push_api.dart';
import 'features/push/domain/push_repository.dart';
import 'features/push/presentation/push_coordinator.dart';
import 'features/push/presentation/notification_inbox_screen.dart';
import 'features/rooms/data/rooms_api.dart';
import 'features/rooms/data/rooms_repository.dart';
import 'features/rooms/presentation/rooms_screen.dart';
import 'features/vehicles/data/vehicles_api.dart';
import 'features/vehicles/data/vehicles_repository.dart';
import 'features/vehicles/presentation/vehicles_screen.dart';
import 'leiva_prelogin/leiva_prelogin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      leivaFirebaseMessagingBackgroundHandler,
    );
  }
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  runApp(kIsWeb ? const _WebPilotUnavailableApp() : const LeivaApp());
}

class _WebPilotUnavailableApp extends StatelessWidget {
  const _WebPilotUnavailableApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_android_rounded, size: 52),
                SizedBox(height: 18),
                Text(
                  'Piloto disponible en la app móvil',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 10),
                Text(
                  'El acceso web permanece deshabilitado durante esta etapa.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

abstract final class AppColors {
  static const red = Color(0xFFDC1F26);
  static const darkRed = Color(0xFF980811);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const canvas = Color(0xFFF4F6F9);
  static const border = Color(0xFFDCE2EA);
}

class LeivaApp extends StatefulWidget {
  const LeivaApp({
    super.key,
    this.authController,
    this.roomsGateway,
    this.vehiclesGateway,
    this.parkingGateway,
    this.expensesGateway,
    this.pushCoordinator,
    this.skipPrelogin = false,
  });

  final AuthController? authController;
  final RoomsGateway? roomsGateway;
  final VehiclesGateway? vehiclesGateway;
  final ParkingGateway? parkingGateway;
  final ExpensesGateway? expensesGateway;
  final PushCoordinator? pushCoordinator;
  final bool skipPrelogin;

  @override
  State<LeivaApp> createState() => _LeivaAppState();
}

class _LeivaAppState extends State<LeivaApp> {
  late final AuthController _authController;
  late final bool _ownsAuthController;
  RoomsGateway? _roomsGateway;
  VehiclesGateway? _vehiclesGateway;
  ParkingGateway? _parkingGateway;
  ExpensesGateway? _expensesGateway;
  PushCoordinator? _pushCoordinator;
  late final bool _ownsPushCoordinator;
  bool _preloginShown = false;

  @override
  void initState() {
    super.initState();
    _preloginShown = widget.skipPrelogin;
    _ownsAuthController = widget.authController == null;
    _ownsPushCoordinator = widget.pushCoordinator == null;
    if (widget.authController == null) {
      final sessionStore = SecureSessionStore();
      late final AuthController controller;
      final client = ApiClient(
        config: AppConfig(),
        sessionStore: sessionStore,
        onUnauthorized: () => controller.invalidateSession(),
        onForbidden: () => controller.refreshSession(),
      );
      controller = AuthController(
        AuthRepository(AuthApi(client.dio), sessionStore),
        localAccess: SecureLocalAccess(),
      );
      _authController = controller;
      _roomsGateway = RoomsRepository(RoomsApi(client.dio));
      _vehiclesGateway = VehiclesRepository(VehiclesApi(client.dio));
      _parkingGateway = ParkingRepository(ParkingApi(client.dio));
      _expensesGateway = ExpensesRepository(ExpensesApi(client.dio));
      _pushCoordinator =
          widget.pushCoordinator ??
          PushCoordinator(gateway: PushRepository(PushApi(client.dio)));
      controller.beforeLogout = _pushCoordinator!.beforeLogout;
      controller.onSessionEnded = _pushCoordinator!.enterUnauthenticatedMode;
    } else {
      _authController = widget.authController!;
      _roomsGateway = widget.roomsGateway;
      _vehiclesGateway = widget.vehiclesGateway;
      _parkingGateway = widget.parkingGateway;
      _expensesGateway = widget.expensesGateway;
      _pushCoordinator = widget.pushCoordinator;
      _authController.beforeLogout = _pushCoordinator?.beforeLogout;
      _authController.onSessionEnded =
          _pushCoordinator?.enterUnauthenticatedMode;
    }
    _authController.initialize();
    unawaited(_pushCoordinator?.startUnauthenticated());
  }

  @override
  void dispose() {
    if (_ownsAuthController) _authController.dispose();
    if (_ownsPushCoordinator) _pushCoordinator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) => MaterialApp(
        title: 'Leiva Interna',
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            SafeArea(top: false, child: child ?? const SizedBox.shrink()),
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
        home: switch (_authController.status) {
          AuthStatus.checkingSession => const _SessionLoadingScreen(),
          AuthStatus.biometricLocked => _BiometricLockScreen(
            authController: _authController,
          ),
          AuthStatus.authenticated => HomeScreen(
            authController: _authController,
            roomsGateway: _roomsGateway,
            vehiclesGateway: _vehiclesGateway,
            parkingGateway: _parkingGateway,
            expensesGateway: _expensesGateway,
            pushCoordinator: _pushCoordinator,
          ),
          _ => LeivaPrelogin(
            skipIntro: _preloginShown,
            onLoginReady: () {
              if (mounted && !_preloginShown) {
                setState(() => _preloginShown = true);
              }
            },
            loginBuilder: (_) => LoginScreen(authController: _authController),
          ),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LeivaBrand(),
          SizedBox(height: 28),
          CircularProgressIndicator(color: AppColors.red),
          SizedBox(height: 16),
          Text('Verificando sesión segura...'),
        ],
      ),
    ),
  );
}

class _BiometricLockScreen extends StatelessWidget {
  const _BiometricLockScreen({required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.red,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Desbloqueá Leiva Interna',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  authController.biometricAvailable
                      ? 'La sesión del portal sigue activa. Confirmá tu identidad para continuar.'
                      : 'La huella no está disponible en este dispositivo. Ingresá nuevamente con tu contraseña.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                if (authController.message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    authController.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
                const SizedBox(height: 28),
                if (authController.biometricAvailable)
                  FilledButton.icon(
                    key: const Key('biometricUnlockButton'),
                    onPressed: authController.unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Ingresar con huella'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: authController.usePasswordInstead,
                  child: const Text('Ingresar con contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
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
  const LoginScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late bool _rememberUsername;
  late bool _useBiometrics;

  @override
  void initState() {
    super.initState();
    final remembered = widget.authController.rememberedUsername;
    _userController.text = remembered ?? '';
    _rememberUsername = remembered != null && remembered.isNotEmpty;
    _useBiometrics = widget.authController.biometricEnabled;
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final password = _passwordController.text;
    await widget.authController.login(
      username: _userController.text,
      password: password,
      rememberUsername: _rememberUsername,
      enableBiometrics: _useBiometrics,
    );
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final compactMobile =
              !wide &&
              (constraints.maxWidth < 390 || constraints.maxHeight < 780);
          final submitting =
              widget.authController.status == AuthStatus.submittingCredentials;
          final form = _LoginForm(
            formKey: _formKey,
            userController: _userController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            submitting: submitting,
            message: widget.authController.message,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onLogin: _login,
            rememberUsername: _rememberUsername,
            biometricAvailable: widget.authController.biometricAvailable,
            useBiometrics: _useBiometrics,
            onRememberUsernameChanged: (value) =>
                setState(() => _rememberUsername = value),
            onUseBiometricsChanged: (value) =>
                setState(() => _useBiometrics = value),
            mobile: !wide,
            compactMobile: compactMobile,
          );
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBFCFF), Color(0xFFEEF2F7)],
              ),
            ),
            child: wide
                ? SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 34,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Expanded(child: _LoginHero()),
                                  Expanded(child: form),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight -
                              MediaQuery.viewPaddingOf(context).vertical,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              _mobileHero(compact: compactMobile),
                              Expanded(child: form),
                            ],
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

  Widget _mobileHero({required bool compact}) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      compact ? 22 : 26,
      compact ? 14 : 22,
      compact ? 22 : 26,
      compact ? 16 : 24,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFE11D25), Color(0xFFC70F19)]),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LeivaBrand(light: true, compact: true),
        SizedBox(height: compact ? 10 : 30),
        Text(
          compact ? 'Todo Leiva' : 'Todo Leiva, en un solo lugar.',
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 24,
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
    required this.submitting,
    required this.message,
    required this.onTogglePassword,
    required this.onLogin,
    required this.rememberUsername,
    required this.biometricAvailable,
    required this.useBiometrics,
    required this.onRememberUsernameChanged,
    required this.onUseBiometricsChanged,
    this.mobile = false,
    this.compactMobile = false,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool submitting;
  final String? message;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final bool rememberUsername;
  final bool biometricAvailable;
  final bool useBiometrics;
  final ValueChanged<bool> onRememberUsernameChanged;
  final ValueChanged<bool> onUseBiometricsChanged;
  final bool mobile;
  final bool compactMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compactMobile ? 0 : 520),
      padding: EdgeInsets.fromLTRB(
        mobile ? (compactMobile ? 22 : 26) : 42,
        mobile ? (compactMobile ? 18 : 30) : 42,
        mobile ? (compactMobile ? 22 : 26) : 42,
        mobile ? (compactMobile ? 14 : 24) : 42,
      ),
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
                Text(
                  'Bienvenido',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: compactMobile ? 26 : 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresá con tu cuenta corporativa.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                SizedBox(height: compactMobile ? 20 : 30),
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
                SizedBox(height: compactMobile ? 14 : 20),
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
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    key: const Key('rememberUsernameCheckbox'),
                    value: rememberUsername,
                    onChanged: submitting
                        ? null
                        : (value) => onRememberUsernameChanged(value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: const Text('Recordar mi usuario'),
                  ),
                ),
                if (biometricAvailable)
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      key: const Key('biometricLoginCheckbox'),
                      value: useBiometrics,
                      onChanged: submitting
                          ? null
                          : (value) => onUseBiometricsChanged(value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      secondary: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Usar huella en este dispositivo'),
                      subtitle: const Text(
                        'Desbloquea una sesión vigente; nunca guarda tu contraseña.',
                      ),
                    ),
                  ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message!,
                      key: const Key('authMessage'),
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: compactMobile ? 12 : 20),
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
                SizedBox(height: compactMobile ? 12 : 22),
                const Center(
                  child: Text(
                    'Conexión segura con el portal Leiva',
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
  const HomeScreen({
    required this.authController,
    required this.roomsGateway,
    required this.vehiclesGateway,
    required this.parkingGateway,
    required this.expensesGateway,
    this.pushCoordinator,
    super.key,
  });

  final AuthController authController;
  final RoomsGateway? roomsGateway;
  final VehiclesGateway? vehiclesGateway;
  final ParkingGateway? parkingGateway;
  final ExpensesGateway? expensesGateway;
  final PushCoordinator? pushCoordinator;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.pushCoordinator?.attachNavigationHandler(_handlePushTarget);
    final coordinator = widget.pushCoordinator;
    if (coordinator != null) unawaited(coordinator.startAuthenticated());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.pushCoordinator?.detachNavigationHandler();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.pushCoordinator?.refreshInbox());
    }
  }

  void _handlePushTarget(PushTarget target) {
    unawaited(_openPushTarget(target));
  }

  Future<void> _openPushTarget(PushTarget target) async {
    if (!mounted) return;
    if (target.type == PushTargetType.home) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _selectedIndex = 0);
      return;
    }
    final capabilities = widget.authController.session!.capabilities;
    if (target.type == PushTargetType.vehicleReservation) {
      if (widget.vehiclesGateway == null ||
          !capabilities.allows('vehicle_reservations', 'view')) {
        _showPushAccessDenied();
        return;
      }
      try {
        final reservation = await widget.vehiclesGateway!.reservation(
          target.resourceId!,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => VehicleTripScreen(
              gateway: widget.vehiclesGateway!,
              reservation: reservation,
              parkingGateway: widget.parkingGateway,
            ),
          ),
        );
      } catch (_) {
        if (mounted) _showPushOpenError();
      }
      return;
    }
    if (target.type == PushTargetType.roomReservation) {
      if (widget.roomsGateway == null ||
          !capabilities.allows('room_reservations', 'view')) {
        _showPushAccessDenied();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RoomReservationDetailScreen(
            gateway: widget.roomsGateway!,
            reservationId: target.resourceId!,
            currentUserId: widget.authController.session!.user.id,
            parkingGateway: widget.parkingGateway,
            canCreateParking: capabilities.allows('parking_requests', 'create'),
          ),
        ),
      );
      return;
    }
    if (target.type == PushTargetType.expenseRecord) {
      if (widget.expensesGateway == null ||
          !capabilities.allows('my_expenses', 'view')) {
        _showPushAccessDenied();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ExpenseRecordScreen(
            gateway: widget.expensesGateway!,
            documentId: target.resourceId!,
          ),
        ),
      );
      return;
    }
    if (widget.parkingGateway == null ||
        !capabilities.allows('parking_requests', 'view')) {
      _showPushAccessDenied();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ParkingScreen(
          gateway: widget.parkingGateway!,
          canCreate: capabilities.allows('parking_requests', 'create'),
          focusRequestId: target.resourceId,
        ),
      ),
    );
  }

  void _showPushAccessDenied() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Ya no tenés permiso para abrir ese aviso.')),
  );

  void _showPushOpenError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No pudimos abrir el contenido del aviso.')),
  );

  void _openPushSettings() {
    final coordinator = widget.pushCoordinator;
    if (coordinator == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationInboxScreen(coordinator: coordinator),
      ),
    );
  }

  String get _displayName =>
      widget.authController.session?.user.displayName ?? 'Usuario';

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    return parts.map((part) => part[0].toUpperCase()).join();
  }

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
              if (widget.pushCoordinator case final coordinator?)
                AnimatedBuilder(
                  animation: coordinator,
                  builder: (context, _) => IconButton(
                    tooltip: coordinator.unreadCount == 0
                        ? 'Notificaciones'
                        : '${coordinator.unreadCount} notificaciones sin leer',
                    onPressed: _openPushSettings,
                    icon: Badge(
                      isLabelVisible: coordinator.unreadCount > 0,
                      label: Text(
                        coordinator.unreadCount > 99
                            ? '99+'
                            : '${coordinator.unreadCount}',
                      ),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFFE4E6),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const Key('logoutButton'),
                tooltip: 'Cerrar sesión',
                onPressed: widget.authController.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
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
              Expanded(
                child: _DashboardContent(
                  selectedIndex: _selectedIndex,
                  displayName: _displayName,
                  currentUserId: widget.authController.session!.user.id,
                  capabilities: widget.authController.session!.capabilities,
                  roomsGateway: widget.roomsGateway,
                  vehiclesGateway: widget.vehiclesGateway,
                  parkingGateway: widget.parkingGateway,
                  expensesGateway: widget.expensesGateway,
                  biometricAvailable: widget.authController.biometricAvailable,
                  biometricEnabled: widget.authController.biometricEnabled,
                  onBiometricChanged:
                      widget.authController.configureBiometricUnlock,
                  onLogout: widget.authController.logout,
                ),
              ),
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
  const _DashboardContent({
    required this.selectedIndex,
    required this.displayName,
    required this.currentUserId,
    required this.capabilities,
    required this.roomsGateway,
    required this.vehiclesGateway,
    required this.parkingGateway,
    required this.expensesGateway,
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.onBiometricChanged,
    required this.onLogout,
  });

  final int selectedIndex;
  final String displayName;
  final int currentUserId;
  final AppCapabilities capabilities;
  final RoomsGateway? roomsGateway;
  final VehiclesGateway? vehiclesGateway;
  final ParkingGateway? parkingGateway;
  final ExpensesGateway? expensesGateway;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final Future<bool> Function(bool enabled) onBiometricChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final roomsEnabled =
        capabilities.allows('room_reservations', 'view') &&
        roomsGateway != null;
    final vehiclesEnabled =
        capabilities.allows('vehicle_reservations', 'view') &&
        vehiclesGateway != null;
    final parkingEnabled =
        capabilities.allows('parking_requests', 'view') &&
        parkingGateway != null;
    final expensesEnabled =
        capabilities.allows('my_expenses', 'view') && expensesGateway != null;
    final modules = [
      _ModuleData(
        'Reservas de vehículos',
        Icons.directions_car_outlined,
        const Color(0xFF2563EB),
        enabled: vehiclesEnabled,
        onTap: vehiclesEnabled
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehiclesScreen(
                    gateway: vehiclesGateway!,
                    parkingGateway: parkingEnabled ? parkingGateway : null,
                    canCreate: capabilities.allows(
                      'vehicle_reservations',
                      'create',
                    ),
                  ),
                ),
              )
            : null,
      ),
      _ModuleData(
        'Salas',
        Icons.meeting_room_outlined,
        const Color(0xFF7C3AED),
        enabled: roomsEnabled,
        onTap: roomsEnabled
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoomsScreen(
                    gateway: roomsGateway!,
                    currentUserId: currentUserId,
                    canCreate: capabilities.allows(
                      'room_reservations',
                      'create',
                    ),
                    parkingGateway: parkingEnabled ? parkingGateway : null,
                    canCreateParking: capabilities.allows(
                      'parking_requests',
                      'create',
                    ),
                  ),
                ),
              )
            : null,
      ),
      _ModuleData(
        'Estacionamiento',
        Icons.local_parking_outlined,
        const Color(0xFF059669),
        enabled: parkingEnabled,
        onTap: parkingEnabled
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ParkingScreen(
                    gateway: parkingGateway!,
                    canCreate: capabilities.allows(
                      'parking_requests',
                      'create',
                    ),
                  ),
                ),
              )
            : null,
      ),
      _ModuleData(
        'Mis gastos',
        Icons.receipt_long_outlined,
        const Color(0xFFEA580C),
        enabled: expensesEnabled,
        onTap: expensesEnabled
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpensesScreen(
                    gateway: expensesGateway!,
                    vehiclesGateway: vehiclesEnabled ? vehiclesGateway : null,
                    canUpload: capabilities.allows('my_expenses', 'upload'),
                  ),
                ),
              )
            : null,
      ),
    ];
    if (selectedIndex == 1) {
      return _SimplePage(
        title: 'Módulos',
        subtitle: 'Herramientas habilitadas para tu cuenta.',
        child: _ModulesGrid(modules: modules),
      );
    }
    if (selectedIndex == 2) {
      return _SimplePage(
        title: 'Gestiones',
        subtitle: 'Iniciá o consultá una gestión desde su módulo.',
        child: Column(
          children: modules
              .where((module) => module.enabled)
              .map(
                (module) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ModuleCard(
                    title: module.$1,
                    subtitle: 'Abrir gestiones',
                    icon: module.$2,
                    color: module.$3,
                    enabled: true,
                    onTap: module.onTap,
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    if (selectedIndex == 3) {
      return _SimplePage(
        title: 'Mi perfil',
        subtitle: 'Tu acceso se valida en tiempo real contra el portal Leiva.',
        child: _ProfileCard(
          displayName: displayName,
          enabledModules: modules.where((module) => module.enabled).length,
          totalModules: modules.length,
          biometricAvailable: biometricAvailable,
          biometricEnabled: biometricEnabled,
          onBiometricChanged: onBiometricChanged,
          onLogout: onLogout,
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $displayName',
                style: const TextStyle(
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
                            'La autenticación piloto está conectada de forma segura.',
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
              _ModulesGrid(modules: modules),
              const SizedBox(height: 30),
              const _SectionTitle('Estado del piloto'),
              const SizedBox(height: 14),
              const _PendingCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    ),
  );
}

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid({required this.modules});
  final List<_ModuleData> modules;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 540
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: modules
            .map(
              (module) => SizedBox(
                width: width,
                child: _ModuleCard(
                  title: module.$1,
                  subtitle: module.enabled ? 'Disponible' : 'Sin permiso',
                  icon: module.$2,
                  color: module.$3,
                  enabled: module.enabled,
                  onTap: module.onTap,
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.enabledModules,
    required this.totalModules,
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.onBiometricChanged,
    required this.onLogout,
  });
  final String displayName;
  final int enabledModules;
  final int totalModules;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final Future<bool> Function(bool enabled) onBiometricChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF1)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFFFE4E6),
              child: Text(
                displayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '$enabledModules de $totalModules módulos habilitados',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (biometricAvailable) ...[
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile(
            key: const Key('profileBiometricSwitch'),
            value: biometricEnabled,
            secondary: const Icon(Icons.fingerprint_rounded),
            title: const Text('Ingreso con huella'),
            subtitle: const Text(
              'Protege una sesión vigente sin guardar tu contraseña.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE8ECF1)),
            ),
            onChanged: (enabled) async {
              final changed = await onBiometricChanged(enabled);
              if (!changed && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo confirmar la huella.'),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión'),
        ),
      ),
    ],
  );
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

class _ModuleData {
  const _ModuleData(
    this.$1,
    this.$2,
    this.$3, {
    this.enabled = false,
    this.onTap,
  });

  final String $1;
  final IconData $2;
  final Color $3;
  final bool enabled;
  final VoidCallback? onTap;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
              Icon(
                enabled
                    ? Icons.arrow_forward_rounded
                    : Icons.lock_outline_rounded,
                color: enabled ? color : const Color(0xFF9CA3AF),
              ),
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
                'Conectado al portal',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Cada módulo y acción se habilita según los permisos vigentes de tu cuenta.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Chip(
          label: Text('Seguro'),
          backgroundColor: Color(0xFFEFF6FF),
          side: BorderSide.none,
        ),
      ],
    ),
  );
}
