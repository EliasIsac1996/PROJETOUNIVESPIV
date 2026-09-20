import 'package:flutter/material.dart';
import '../models/maquina.dart';
import '../services/firestore_service.dart';
import '../widgets/risco_badge.dart';
import 'ficha_screen.dart';

class ListaScreen extends StatefulWidget {
  const ListaScreen({super.key});

  @override
  State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen> {
  final _servico = FirestoreService();
  final _busca = TextEditingController();
  String _filtro = 'todas';

  /// Requisito 2.4: Data Cleaning - Normaliza busca ignorando acentos e caracteres especiais
  String _sanitizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  bool _passa(Maquina m) {
    final termo = _sanitizar(_busca.text);
    if (termo.isNotEmpty) {
      // Normaliza os dados do banco antes de comparar
      final alvo = _sanitizar('${m.idDispositivo} ${m.hostname} ${m.processador}');
      if (!alvo.contains(termo)) return false;
    }
    
    if (_filtro == 'quarentena') return m.emQuarentena;
    if (_filtro == 'critico') return m.faixa == FaixaRisco.critico;
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _busca,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por ID ou Hostname...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _busca.text.isNotEmpty 
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _busca.clear();
                  setState(() {});
                }) 
              : null,
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final f in [('todas', 'Todos'), ('quarentena', 'Pendentes'), ('critico', 'Risco')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: _filtro == f.$1,
                onSelected: (_) => setState(() => _filtro = f.$1),
              ),
            ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<Maquina>>(
          stream: _servico.maquinas(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            
            final itens = snap.data!.where(_passa).toList();
            if (itens.isEmpty) return const Center(child: Text('Nenhum equipamento encontrado.'));
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itens.length,
              itemBuilder: (context, i) {
                final m = itens[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.computer),
                    title: Text(m.hostname, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${m.idDispositivo}\nCPU: ${m.processador}'),
                    trailing: RiscoBadge(maquina: m),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FichaScreen(maquina: m)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
