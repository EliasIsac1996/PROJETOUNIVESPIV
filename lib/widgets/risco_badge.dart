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
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(maquina.riscoTexto,
            style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

/// Cartao de metrica do dashboard.
class CartaoMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const CartaoMetrica({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor, size: 26),
          const SizedBox(height: 12),
          Text(valor,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w700, color: cor)),
          const SizedBox(height: 2),
          Text(titulo,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A8F98))),
        ],
      ),
    );
  }
}
