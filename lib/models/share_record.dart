import 'package:cloud_firestore/cloud_firestore.dart';

class ShareRecord {
  final String id;
  final String shareId;
  final String documentId;
  final String ownerId;
  final String? receiverId;
  final String? receiverName;
  final String ipfsCid;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;
  final bool unlocked;
  final bool accessRequested;
  final String? pin;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final DateTime? accessedAt;
  final String status; // 'pending', 'accessed', 'rejected', 'expired'

  ShareRecord({
    required this.id,
    required this.shareId,
    required this.documentId,
    required this.ownerId,
    this.receiverId,
    this.receiverName,
    required this.ipfsCid,
    required this.createdAt,
    required this.expiresAt,
    required this.active,
    required this.unlocked,
    required this.accessRequested,
    this.pin,
    this.rejectedBy,
    this.rejectedAt,
    this.accessedAt,
    this.status = 'pending',
  });

  factory ShareRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShareRecord(
      id: doc.id,
      shareId: data['shareId'] ?? '',
      documentId: data['documentId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      receiverId: data['receiverId'],
      receiverName: data['receiverName'],
      ipfsCid: data['ipfsCid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      active: data['active'] ?? false,
      unlocked: data['unlocked'] ?? false,
      accessRequested: data['accessRequested'] ?? false,
      pin: data['pin'],
      rejectedBy: data['rejectedBy'],
      rejectedAt: data['rejectedAt'] != null 
          ? (data['rejectedAt'] as Timestamp).toDate() 
          : null,
      accessedAt: data['accessedAt'] != null 
          ? (data['accessedAt'] as Timestamp).toDate() 
          : null,
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shareId': shareId,
      'documentId': documentId,
      'ownerId': ownerId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'ipfsCid': ipfsCid,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'active': active,
      'unlocked': unlocked,
      'accessRequested': accessRequested,
      'pin': pin,
      'rejectedBy': rejectedBy,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'accessedAt': accessedAt != null ? Timestamp.fromDate(accessedAt!) : null,
      'status': status,
    };
  }

  ShareRecord copyWith({
    String? id,
    String? shareId,
    String? documentId,
    String? ownerId,
    String? receiverId,
    String? receiverName,
    String? ipfsCid,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? active,
    bool? unlocked,
    bool? accessRequested,
    String? pin,
    String? rejectedBy,
    DateTime? rejectedAt,
    DateTime? accessedAt,
    String? status,
  }) {
    return ShareRecord(
      id: id ?? this.id,
      shareId: shareId ?? this.shareId,
      documentId: documentId ?? this.documentId,
      ownerId: ownerId ?? this.ownerId,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      ipfsCid: ipfsCid ?? this.ipfsCid,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      active: active ?? this.active,
      unlocked: unlocked ?? this.unlocked,
      accessRequested: accessRequested ?? this.accessRequested,
      pin: pin ?? this.pin,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      accessedAt: accessedAt ?? this.accessedAt,
      status: status ?? this.status,
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
  final String action; // 'viewed', 'downloaded', 'rejected'

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
      shareId: data['shareId'] ?? '',
      documentId: data['documentId'] ?? '',
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
