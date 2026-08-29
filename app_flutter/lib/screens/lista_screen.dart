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

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _passa(Maquina m) {
    final termo = _busca.text.trim().toLowerCase();
    if (termo.isNotEmpty) {
      final alvo = '${m.serialBios} ${m.escola} ${m.sala} ${m.modeloPc} '
              '${m.modeloDisco}'
          .toLowerCase();
      if (!alvo.contains(termo)) return false;
    }
    return switch (_filtro) {
      'critico' => m.faixa == FaixaRisco.critico,
      'atencao' => m.faixa == FaixaRisco.atencao,
      'quarentena' => m.emQuarentena,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _busca,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Buscar por serial, escola, sala ou modelo',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final f in const [
            ('todas', 'Todas'),
            ('critico', 'Critico'),
            ('atencao', 'Atencao'),
            ('quarentena', 'Quarentena'),
          ])
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
      const SizedBox(height: 8),
      Expanded(
        child: StreamBuilder<List<Maquina>>(
          stream: _servico.maquinas(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final itens = snap.data!.where(_passa).toList();
            if (itens.isEmpty) {
              return const Center(child: Text('Nenhum resultado.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: itens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = itens[i];
                return Card(
                  child: ListTile(
                    leading: Icon(m.emQuarentena
                        ? Icons.help_outline
                        : Icons.desktop_windows_outlined),
                    title: Text(m.serialBios,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${m.escola} - ${m.sala}\n'
                        '${m.cpu} | ${m.ramGb} GB RAM | '
                        '${m.tipoDisco} ${m.capacidadeTexto}'),
                    isThreeLine: true,
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
