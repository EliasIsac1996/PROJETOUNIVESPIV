import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/maquina.dart';
import '../services/firestore_service.dart';
import '../widgets/risco_badge.dart';

/// Nomes legiveis dos atributos SMART - o tecnico nao decora numero de atributo.
const _rotulosSmart = {
  'smart_5_raw': 'Setores realocados',
  'smart_9_raw': 'Horas ligado',
  'smart_12_raw': 'Ciclos de energia',
  'smart_187_raw': 'Erros nao corrigiveis',
  'smart_188_raw': 'Command timeout',
  'smart_194_raw': 'Temperatura (C)',
  'smart_197_raw': 'Setores pendentes',
  'smart_198_raw': 'Setores incorrigiveis',
  'smart_199_raw': 'Erros CRC (cabo)',
};

class FichaScreen extends StatelessWidget {
  final Maquina maquina;
  const FichaScreen({super.key, required this.maquina});

  @override
  Widget build(BuildContext context) {
    final cor = CoresRisco.de(maquina.faixa);
    final servico = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(maquina.serialBios)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ---- medidor de risco ----
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Text('Risco de falha do disco em 30 dias',
                style: TextStyle(fontSize: 13, color: cor)),
            const SizedBox(height: 8),
            Text(maquina.riscoTexto,
                style: TextStyle(
                    fontSize: 46, fontWeight: FontWeight.w800, color: cor)),
            Text(CoresRisco.rotulo(maquina.faixa),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: cor)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: maquina.riscoFalha ?? 0,
                minHeight: 9,
                backgroundColor: cor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(cor),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        _Secao(titulo: 'Localizacao', linhas: {
          'Escola': maquina.escola,
          'Sala': maquina.sala,
          'Status': maquina.status,
          'Ultima leitura': maquina.atualizadoEm
                  ?.toLocal()
                  .toString()
                  .substring(0, 16) ??
              '--',
        }),
        _Secao(titulo: 'Hardware', linhas: {
          'Fabricante': maquina.fabricante,
          'Modelo': maquina.modeloPc,
          'Processador': maquina.cpu,
          'Nucleos': '${maquina.cpuCores}',
          'Memoria': '${maquina.ramGb} GB em ${maquina.ramPentes} pente(s)',
          'Disco': '${maquina.modeloDisco} ${maquina.capacidadeTexto} '
              '(${maquina.tipoDisco})',
        }),
        _Secao(
          titulo: 'Atributos SMART',
          linhas: {
            for (final e in _rotulosSmart.entries)
              if (maquina.smart.containsKey(e.key))
                e.value: '${maquina.smart[e.key]}',
          },
        ),

        const SizedBox(height: 12),
        const Text('Evolucao do risco',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: servico.historico(maquina.serialBios),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pontos = snap.data!
                  .where((d) => d['risco_falha'] != null)
                  .toList();
              if (pontos.length < 2) {
                return const Center(
                  child: Text(
                    'Historico insuficiente.\n'
                    'A cada passagem pela bancada o grafico cresce.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8A8F98)),
                  ),
                );
              }
              return LineChart(LineChartData(
                minY: 0,
                maxY: 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < pontos.length; i++)
                        FlSpot(i.toDouble(),
                            (pontos[i]['risco_falha'] as num).toDouble()),
                    ],
                    isCurved: true,
                    barWidth: 3,
                    color: cor,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true, color: cor.withValues(alpha: 0.14)),
                  ),
                ],
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
              ));
            },
          ),
        ),
      ]),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final Map<String, String> linhas;
  const _Secao({required this.titulo, required this.linhas});

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: linhas.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 155,
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF8A8F98))),
                          ),
                          Expanded(
                              child: Text(e.value.isEmpty ? '--' : e.value,
                                  style: const TextStyle(fontSize: 13.5))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    ]);
  }
}
