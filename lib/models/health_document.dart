import 'package:cloud_firestore/cloud_firestore.dart';

class HealthDocument {
  final String id;
  final String fileName;
  final String fileType; // 'image' or 'pdf'
  final String ipfsCid;
  final String documentType; // Prescription, Lab Report, etc.
  final String doctorName;
  final String hospitalName;
  final DateTime documentDate;
  final String notes;
  final String metadataHash;
  final DateTime createdAt;
  final int? blockchainRecordId;
  final String? transactionHash;

  HealthDocument({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.ipfsCid,
    required this.documentType,
    required this.doctorName,
    required this.hospitalName,
    required this.documentDate,
    required this.notes,
    required this.metadataHash,
    required this.createdAt,
    this.blockchainRecordId,
    this.transactionHash,
  });

  factory HealthDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthDocument(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      fileType: data['fileType'] ?? '',
      ipfsCid: data['ipfsCid'] ?? '',
      documentType: data['documentType'] ?? '',
      doctorName: data['doctorName'] ?? '',
      hospitalName: data['hospitalName'] ?? '',
      documentDate: (data['documentDate'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      metadataHash: data['metadataHash'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      blockchainRecordId: data['blockchainRecordId'],
      transactionHash: data['transactionHash'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'ipfsCid': ipfsCid,
      'documentType': documentType,
      'doctorName': doctorName,
      'hospitalName': hospitalName,
      'documentDate': Timestamp.fromDate(documentDate),
      'notes': notes,
      'metadataHash': metadataHash,
      'createdAt': Timestamp.fromDate(createdAt),
      'blockchainRecordId': blockchainRecordId,
      'transactionHash': transactionHash,
    };
  }

  // Metadata for hashing (excluding sensitive file info)
  Map<String, dynamic> getMetadataForHashing() {
    return {
      'documentType': documentType,
      'doctorName': doctorName,
      'hospitalName': hospitalName,
      'documentDate': documentDate.toIso8601String(),
      'fileName': fileName,
      'fileType': fileType,
    };
  }
}

class ShareRecord {
  final String id;
  final String shareId;
  final String documentId;
  final String ownerId;
  final String ipfsCid;
  final String? pinHash; // Hashed PIN
  final DateTime expiresAt;
  final bool active;
  final DateTime createdAt;
  final bool unlocked; // Patient must unlock for receiver
  final bool accessRequested; // Receiver has requested access

  ShareRecord({
    required this.id,
    required this.shareId,
    required this.documentId,
    required this.ownerId,
    required this.ipfsCid,
    this.pinHash,
    required this.expiresAt,
    required this.active,
    required this.createdAt,
    this.unlocked = false,
    this.accessRequested = false,
  });

  factory ShareRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShareRecord(
      id: doc.id,
      shareId: data['shareId'],
      documentId: data['documentId'],
      ownerId: data['ownerId'],
      ipfsCid: data['ipfsCid'],
      pinHash: data['pinHash'],
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      unlocked: data['unlocked'] ?? false,
      accessRequested: data['accessRequested'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shareId': shareId,
      'documentId': documentId,
      'ownerId': ownerId,
      'ipfsCid': ipfsCid,
      'pinHash': pinHash,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'unlocked': unlocked,
      'accessRequested': accessRequested,
    };
  }

  ShareRecord copyWith({
    String? id,
    String? shareId,
    String? documentId,
    String? ownerId,
    String? ipfsCid,
    String? pinHash,
    DateTime? expiresAt,
    bool? active,
    DateTime? createdAt,
    bool? unlocked,
    bool? accessRequested,
  }) {
    return ShareRecord(
      id: id ?? this.id,
      shareId: shareId ?? this.shareId,
      documentId: documentId ?? this.documentId,
      ownerId: ownerId ?? this.ownerId,
      ipfsCid: ipfsCid ?? this.ipfsCid,
      pinHash: pinHash ?? this.pinHash,
      expiresAt: expiresAt ?? this.expiresAt,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      unlocked: unlocked ?? this.unlocked,
      accessRequested: accessRequested ?? this.accessRequested,
    );
  }
}

class AccessLog {
  final String id;
  final String shareId;
  final String documentId;
  final String? viewerId;
  final String? viewerIp;
  final DateTime accessedAt;
  final String action; // 'viewed', 'downloaded'

  AccessLog({
    required this.id,
    required this.shareId,
    required this.documentId,
    this.viewerId,
    this.viewerIp,
    required this.accessedAt,
    required this.action,
  });

  factory AccessLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessLog(
      id: doc.id,
      shareId: data['shareId'],
      documentId: data['documentId'],
      viewerId: data['viewerId'],
      viewerIp: data['viewerIp'],
      accessedAt: (data['accessedAt'] as Timestamp).toDate(),
      action: data['action'] ?? 'viewed',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shareId': shareId,
      'documentId': documentId,
      'viewerId': viewerId,
      'viewerIp': viewerIp,
      'accessedAt': Timestamp.fromDate(accessedAt),
      'action': action,
    };
  }
}