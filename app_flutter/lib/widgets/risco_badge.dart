import 'package:flutter/material.dart';
import '../models/maquina.dart';

/// Cores unicas de risco, usadas em todas as telas.
class CoresRisco {
  static const ok = Color(0xFF2E9E5B);
  static const atencao = Color(0xFFE0A008);
  static const critico = Color(0xFFD64545);
  static const semDados = Color(0xFF8A8F98);

  static Color de(FaixaRisco f) => switch (f) {
        FaixaRisco.ok => ok,
        FaixaRisco.atencao => atencao,
        FaixaRisco.critico => critico,
        FaixaRisco.semDados => semDados,
      };

  static String rotulo(FaixaRisco f) => switch (f) {
        FaixaRisco.ok => 'OK',
        FaixaRisco.atencao => 'ATENCAO',
        FaixaRisco.critico => 'CRITICO',
        FaixaRisco.semDados => 'SEM DADOS',
      };
}

class RiscoBadge extends StatelessWidget {
  final Maquina maquina;
  const RiscoBadge({super.key, required this.maquina});

  @override
  Widget build(BuildContext context) {
    final cor = CoresRisco.de(maquina.faixa);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(maquina.riscoTexto,
            style:
                TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

/// Cartao de metrica do painel.
///
/// Layout horizontal e de altura fixa. A versao anterior usava
/// GridView.count com childAspectRatio, que calcula a altura a partir da
/// largura disponivel - em tela larga o cartao esticava para mais de 300px
/// de altura so para exibir um numero. Aqui a altura e definida pelo
/// proprio conteudo, entao ela nao muda com o tamanho da janela.
class CartaoMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;
  final VoidCallback? aoTocar;

  const CartaoMetrica({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final conteudo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icone, color: cor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(valor,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: cor)),
               Text(titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, height: 1.2, color: Color(0xFF8A8F98))),
            ],
          ),
        ),
      ]),
    );

    if (aoTocar == null) return conteudo;
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(14),
      child: conteudo,
    );
  }
}

/// Barra de proporcao horizontal com legenda.
///
/// Substitui o grafico de barras verticais do painel. Com 280 maquinas em
/// "OK" e 3 em "ATENCAO", um eixo linear comum tornava as barras menores
/// invisiveis - nao dava para distinguir 16 de 3. Aqui a proporcao e
/// mostrada na barra e o valor exato aparece na legenda, entao nenhuma
/// categoria some.
class BarraProporcao extends StatelessWidget {
  final List<({String rotulo, int valor, Color cor})> itens;
  const BarraProporcao({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    final total = itens.fold<int>(0, (s, i) => s + i.valor);
    if (total == 0) return const SizedBox.shrink();

    final visiveis = itens.where((i) => i.valor > 0).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              for (final i in visiveis)
                Expanded(
                  flex: i.valor,
                  child: Tooltip(
                    message: '${i.rotulo}: ${i.valor}',
                    child: Container(color: i.cor),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 22,
        runSpacing: 10,
        children: [
          for (final i in itens)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                      color: i.cor, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 7),
              Text(i.rotulo,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF8A8F98))),
              const SizedBox(width: 6),
              Text('${i.valor}',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: i.cor)),
              const SizedBox(width: 3),
              Text('(${(i.valor / total * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF8A8F98))),
            ]),
        ],
      ),
    ]);
  }
}
