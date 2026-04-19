import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  Stream<List<TranslationHistory>> getHistoryStream() {
    if (_currentUser == null) {
      return Stream.value([]);
    }
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TranslationHistory.fromMap(data);
      }).toList();
    });
  }

  Future<void> addHistory(TranslationHistory history) async {
    if (_currentUser == null) return;
    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('history')
        .doc(history.id)
        .set(history.toMap());
  }

  Future<void> toggleFavorite(String historyId, bool currentStatus) async {
    if (_currentUser == null) return;
    await _firestore
        .collection('users')
                .doc(_currentUser!.uid)
        .collection('history')
        .doc(historyId)
        .update({'isFavorite': !currentStatus});
  }

  Future<void> deleteHistory(String historyId) async {
    if (_currentUser == null) return;
    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('history')
        .doc(historyId)
        .delete();
  }
}
