import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maquina.dart';

/// Camada unica de acesso ao Firestore.
/// Nenhuma tela fala com o Firestore direto - facilita testar e trocar de backend.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Todas as maquinas, em tempo real.
  /// Se [cie] for fornecido, filtra apenas as maquinas daquela escola.
  Stream<List<Maquina>> maquinas({String? cie}) {
    Query query = _db.collection('maquinas');
    
    if (cie != null && cie.isNotEmpty) {
      query = query.where('cie_escola', isEqualTo: cie);
    }

    return query
        .orderBy('atualizado_em', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Maquina.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  /// Somente as maquinas em quarentena.
  Stream<List<Maquina>> quarentena({String? cie}) {
    Query query = _db.collection('maquinas').where('status', isEqualTo: 'quarentena');
    
    if (cie != null && cie.isNotEmpty) {
      query = query.where('cie_escola', isEqualTo: cie);
    }

    return query
        .snapshots()
        .map((s) => s.docs.map((d) => Maquina.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  /// Historico de leituras de uma maquina (para o grafico da ficha).
  Stream<List<Map<String, dynamic>>> historico(String serial) {
    return _db
        .collection('maquinas')
        .doc(serial)
        .collection('leituras')
        .orderBy('atualizado_em')
        .limitToLast(60)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<Map<String, dynamic>>> eventos({int limite = 50, String? cie}) {
    Query query = _db.collection('eventos');
    
    if (cie != null && cie.isNotEmpty) {
      // Nota: Para filtrar eventos por CIE, o script Python tambem precisaria
      // gravar o cie_escola no documento do evento.
      query = query.where('cie_escola', isEqualTo: cie);
    }

    return query
        .orderBy('criado_em', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList());
  }

  /// Tira a maquina da quarentena e atribui a uma escola/sala.
  Future<void> aprovarMaquina(String serial, String escola, String sala, {String? cie}) {
    return _db.collection('maquinas').doc(serial).update({
      'status': 'ativo',
      'escola': escola,
      'sala': sala,
      if (cie != null) 'cie_escola': cie,
    });
  }

  Future<void> marcarDescartada(String serial) {
    return _db.collection('maquinas').doc(serial).update({'status': 'descartado'});
  }

  /// Busca dados extras do usuario (como o CIE vinculado) no Firestore.
  Future<Map<String, dynamic>?> buscarDadosUsuario(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.data();
  }
}
