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

  @override
  String get storeOnlyUpgradeMessage =>
      'A atualização para o Pro só está disponível na versão instalada pela Microsoft Store.';

  @override
  String get storePurchaseFailed =>
      'Não foi possível concluir a compra. Tente novamente mais tarde.';

  @override
  String get authSignInTitle => 'Iniciar sessão no Orbita';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Palavra-passe';

  @override
  String get authSignIn => 'Iniciar sessão';

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authSwitchToSignUp => 'É novo? Crie uma conta';

  @override
  String get authSwitchToSignIn => 'Já tem conta? Inicie sessão';

  @override
  String get authUseEmailCode => 'Enviar-me um código de acesso por e-mail';

  @override
  String get authUsePassword => 'Usar palavra-passe';

  @override
  String get authSendCode => 'Enviar código';

  @override
  String get authCodeLabel => 'Código do seu e-mail';

  @override
  String get authVerifyCode => 'Verificar';

  @override
  String get authCodeSent =>
      'Enviámos um código para o seu e-mail. Introduza-o abaixo.';

  @override
  String get authConfirmEmail =>
      'Verifique o seu e-mail para confirmar o endereço e depois inicie sessão.';

  @override
  String get authFailed =>
      'Falha ao iniciar sessão. Verifique os dados e tente novamente.';

  @override
  String get authNotConfigured =>
      'O início de sessão não está configurado nesta versão.';

  @override
  String get authSignOut => 'Terminar sessão';

  @override
  String get authAccount => 'Conta';
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

  @override
  String get storeOnlyUpgradeMessage =>
      'A atualização para o Pro só está disponível na versão instalada pela Microsoft Store.';

  @override
  String get storePurchaseFailed =>
      'Não foi possível concluir a compra. Tente novamente mais tarde.';

  @override
  String get authSignInTitle => 'Entrar no Orbita';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authSwitchToSignUp => 'Novo por aqui? Crie uma conta';

  @override
  String get authSwitchToSignIn => 'Já tem conta? Entre';

  @override
  String get authUseEmailCode => 'Enviar um código de acesso por e-mail';

  @override
  String get authUsePassword => 'Usar senha';

  @override
  String get authSendCode => 'Enviar código';

  @override
  String get authCodeLabel => 'Código do seu e-mail';

  @override
  String get authVerifyCode => 'Verificar';

  @override
  String get authCodeSent =>
      'Enviamos um código para o seu e-mail. Digite-o abaixo.';

  @override
  String get authConfirmEmail =>
      'Confira seu e-mail para confirmar o endereço e depois entre.';

  @override
  String get authFailed =>
      'Falha ao entrar. Confira os dados e tente novamente.';

  @override
  String get authNotConfigured => 'O login não está configurado nesta versão.';

  @override
  String get authSignOut => 'Sair';

  @override
  String get authAccount => 'Conta';
}
