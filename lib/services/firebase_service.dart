import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_document.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Documents
  Future<List<HealthDocument>> getUserDocuments(String userId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => HealthDocument.fromFirestore(doc))
        .toList();
  }

  Future<HealthDocument?> getDocument(String userId, String documentId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .doc(documentId)
        .get();

    if (doc.exists) {
      return HealthDocument.fromFirestore(doc);
    }
    return null;
  }

  Future<String> saveDocument(String userId, HealthDocument document) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .add(document.toFirestore());
    
    return docRef.id;
  }

  Future<void> updateDocument(String userId, String documentId, Map<String, dynamic> updates) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .doc(documentId)
        .update(updates);
  }

  Future<void> deleteDocument(String documentId, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .doc(documentId)
        .delete();
  }

  // Share Records
  Future<String> createShareRecord(ShareRecord shareRecord) async {
    final docRef = await _firestore
        .collection('shares')
        .add(shareRecord.toFirestore());
    return docRef.id;
  }

  Future<ShareRecord?> getShareRecord(String shareId) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('shareId', isEqualTo: shareId)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return ShareRecord.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  }

  Future<List<ShareRecord>> getUserActiveShares(String userId) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('ownerId', isEqualTo: userId)
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => ShareRecord.fromFirestore(doc))
        .toList();
  }

  Future<void> updateShareRecord(String shareId, Map<String, dynamic> updates) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('shareId', isEqualTo: shareId)
        .limit(1)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update(updates);
    }
  }

  Future<void> deactivateShare(String shareId) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('shareId', isEqualTo: shareId)
        .limit(1)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({'active': false});
    }
  }

  // Access Logs
  Future<void> logAccess(AccessLog accessLog) async {
    await _firestore.collection('access_logs').add(accessLog.toFirestore());
  }

  Future<List<AccessLog>> getDocumentAccessLogs(String documentId) async {
    final querySnapshot = await _firestore
        .collection('access_logs')
        .where('documentId', isEqualTo: documentId)
        .orderBy('accessedAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => AccessLog.fromFirestore(doc))
        .toList();
  }

  Future<List<AccessLog>> getUserAccessLogs(String userId) async {
    // Get all documents for the user first
    final documentsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('documents')
        .get();

    final documentIds = documentsSnapshot.docs.map((doc) => doc.id).toList();

    if (documentIds.isEmpty) return [];

    final querySnapshot = await _firestore
        .collection('access_logs')
        .where('documentId', whereIn: documentIds)
        .orderBy('accessedAt', descending: true)
        .limit(50)
        .get();

    return querySnapshot.docs
        .map((doc) => AccessLog.fromFirestore(doc))
        .toList();
  }

  // User PIN management
  Future<String?> getUserPermanentPin(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['permanentPin'] as String?;
    }
    return null;
  }

  Future<void> setUserPermanentPin(String userId, String pinHash) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set({'permanentPin': pinHash}, SetOptions(merge: true));
  }

  // Document Activity History
  Future<List<ShareRecord>> getDocumentShareHistory(String documentId, {int limit = 10}) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('documentId', isEqualTo: documentId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => ShareRecord.fromFirestore(doc))
        .toList();
  }

  Future<List<AccessLog>> getDocumentRecentActivity(String documentId, {int limit = 4}) async {
    final querySnapshot = await _firestore
        .collection('access_logs')
        .where('documentId', isEqualTo: documentId)
        .orderBy('accessedAt', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => AccessLog.fromFirestore(doc))
        .toList();
  }

  Future<List<ShareRecord>> getUserAllActiveShares(String userId) async {
    final querySnapshot = await _firestore
        .collection('shares')
        .where('ownerId', isEqualTo: userId)
        .where('active', isEqualTo: true)
        .where('expiresAt', isGreaterThan: DateTime.now())
        .orderBy('expiresAt', descending: false)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => ShareRecord.fromFirestore(doc))
        .toList();
  }
}