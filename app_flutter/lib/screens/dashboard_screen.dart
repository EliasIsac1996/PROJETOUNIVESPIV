import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/maquina.dart';
import '../services/firestore_service.dart';
import '../widgets/risco_badge.dart';
import 'ficha_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = FirestoreService();

    return StreamBuilder<List<Maquina>>(
      stream: servico.maquinas(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Erro ao carregar: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final maquinas = snap.data!;
        if (maquinas.isEmpty) {
          return const _Vazio();
        }

        final criticas =
            maquinas.where((m) => m.faixa == FaixaRisco.critico).toList();
        final atencao = maquinas.where((m) => m.faixa == FaixaRisco.atencao).length;
        final quarentena = maquinas.where((m) => m.emQuarentena).length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Visao geral do parque',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount:
                  MediaQuery.of(context).size.width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: [
                CartaoMetrica(
                    titulo: 'Maquinas', valor: '${maquinas.length}',
                    icone: Icons.desktop_windows_outlined,
                    cor: const Color(0xFF4A7DD6)),
                CartaoMetrica(
                    titulo: 'Risco critico', valor: '${criticas.length}',
                    icone: Icons.error_outline, cor: CoresRisco.critico),
                CartaoMetrica(
                    titulo: 'Em atencao', valor: '$atencao',
                    icone: Icons.warning_amber_outlined, cor: CoresRisco.atencao),
                CartaoMetrica(
                    titulo: 'Quarentena', valor: '$quarentena',
                    icone: Icons.help_outline, cor: const Color(0xFF9B59B6)),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Distribuicao de risco',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            SizedBox(height: 210, child: _GraficoRisco(maquinas: maquinas)),
            const SizedBox(height: 28),
            const Text('Trocar com prioridade',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Discos com maior probabilidade de falha em 30 dias',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF8A8F98))),
            const SizedBox(height: 10),
            if (criticas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Nenhuma maquina em risco critico.'),
              )
            else
              ...(criticas
                    ..sort((a, b) =>
                        (b.riscoFalha ?? 0).compareTo(a.riscoFalha ?? 0)))
                  .take(8)
                  .map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.storage_outlined),
                          title: Text(m.serialBios),
                          subtitle: Text('${m.escola} - ${m.sala}\n'
                              '${m.modeloDisco} ${m.capacidadeTexto}'),
                          isThreeLine: true,
                          trailing: RiscoBadge(maquina: m),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FichaScreen(maquina: m)),
                          ),
                        ),
                      )),
          ],
        );
      },
    );
  }
}

class _GraficoRisco extends StatelessWidget {
  final List<Maquina> maquinas;
  const _GraficoRisco({required this.maquinas});

  @override
  Widget build(BuildContext context) {
    final contagem = <FaixaRisco, int>{
      FaixaRisco.ok: 0,
      FaixaRisco.atencao: 0,
      FaixaRisco.critico: 0,
      FaixaRisco.semDados: 0,
    };
    for (final m in maquinas) {
      contagem[m.faixa] = contagem[m.faixa]! + 1;
    }
    final faixas = contagem.keys.toList();
    final maxY = (contagem.values.reduce((a, b) => a > b ? a : b) * 1.25) + 1;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < faixas.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: contagem[faixas[i]]!.toDouble(),
                color: CoresRisco.de(faixas[i]),
                width: 34,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )
            ]),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(CoresRisco.rotulo(faixas[v.toInt()]),
                    style: const TextStyle(fontSize: 10.5)),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 54, color: Color(0xFF8A8F98)),
          SizedBox(height: 14),
          Text('Nenhuma maquina no inventario ainda.',
              style: TextStyle(fontSize: 16)),
          SizedBox(height: 6),
          Text('Rode a bancada: python bancada/main.py',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF8A8F98))),
        ]),
      ),
    );
  }
}
