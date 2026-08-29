import 'package:flutter/material.dart';

import '../models/maquina.dart';
import '../services/firestore_service.dart';

class QuarentenaScreen extends StatelessWidget {
  const QuarentenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = FirestoreService();

    return StreamBuilder<List<Maquina>>(
      stream: servico.quarentena(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final itens = snap.data!;
        if (itens.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_outlined, size: 52, color: Color(0xFF2E9E5B)),
              SizedBox(height: 12),
              Text('Nenhuma maquina em quarentena.'),
            ]),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = itens[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.help_outline, color: Color(0xFF9B59B6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.serialBios,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text('${m.fabricante} ${m.modeloPc}'),
                    Text('${m.cpu} | ${m.ramGb} GB RAM | '
                        '${m.tipoDisco} ${m.capacidadeTexto}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF8A8F98))),
                    const SizedBox(height: 14),
                    Row(children: [
                      FilledButton.icon(
                        onPressed: () => _dialogoAprovar(context, servico, m),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Cadastrar'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            servico.marcarDescartada(m.serialBios),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Descartar'),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _dialogoAprovar(
      BuildContext context, FirestoreService servico, Maquina m) {
    final escola = TextEditingController();
    final sala = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cadastrar ${m.serialBios}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: escola,
            decoration: const InputDecoration(labelText: 'Escola'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sala,
            decoration: const InputDecoration(labelText: 'Sala'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              servico.aprovarMaquina(
                  m.serialBios, escola.text.trim(), sala.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
