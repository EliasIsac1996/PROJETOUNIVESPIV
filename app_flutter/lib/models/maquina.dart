/// Modelo de dados de uma maquina do inventario.
/// Espelha o documento gravado em `maquinas/{serial_bios}` no Firestore
/// pelo script bancada/main.py.

enum FaixaRisco { ok, atencao, critico, semDados }

class Maquina {
  final String serialBios;
  final String fabricante;
  final String modeloPc;
  final String escola;
  final String sala;
  final String cpu;
  final int cpuCores;
  final int ramGb;
  final int ramPentes;
  final String modeloDisco;
  final String tipoDisco;
  final int capacidadeBytes;
  final double? riscoFalha;
  final String status; // ativo | quarentena | descartado
  final DateTime? atualizadoEm;
  final Map<String, dynamic> smart;

  Maquina({
    required this.serialBios,
    this.fabricante = '',
    this.modeloPc = '',
    this.escola = '',
    this.sala = '',
    this.cpu = '',
    this.cpuCores = 0,
    this.ramGb = 0,
    this.ramPentes = 0,
    this.modeloDisco = '',
    this.tipoDisco = '',
    this.capacidadeBytes = 0,
    this.riscoFalha,
    this.status = 'ativo',
    this.atualizadoEm,
    this.smart = const {},
  });

  factory Maquina.fromMap(String id, Map<String, dynamic> m) {
    final disco = (m['disco'] as Map<String, dynamic>?) ?? const {};
    return Maquina(
      serialBios: id,
      fabricante: (m['fabricante'] ?? '') as String,
      modeloPc: (m['modelo_pc'] ?? '') as String,
      escola: (m['escola'] ?? 'Nao atribuida') as String,
      sala: (m['sala'] ?? '-') as String,
      cpu: (m['cpu'] ?? '') as String,
      cpuCores: (m['cpu_cores'] ?? 0) as int,
      ramGb: (m['ram_gb'] ?? 0) as int,
      ramPentes: (m['ram_pentes'] ?? 0) as int,
      modeloDisco: (disco['model'] ?? '') as String,
      tipoDisco: (disco['tipo_disco'] ?? '') as String,
      capacidadeBytes: (disco['capacity_bytes'] ?? 0) as int,
      riscoFalha: (m['risco_falha'] as num?)?.toDouble(),
      status: (m['status'] ?? 'ativo') as String,
      atualizadoEm: DateTime.tryParse((m['atualizado_em'] ?? '') as String),
      smart: {
        for (final e in disco.entries)
          if (e.key.startsWith('smart_')) e.key: e.value,
      },
    );
  }

  FaixaRisco get faixa {
    if (riscoFalha == null) return FaixaRisco.semDados;
    if (riscoFalha! >= 0.60) return FaixaRisco.critico;
    if (riscoFalha! >= 0.25) return FaixaRisco.atencao;
    return FaixaRisco.ok;
  }

  String get riscoTexto =>
      riscoFalha == null ? '--' : '${(riscoFalha! * 100).toStringAsFixed(1)}%';

  String get capacidadeTexto => capacidadeBytes == 0
      ? '--'
      : '${(capacidadeBytes / 1e9).toStringAsFixed(0)} GB';

  bool get emQuarentena => status == 'quarentena';
}
