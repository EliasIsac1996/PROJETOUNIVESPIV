import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maquina.dart';

/// Camada unica de acesso ao Firestore.
/// Nenhuma tela fala com o Firestore direto - facilita testar e trocar de backend.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Todas as maquinas, em tempo real.
  Stream<List<Maquina>> maquinas() {
    return _db
        .collection('maquinas')
        .orderBy('atualizado_em', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Maquina.fromMap(d.id, d.data())).toList());
  }

  /// Somente as maquinas em quarentena.
  Stream<List<Maquina>> quarentena() {
    return _db
        .collection('maquinas')
        .where('status', isEqualTo: 'quarentena')
        .snapshots()
        .map((s) => s.docs.map((d) => Maquina.fromMap(d.id, d.data())).toList());
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

  Stream<List<Map<String, dynamic>>> eventos({int limite = 50}) {
    return _db
        .collection('eventos')
        .orderBy('criado_em', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Tira a maquina da quarentena e atribui a uma escola/sala.
  Future<void> aprovarMaquina(String serial, String escola, String sala) {
    return _db.collection('maquinas').doc(serial).update({
      'status': 'ativo',
      'escola': escola,
      'sala': sala,
    });
  }

  Future<void> marcarDescartada(String serial) {
    return _db.collection('maquinas').doc(serial).update({'status': 'descartado'});
  }
}
