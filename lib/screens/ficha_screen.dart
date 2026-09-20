import 'package:flutter/material.dart';
import '../models/maquina.dart';
import '../widgets/risco_badge.dart';

class FichaScreen extends StatelessWidget {
  final Maquina maquina;
  const FichaScreen({super.key, required this.maquina});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Equipamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.computer, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(maquina.hostname, 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RiscoBadge(maquina: maquina),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ItemFicha(label: 'ID do Dispositivo', valor: maquina.idDispositivo),
          _ItemFicha(label: 'Tipo Identificador', valor: maquina.tipoIdentificador),
          _ItemFicha(label: 'Processador', valor: maquina.processador),
          _ItemFicha(label: 'Memória RAM', valor: '${maquina.memoriaRamGb} GB'),
          _ItemFicha(label: 'Status de Validação', valor: maquina.statusValidacao),
          _ItemFicha(
            label: 'Data de Registro', 
            valor: maquina.dataRegistro?.toLocal().toString().split('.')[0] ?? 'N/A'
          ),
        ],
      ),
    );
  }
}

class _ItemFicha extends StatelessWidget {
  final String label;
  final String valor;
  const _ItemFicha({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      hoverColor: Colors.transparent,
    );
  }
}
