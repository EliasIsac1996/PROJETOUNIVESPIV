import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // gerado por: flutterfire configure
import 'screens/dashboard_screen.dart';
import 'screens/lista_screen.dart';
import 'screens/quarentena_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BancadaApp());
}

class BancadaApp extends StatelessWidget {
  const BancadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario Preditivo - URE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6FD0),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6FD0),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _aba = 0;

  static const _titulos = ['Painel', 'Inventario', 'Quarentena'];
  static const _telas = [
    DashboardScreen(),
    ListaScreen(),
    QuarentenaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        centerTitle: false,
      ),
      body: largo
          ? Row(children: [
              NavigationRail(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Painel')),
                  NavigationRailDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt),
                      label: Text('Inventario')),
                  NavigationRailDestination(
                      icon: Icon(Icons.help_outline),
                      selectedIcon: Icon(Icons.help),
                      label: Text('Quarentena')),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _telas[_aba]),
            ])
          : _telas[_aba],
      bottomNavigationBar: largo
          ? null
          : NavigationBar(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined), label: 'Painel'),
                NavigationDestination(
                    icon: Icon(Icons.list_alt_outlined), label: 'Inventario'),
                NavigationDestination(
                    icon: Icon(Icons.help_outline), label: 'Quarentena'),
              ],
            ),
    );
  }
}
