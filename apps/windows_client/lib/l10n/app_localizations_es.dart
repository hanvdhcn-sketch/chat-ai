// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get send => 'Enviar';

  @override
  String get messageHint => 'Escribe a Orbita…';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String usageRemaining(int remaining) {
    return '$remaining mensajes restantes hoy';
  }

  @override
  String get upgradePro => 'Mejorar a Pro';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Gratis';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Gratis: 60 mensajes/día · hasta 3 imágenes/mensaje (5 MB), 8/día';

  @override
  String get proQuotaHint =>
      'Pro: 400 mensajes/día · hasta 8 imágenes/mensaje (8 MB), 20/día';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Límite diario de mensajes alcanzado. Espera el próximo reinicio ($resetsAt) para continuar.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Límite diario de imágenes alcanzado. Espera el próximo reinicio ($resetsAt) para subir más.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Has agotado la cuota mensual de imágenes. Hasta $resetsAt, las subidas usan límites Gratis (3 por mensaje, 8 al día). El chat de texto no se ve afectado.';
  }

  @override
  String get conversations => 'Conversaciones';

  @override
  String get settings => 'Configuración';

  @override
  String get language => 'Idioma';

  @override
  String get languagePickerHint => 'Elige el idioma de la aplicación';

  @override
  String get searchChats => 'Buscar chats';

  @override
  String get library => 'Biblioteca';

  @override
  String get tools => 'Herramientas';

  @override
  String get about => 'Acerca de';

  @override
  String get stubAuthHint =>
      'La autenticación de desarrollo usa tokens stub hasta conectar Supabase.';

  @override
  String get emptyChat => 'Inicia una conversación';

  @override
  String get streaming => 'Pensando…';

  @override
  String get stop => 'Detener';

  @override
  String get storeStubHint =>
      'Concesión stub de Store solo para desarrollo (ALLOW_STORE_STUB_GRANT). Las builds normales usan compra integrada.';

  @override
  String get storePurchaseHint =>
      'Compra Pro en la app vía Microsoft Store (Go Pro). Store procesa el pago dentro de Orbita.';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get storeOnlyUpgradeMessage =>
      'La mejora a Pro solo está disponible en la versión instalada desde Microsoft Store.';

  @override
  String get storePurchaseFailed =>
      'No pudimos completar la compra. Inténtalo de nuevo más tarde.';

  @override
  String get authSignInTitle => 'Inicia sesión en Orbita';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authSignIn => 'Iniciar sesión';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authSwitchToSignUp => '¿Eres nuevo? Crea una cuenta';

  @override
  String get authSwitchToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authUseEmailCode => 'Enviarme un código de acceso por correo';

  @override
  String get authUsePassword => 'Usar contraseña';

  @override
  String get authSendCode => 'Enviar código';

  @override
  String get authCodeLabel => 'Código de tu correo';

  @override
  String get authVerifyCode => 'Verificar';

  @override
  String get authCodeSent =>
      'Enviamos un código a tu correo. Introdúcelo abajo.';

  @override
  String get authConfirmEmail =>
      'Revisa tu correo para confirmar tu dirección y luego inicia sesión.';

  @override
  String get authFailed =>
      'No se pudo iniciar sesión. Revisa tus datos e inténtalo de nuevo.';

  @override
  String get authNotConfigured =>
      'El inicio de sesión no está configurado en esta compilación.';

  @override
  String get authSignOut => 'Cerrar sesión';

  @override
  String get authAccount => 'Cuenta';
}
