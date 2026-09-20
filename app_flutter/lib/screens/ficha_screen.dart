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

/// Atributos cujo valor diferente de zero merece destaque visual.
/// Horas ligado, ciclos e temperatura sao informativos, nao sintomas.
const _sintomas = {
  'smart_5_raw', 'smart_187_raw', 'smart_197_raw', 'smart_198_raw',
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
                    fontSize: 44, fontWeight: FontWeight.w800, color: cor)),
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

        _SecaoSmart(smart: maquina.smart),

        const SizedBox(height: 12),
        const Text('Evolucao do risco',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Cada ponto e uma passagem pela bancada',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF8A8F98))),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: servico.historico(maquina.serialBios),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pontos =
                  snap.data!.where((d) => d['risco_falha'] != null).toList();

              if (pontos.length < 2) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timeline_outlined,
                          size: 34, color: Color(0xFF8A8F98)),
                      const SizedBox(height: 10),
                      Text(
                        pontos.length == 1
                            ? 'Apenas uma leitura registrada.\n'
                                'O grafico aparece a partir da segunda passagem.'
                            : 'Sem historico registrado ainda.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF8A8F98)),
                      ),
                    ],
                  ),
                );
              }

              return _GraficoEvolucao(pontos: pontos, cor: cor);
            },
          ),
        ),
      ]),
    );
  }
}

/// Grafico de evolucao do risco.
///
/// A versao anterior deixava o fl_chart decidir os rotulos do eixo X, que
/// entao desenhava um rotulo por unidade decimal - centenas de numeros
/// ilegiveis embaixo da linha. Aqui o eixo X e escondido (a ordem das
/// leituras ja e evidente pela linha) e o eixo Y mostra porcentagem.
class _GraficoEvolucao extends StatelessWidget {
  final List<Map<String, dynamic>> pontos;
  final Color cor;

  const _GraficoEvolucao({required this.pontos, required this.cor});

  @override
  Widget build(BuildContext context) {
    // Mostra no maximo as 30 leituras mais recentes.
    final dados = pontos.length > 30
        ? pontos.sublist(pontos.length - 30)
        : pontos;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        minX: 0,
        maxX: (dados.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < dados.length; i++)
                FlSpot(i.toDouble(),
                    (dados[i]['risco_falha'] as num).toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 3,
            color: cor,
            dotData: FlDotData(
              show: dados.length <= 15,
              getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: cor,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData:
                BarAreaData(show: true, color: cor.withValues(alpha: 0.14)),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // Eixo X escondido: a sequencia das leituras ja e clara pela linha,
          // e as datas nao cabem na largura disponivel.
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 0.25,
              getTitlesWidget: (valor, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('${(valor * 100).toInt()}%',
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF8A8F98))),
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.25,
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${(s.y * 100).toStringAsFixed(1)}%',
                      TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5),
                    ))
                .toList(),
          ),
        ),
        // Faixas de decisao: 25% atencao, 60% critico
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: 0.25,
            color: CoresRisco.atencao.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
          HorizontalLine(
            y: 0.60,
            color: CoresRisco.critico.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ]),
      ),
    );
  }
}

/// Atributos SMART, com destaque para os que indicam problema.
class _SecaoSmart extends StatelessWidget {
  final Map<String, dynamic> smart;
  const _SecaoSmart({required this.smart});

  @override
  Widget build(BuildContext context) {
    final linhas = _rotulosSmart.entries
        .where((e) => smart.containsKey(e.key))
        .toList();
    if (linhas.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Atributos SMART',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: linhas.map((e) {
              final valor = smart[e.key];
              final numero = valor is num ? valor : 0;
              final alerta = _sintomas.contains(e.key) && numero > 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  SizedBox(
                    width: 165,
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF8A8F98))),
                  ),
                  Text('$valor',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              alerta ? FontWeight.w700 : FontWeight.normal,
                          color: alerta ? CoresRisco.critico : null)),
                  if (alerta) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.warning_amber_rounded,
                        size: 15, color: CoresRisco.critico),
                  ],
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    ]);
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
                            width: 165,
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
