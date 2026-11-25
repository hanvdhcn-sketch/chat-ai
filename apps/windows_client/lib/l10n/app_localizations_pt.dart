// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Novo chat';

  @override
  String get send => 'Enviar';

  @override
  String get messageHint => 'Mensagem para o Orbita…';

  @override
  String get signIn => 'Entrar';

  @override
  String get signOut => 'Sair';

  @override
  String usageRemaining(int remaining) {
    return '$remaining mensagens restantes hoje';
  }

  @override
  String get upgradePro => 'Upgrade para Pro';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Grátis';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Grátis: 60 mensagens/dia · até 3 imagens/mensagem (5 MB), 8/dia';

  @override
  String get proQuotaHint =>
      'Pro: 400 mensagens/dia · até 8 imagens/mensagem (8 MB), 20/dia';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Limite diário de mensagens atingido. Aguarde a próxima reinicialização ($resetsAt) para continuar.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Limite diário de imagens atingido. Aguarde a próxima reinicialização ($resetsAt) para enviar mais.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Você atingiu a cota mensal de imagens. Até $resetsAt, os envios usam limites Grátis (3 por mensagem, 8 por dia). O chat de texto não é afetado.';
  }

  @override
  String get conversations => 'Conversas';

  @override
  String get settings => 'Configurações';

  @override
  String get language => 'Idioma';

  @override
  String get languagePickerHint => 'Escolha o idioma de exibição do app';

  @override
  String get searchChats => 'Pesquisar chats';

  @override
  String get library => 'Biblioteca';

  @override
  String get tools => 'Ferramentas';

  @override
  String get about => 'Sobre';

  @override
  String get stubAuthHint =>
      'Auth de desenvolvimento usa tokens stub até o Supabase ser conectado.';

  @override
  String get emptyChat => 'Comece uma conversa';

  @override
  String get streaming => 'Pensando…';

  @override
  String get stop => 'Parar';

  @override
  String get storeStubHint =>
      'Concessão stub da Store só para desenvolvimento (ALLOW_STORE_STUB_GRANT). Builds normais usam compra no app.';

  @override
  String get storePurchaseHint =>
      'Compre o Pro no app pela Microsoft Store (Go Pro). A Store processa o pagamento dentro do Orbita.';

  @override
  String get restorePurchases => 'Restaurar compras';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Novo chat';

  @override
  String get send => 'Enviar';

  @override
  String get messageHint => 'Mensagem para o Orbita…';

  @override
  String get signIn => 'Entrar';

  @override
  String get signOut => 'Sair';

  @override
  String usageRemaining(int remaining) {
    return '$remaining mensagens restantes hoje';
  }

  @override
  String get upgradePro => 'Upgrade para Pro';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Grátis';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Grátis: 60 mensagens/dia · até 3 imagens/mensagem (5 MB), 8/dia';

  @override
  String get proQuotaHint =>
      'Pro: 400 mensagens/dia · até 8 imagens/mensagem (8 MB), 20/dia';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Limite diário de mensagens atingido. Aguarde a próxima reinicialização ($resetsAt) para continuar.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Limite diário de imagens atingido. Aguarde a próxima reinicialização ($resetsAt) para enviar mais.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Você atingiu a cota mensal de imagens. Até $resetsAt, os envios usam limites Grátis (3 por mensagem, 8 por dia). O chat de texto não é afetado.';
  }

  @override
  String get conversations => 'Conversas';

  @override
  String get settings => 'Configurações';

  @override
  String get language => 'Idioma';

  @override
  String get languagePickerHint => 'Escolha o idioma de exibição do app';

  @override
  String get searchChats => 'Pesquisar chats';

  @override
  String get library => 'Biblioteca';

  @override
  String get tools => 'Ferramentas';

  @override
  String get about => 'Sobre';

  @override
  String get stubAuthHint =>
      'Auth de desenvolvimento usa tokens stub até o Supabase ser conectado.';

  @override
  String get emptyChat => 'Comece uma conversa';

  @override
  String get streaming => 'Pensando…';

  @override
  String get stop => 'Parar';

  @override
  String get storeStubHint =>
      'Concessão stub da Store só para desenvolvimento (ALLOW_STORE_STUB_GRANT). Builds normais usam compra no app.';

  @override
  String get storePurchaseHint =>
      'Compre o Pro no app pela Microsoft Store (Go Pro). A Store processa o pagamento dentro do Orbita.';

  @override
  String get restorePurchases => 'Restaurar compras';
}
