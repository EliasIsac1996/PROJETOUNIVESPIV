<<<<<<< HEAD
# App Flutter — Painel da URE

## Primeira execução

```bash
flutter create . --platforms=web,android      # gera android/, web/, ios/
flutter pub get

# conecta ao Firebase (gera lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure

flutter run -d chrome                          # roda no navegador
```

**Rode primeiro em Web.** Sem emulador, sem loja, e a banca abre por link.
APK depois: `flutter build apk --release`.

## Telas

| Arquivo | Tela |
|---|---|
| `screens/dashboard_screen.dart` | Cartões de resumo + gráfico de distribuição de risco |
| `screens/lista_screen.dart` | Inventário com busca e filtro |
| `screens/ficha_screen.dart` | Ficha da máquina + histórico de risco |
| `screens/quarentena_screen.dart` | Máquinas desconhecidas aguardando decisão |
=======
# PROJETOUNIVESPIV
>>>>>>> 63fef65a0cf5d56645e5316a2aa40382fdec8d47
