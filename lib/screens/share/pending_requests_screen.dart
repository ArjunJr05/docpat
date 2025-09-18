import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../../models/health_document.dart' hide ShareRecord;
import '../../models/share_record.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/ipfs_service.dart';
import '../document/image_viewer_screen.dart';
import '../document/pdf_viewer_screen.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<ShareRecord> _receivedDocuments = [];
  Map<String, HealthDocument> _documentDetails = {};
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _shareSubscription;

  final Color primaryColor = const Color(0xFF10B981); // Emerald green

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Received Documents'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : _receivedDocuments.isEmpty
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
            Icons.inbox_outlined,
            size: 64,
            color: primaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Received Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Documents shared with you will appear here.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return RefreshIndicator(
      onRefresh: _refreshDocuments,
      backgroundColor: Colors.white,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedDocuments.length,
        itemBuilder: (context, index) {
          final shareRecord = _receivedDocuments[index];
          final document = _documentDetails[shareRecord.documentId];
          return _buildDocumentCard(shareRecord, document);
        },
      ),
    );
  }

  Widget _buildDocumentCard(ShareRecord shareRecord, HealthDocument? document) {
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

            // Document details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  if (document != null) ...[
                    _buildDetailRow('Doctor', document.doctorName),
                    _buildDetailRow('Hospital', document.hospitalName),
                    _buildDetailRow('Date', _formatDate(document.documentDate)),
                  ],
                  _buildDetailRow('Shared', _formatDateTime(shareRecord.createdAt)),
                  _buildDetailRow('Expires', _formatDateTime(shareRecord.expiresAt)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: document != null ? () => _viewDocument(shareRecord, document) : null,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectDocument(shareRecord),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 13, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _setupRealtimeListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId!;
    
    // Listen to shares where current user is NOT the owner (received documents)
    // Split the query to avoid composite index requirement
    _shareSubscription = FirebaseFirestore.instance
        .collection('shares')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _processShareUpdates(snapshot, userId);
    });
  }

  void _processShareUpdates(QuerySnapshot snapshot, String currentUserId) async {
    List<ShareRecord> receivedDocs = [];
    Map<String, HealthDocument> docDetails = {};

    for (var doc in snapshot.docs) {
      if (doc.exists) {
        final shareRecord = ShareRecord.fromFirestore(doc);
        
        // Filter by expiration date and ownership in code to avoid composite index
        final now = DateTime.now();
        final isNotExpired = shareRecord.expiresAt.isAfter(now);
        final isNotOwner = shareRecord.ownerId != currentUserId;
        final isUnlocked = shareRecord.unlocked; // Only show unlocked documents
        
        if (isNotExpired && isNotOwner && isUnlocked) {
          receivedDocs.add(shareRecord);
          
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
        _receivedDocuments = receivedDocs;
        _documentDetails.addAll(docDetails);
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDocuments() async {
    setState(() {
      _isLoading = true;
      _receivedDocuments.clear();
      _documentDetails.clear();
    });
    // The real-time listener will automatically refresh the data
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewDocument(ShareRecord shareRecord, HealthDocument document) {
    // Navigate to document viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          shareRecord: shareRecord,
          document: document,
        ),
      ),
    );
  }

  Future<void> _rejectDocument(ShareRecord shareRecord) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Document'),
        content: const Text('Are you sure you want to reject this shared document? You will no longer be able to access it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mark the share as inactive (rejected by receiver)
        await _firebaseService.updateShareRecord(shareRecord.id, {
          'active': false,
          'rejectedAt': Timestamp.now(),
          'rejectedBy': 'receiver',
          'status': 'rejected',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Document rejected successfully'),
              backgroundColor: primaryColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accessed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.orange;
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
      case 'pending':
      default:
        return 'Active';
    }
  }
}

// Document Viewer Screen for viewing shared documents
class DocumentViewerScreen extends StatefulWidget {
  final ShareRecord shareRecord;
  final HealthDocument document;

  const DocumentViewerScreen({
    super.key,
    required this.shareRecord,
    required this.document,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final IpfsService _ipfsService = IpfsService();
  StreamSubscription<DocumentSnapshot>? _shareSubscription;
  bool _isRevoked = false;

  final Color primaryColor = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _setupRealTimeListener();
    _logAccess();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeListener() {
    // Listen for real-time changes to the share record
    _shareSubscription = FirebaseFirestore.instance
        .collection('shares')
        .doc(widget.shareRecord.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final isActive = data['active'] ?? false;
        
        if (!isActive && mounted) {
          setState(() {
            _isRevoked = true;
          });
          _showRevokedDialog();
        }
      } else if (mounted) {
        // Document was deleted
        setState(() {
          _isRevoked = true;
        });
        _showRevokedDialog();
      }
    });
  }

  void _showRevokedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Access Revoked'),
        content: const Text('The document owner has revoked your access to this document.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close viewer
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _logAccess() async {
    try {
      await _firebaseService.logDocumentAccess(
        widget.shareRecord.id,
        widget.document.id,
        'viewed',
      );
      
      // Update share record status to 'accessed' and record access time
      await _firebaseService.updateShareRecord(widget.shareRecord.id, {
        'status': 'accessed',
        'accessedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Failed to log access: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevoked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Document Revoked'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Access Revoked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This document is no longer available.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.fileName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('File Name', widget.document.fileName),
                    _buildInfoRow('Type', widget.document.documentType),
                    _buildInfoRow('Doctor', widget.document.doctorName),
                    _buildInfoRow('Hospital', widget.document.hospitalName),
                    _buildInfoRow('Date', _formatDate(widget.document.documentDate)),
                    if (widget.document.notes.isNotEmpty)
                      _buildInfoRow('Notes', widget.document.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Document preview and view button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilePreview(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openDocumentViewer(),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Full Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(': '),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFilePreview() {
    final fileUrl = _ipfsService.getFileUrl(widget.document.ipfsCid);
    
    if (widget.document.fileType == 'image') {
      return GestureDetector(
        onTap: () => _openImageViewer(),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: fileUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              errorWidget: (context, url, error) {
                debugPrint('Image loading error: $error');
                debugPrint('Image URL: $url');
                return Container(
                  color: Colors.grey.shade100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'URL: ${url.length > 50 ? '${url.substring(0, 50)}...' : url}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openPdfViewer(),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                size: 48,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                'PDF Document',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tap to View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openImageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          imageUrl: _ipfsService.getFileUrl(widget.document.ipfsCid),
          title: widget.document.fileName,
        ),
      ),
    );
  }

  void _openPdfViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: _ipfsService.getFileUrl(widget.document.ipfsCid),
          title: widget.document.fileName,
        ),
      ),
    );
  }

  void _openDocumentViewer() {
    if (widget.document.fileType == 'image') {
      _openImageViewer();
    } else {
      _openPdfViewer();
    }
  }
}
