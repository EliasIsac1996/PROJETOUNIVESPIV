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
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final itens = snap.data!;
        if (itens.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_user_outlined, size: 52, color: Colors.green),
              SizedBox(height: 12),
              Text('Nenhum equipamento pendente de validação.'),
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
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.idDispositivo,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('Hostname: ${m.hostname}'),
                    Text('CPU: ${m.processador} | RAM: ${m.memoriaRamGb}GB',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(children: [
                      FilledButton.icon(
                        onPressed: () => _dialogoAprovar(context, servico, m),
                        icon: const Icon(Icons.check),
                        label: const Text('Aprovar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => servico.marcarDescartada(m.idDispositivo),
                        child: const Text('Descartar', style: TextStyle(color: Colors.red)),
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

  void _dialogoAprovar(BuildContext context, FirestoreService servico, Maquina m) {
    final escola = TextEditingController();
    final sala = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validar Equipamento'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: escola, decoration: const InputDecoration(labelText: 'Escola')),
          TextField(controller: sala, decoration: const InputDecoration(labelText: 'Sala')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              servico.aprovarMaquina(m.idDispositivo, escola.text, sala.text);
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
