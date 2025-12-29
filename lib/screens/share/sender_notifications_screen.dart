import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../models/health_document.dart' hide ShareRecord;
import '../../models/share_record.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

class SenderNotificationsScreen extends StatefulWidget {
  const SenderNotificationsScreen({super.key});

  @override
  State<SenderNotificationsScreen> createState() => _SenderNotificationsScreenState();
}

class _SenderNotificationsScreenState extends State<SenderNotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Color primaryColor = const Color(0xFF10B981);
  
  List<ShareRecord> _sharedDocuments = [];
  Map<String, HealthDocument> _documentDetails = {};
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    
    if (currentUserId == null) return;

    // Listen to shares where current user is the owner
    _shareSubscription = FirebaseFirestore.instance
        .collection('shares')
        .where('ownerId', isEqualTo: currentUserId)
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _processShareUpdates(snapshot, currentUserId);
    });
  }

  void _processShareUpdates(QuerySnapshot snapshot, String currentUserId) async {
    List<ShareRecord> sharedDocs = [];
    Map<String, HealthDocument> docDetails = {};

    for (var doc in snapshot.docs) {
      if (doc.exists) {
        final shareRecord = ShareRecord.fromFirestore(doc);
        
        // Only show shares that have been unlocked (PIN entered)
        if (shareRecord.unlocked) {
          sharedDocs.add(shareRecord);
          
          // Load document details if not already loaded
          if (!_documentDetails.containsKey(shareRecord.documentId)) {
            try {
              final document = await _firebaseService.getDocumentById(
                shareRecord.documentId
              );
              if (document != null) {
                docDetails[shareRecord.documentId] = document;
              }
            } catch (e) {
              debugPrint('Failed to load document ${shareRecord.documentId}: $e');
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _sharedDocuments = sharedDocs;
        _documentDetails.addAll(docDetails);
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeAccess(ShareRecord shareRecord) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text('Are you sure you want to revoke access to "${_documentDetails[shareRecord.documentId]?.fileName ?? 'this document'}"? The receiver will no longer be able to view it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update the share record to revoke access
        await _firebaseService.updateShareRecord(shareRecord.id, {
          'active': false,
          'revokedAt': Timestamp.now(),
          'revokedBy': 'owner',
          'status': 'revoked',
        });

        // Log the revocation
        debugPrint('Share record ${shareRecord.id} revoked successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Access revoked successfully'),
              backgroundColor: primaryColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to revoke access: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Documents'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sharedDocuments.isEmpty
              ? _buildEmptyState()
              : _buildDocumentsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.share_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Shared Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Documents you share will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sharedDocuments.length,
      itemBuilder: (context, index) {
        final shareRecord = _sharedDocuments[index];
        final document = _documentDetails[shareRecord.documentId];
        return _buildShareCard(shareRecord, document);
      },
    );
  }

  Widget _buildShareCard(ShareRecord shareRecord, HealthDocument? document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document?.fileName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        document?.documentType ?? 'Document',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(shareRecord.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(shareRecord.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Share details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Shared with', shareRecord.receiverName ?? 'Unknown'),
                  _buildDetailRow('Shared on', _formatDateTime(shareRecord.createdAt)),
                  _buildDetailRow('Expires', _formatDateTime(shareRecord.expiresAt)),
                  if (shareRecord.accessedAt != null)
                    _buildDetailRow('Last accessed', _formatDateTime(shareRecord.accessedAt!)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Access notification
            if (shareRecord.status == 'accessed')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document has been accessed by ${shareRecord.receiverName ?? 'the receiver'}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _revokeAccess(shareRecord),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Revoke Access'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.black54)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accessed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      case 'revoked':
        return Colors.red[800]!;
      case 'pending':
      default:
        return primaryColor;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accessed':
        return 'Accessed';
      case 'rejected':
        return 'Rejected';
      case 'expired':
        return 'Expired';
      case 'revoked':
        return 'Revoked';
      case 'pending':
      default:
        return 'Active';
    }
  }
}