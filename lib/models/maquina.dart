enum FaixaRisco { ok, atencao, critico, semDados }

class Maquina {
  final String idDispositivo;
  final String tipoIdentificador;
  final String hostname;
  final String processador;
  final double memoriaRamGb;
  final String statusValidacao;
  final DateTime? dataRegistro;
  final double? riscoFalha;

  Maquina({
    required this.idDispositivo,
    this.tipoIdentificador = '',
    this.hostname = '',
    this.processador = '',
    this.memoriaRamGb = 0.0,
    this.statusValidacao = '',
    this.dataRegistro,
    this.riscoFalha,
  });

  factory Maquina.fromMap(String id, Map<String, dynamic> m) {
    return Maquina(
      idDispositivo: id,
      tipoIdentificador: m['tipo_identificador'] ?? '',
      hostname: m['hostname'] ?? 'Desconhecido',
      processador: m['processador'] ?? '',
      memoriaRamGb: (m['memoria_ram_gb'] as num?)?.toDouble() ?? 0.0,
      statusValidacao: m['status_validacao'] ?? '',
      dataRegistro: m['data_registro'] != null 
          ? DateTime.tryParse(m['data_registro']) 
          : null,
      riscoFalha: (m['risco_falha'] as num?)?.toDouble(),
    );
  }

  // Getters para compatibilidade com as telas existentes
  String get serialBios => idDispositivo;
  String get cpu => processador;
  double get ramGb => memoriaRamGb;
  String get modeloPc => hostname; // Mapeado para o hostname vindo do PS
  String get escola => "PM Ribeirão Preto";
  String get sala => "Laboratório";
  String get modeloDisco => "Unidade Local";
  String get tipoDisco => "Armazenamento";
  String get capacidadeTexto => "---";

  FaixaRisco get faixa {
    if (statusValidacao == 'QUARENTENA' || statusValidacao == 'NAO_RESPONDIDO') return FaixaRisco.critico;
    return FaixaRisco.ok;
  }

  String get riscoTexto => faixa == FaixaRisco.critico ? "ALTO" : "NORMAL";

  bool get emQuarentena => statusValidacao == 'QUARENTENA' || statusValidacao == 'NAO_RESPONDIDO';
}
