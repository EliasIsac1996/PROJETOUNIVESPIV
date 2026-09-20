import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lista_screen.dart';
import 'screens/quarentena_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Requisito 2.4: Persistência offline para resiliência em escolas
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const BancadaApp());
}

class BancadaApp extends StatelessWidget {
  const BancadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventário Inteligente - UNIVESP',
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

  static const _titulos = ['Painel Coletor', 'Inventário Geral', 'Quarentena/Falhas'];
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
        elevation: 2,
      ),
      body: largo
          ? Row(children: [
              NavigationRail(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics),
                      label: Text('Painel')),
                  NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Inventário')),
                  NavigationRailDestination(
                      icon: Icon(Icons.biotech_outlined),
                      selectedIcon: Icon(Icons.biotech),
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
                    icon: Icon(Icons.analytics_outlined), label: 'Painel'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined), label: 'Inventário'),
                NavigationDestination(
                    icon: Icon(Icons.biotech_outlined), label: 'Quarentena'),
              ],
            ),
    );
  }
}
