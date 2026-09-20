import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maquina.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca todos os equipamentos. 
  /// Removi o orderBy temporariamente para garantir que os dados apareçam mesmo sem índices.
  Stream<List<Maquina>> maquinas() {
    try {
      return _db
          .collection('equipamentos')
          .snapshots()
          .map((s) {
            if (s.docs.isEmpty) {
              debugPrint("AVISO: A coleção 'equipamentos' está vazia no Firestore.");
            }
            return s.docs.map((d) {
              return Maquina.fromMap(d.id, d.data());
            }).toList();
          });
    } catch (e) {
      debugPrint("ERRO ao acessar Firestore: $e");
      return Stream.value([]);
    }
  }

  Stream<List<Maquina>> quarentena() {
    return _db
        .collection('equipamentos')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Maquina.fromMap(d.id, d.data()))
            .where((m) => m.emQuarentena)
            .toList());
  }

  Future<void> aprovarMaquina(String id, String escola, String sala) {
    return _db.collection('equipamentos').doc(id).update({
      'status_validacao': 'VALIDADO_MANUAL',
      'escola': escola,
      'sala': sala,
    });
  }

  Future<void> marcarDescartada(String id) {
    return _db.collection('equipamentos').doc(id).update({
      'status_validacao': 'DESCARTADO'
    });
  }
}
