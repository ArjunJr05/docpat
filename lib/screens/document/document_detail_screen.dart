import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/health_document.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/ipfs_service.dart';
import '../../services/blockchain_service.dart';
import '../share/create_share_screen.dart';
import 'image_viewer_screen.dart';
import 'pdf_viewer_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final HealthDocument document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final IpfsService _ipfsService = IpfsService();
  
  List<AccessLog> _accessLogs = [];
  List<ShareRecord> _activeShares = [];
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDocumentData();
  }

  Future<void> _loadDocumentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadAccessLogs(),
        _loadActiveShares(),
      ]);
    } catch (e) {
      debugPrint('Error loading document data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.document.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Color(0xFF10B981),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share,color:Color(0xFF10B981),),
                    SizedBox(width: 8),
                    Text('Share Document'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download,color: Color(0xFF10B981),),
                    SizedBox(width: 8),
                    Text('Download File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Document', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareDocument();
                  break;
                case 'download':
                  _downloadDocument();
                  break;
                case 'delete':
                  _confirmDeleteDocument();
                  break;
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.info_outline)),
            Tab(text: 'Shares', icon: Icon(Icons.share)),
            Tab(text: 'Activity', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildSharesTab(),
          _buildActivityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _shareDocument,
        backgroundColor: Color(0xFF10B981),
        foregroundColor: Colors.white,
        child: const Icon(Icons.share),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File preview card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: 250,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.preview, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      const Text(
                        'Document Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildFilePreview(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Document information card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      const Text(
                        'Document Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection([
                    _buildInfoRow('File Name', widget.document.fileName),
                    _buildInfoRow('Document Type', widget.document.documentType),
                    _buildInfoRow('Doctor', widget.document.doctorName),
                    _buildInfoRow('Hospital/Clinic', widget.document.hospitalName),
                    _buildInfoRow('Document Date', _formatDate(widget.document.documentDate)),
                    _buildInfoRow('Created', _formatDateTime(widget.document.createdAt)),
                    if (widget.document.notes.isNotEmpty)
                      _buildInfoRow('Notes', widget.document.notes, isExpandable: true),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Technical details card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.document.transactionHash != null ? Icons.verified : Icons.warning,
                        color: widget.document.transactionHash != null ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Blockchain Verification',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.document.transactionHash != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Document verified on blockchain',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection([
                      _buildInfoRow('Record ID', widget.document.blockchainRecordId.toString()),
                      _buildInfoRow('Transaction Hash', widget.document.transactionHash!, 
                          copyable: true, monospace: true),
                      _buildInfoRow('Metadata Hash', widget.document.metadataHash, 
                          copyable: true, monospace: true),
                    ]),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pending, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Blockchain verification pending or failed',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _retryBlockchainVerification,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry Verification'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection([
                      _buildInfoRow('IPFS CID', widget.document.ipfsCid, copyable: true, monospace: true),
                      _buildInfoRow('File Type', widget.document.fileType.toUpperCase()),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildSharesTab() {
    return RefreshIndicator(
      onRefresh: _loadActiveShares,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Create share button
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.share, size: 48, color: Color(0xFF10B981)),
                    const SizedBox(height: 16),
                    const Text(
                      'Share This Document',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create secure, time-limited sharing links with optional PIN protection',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareDocument,
                        icon: const Icon(Icons.add_link),
                        label: const Text('Create New Share Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active shares list
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Active Share Links',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_activeShares.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_activeShares.length}',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_activeShares.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.link_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No active shares',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create a share link to allow others to view this document',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activeShares.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildShareCard(_activeShares[index], index);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    return RefreshIndicator(
      onRefresh: _loadAccessLogs,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        const Text(
                          'Access History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_accessLogs.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No access history',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Access logs will appear here when others view your shared document',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _accessLogs.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.grey[300]),
                        itemBuilder: (context, index) {
                          return _buildAccessLogItem(_accessLogs[index]);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    if (widget.document.fileType == 'image') {
      return GestureDetector(
        onTap: () => _openImageViewer(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: _ipfsService.getFileUrl(widget.document.ipfsCid),
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 8),
                  const Text('Failed to load image'),
                  TextButton(
                    onPressed: () => setState(() {}), // Retry
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openPdfViewer(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[600]),
              const SizedBox(height: 12),
              const Text(
                'PDF Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to view the full document',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'View PDF',
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

  // Open full-screen image viewer
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

  // Open PDF viewer
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

  Widget _buildInfoSection(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false, bool monospace = false, bool isExpandable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyable ? () => _copyToClipboard(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  color: copyable ? Color(0xFF10B981) : Colors.black87,
                  decoration: copyable ? TextDecoration.underline : null,
                  fontFamily: monospace ? 'monospace' : null,
                  fontSize: monospace ? 11 : 14,
                ),
                maxLines: isExpandable ? null : 2,
                overflow: isExpandable ? null : TextOverflow.ellipsis,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
              onPressed: () => _copyToClipboard(value),
              tooltip: 'Copy to clipboard',
            ),
        ],
      ),
    );
  }

  Widget _buildShareCard(ShareRecord share, int index) {
    final isExpired = share.expiresAt.isBefore(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpired ? Colors.red[300]! : Colors.green[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpired ? Icons.link_off : Icons.link,
                color: isExpired ? Colors.red[700] : Colors.green[700],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Share Link ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isExpired ? Colors.red[800] : Colors.green[800],
                ),
              ),
              const Spacer(),
              PopupMenuButton(
                icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code),
                        SizedBox(width: 8),
                        Text('Show QR Code'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'revoke',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Revoke Access', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'qr':
                      _showQRCode(share);
                      break;
                    case 'revoke':
                      _revokeShare(share);
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${_formatDateTime(share.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            'Expires: ${_formatDateTime(share.expiresAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (share.pinHash != null)
            Text(
              'PIN Protected',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          if (isExpired)
            Text(
              'EXPIRED',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccessLogItem(AccessLog log) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: log.action == 'downloaded' ? Colors.green[100] : Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          log.action == 'downloaded' ? Icons.download : Icons.visibility,
          color: log.action == 'downloaded' ? Colors.green[700] : Color(0xFF10B981),
          size: 20,
        ),
      ),
      title: Text(
        log.action == 'downloaded' ? 'Document Downloaded' : 'Document Viewed',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.viewerName != null && log.viewerName!.isNotEmpty)
            Text(
              'Viewed by: ${log.viewerName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          Text(
            'Time: ${_formatDateTime(log.accessedAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (log.viewerIp != null)
            Text(
              'IP: ${log.viewerIp}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
    );
  }

  Future<void> _loadAccessLogs() async {
    try {
      final logs = await _firebaseService.getDocumentAccessLogs(widget.document.id);
      setState(() {
        _accessLogs = logs;
      });
    } catch (e) {
      debugPrint('Error loading access logs: $e');
    }
  }

  Future<void> _loadActiveShares() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final shares = await _firebaseService.getUserActiveShares(authProvider.userId!);
      setState(() {
        _activeShares = shares.where((share) => share.documentId == widget.document.id).toList();
      });
    } catch (e) {
      debugPrint('Error loading shares: $e');
    }
  }

  void _shareDocument() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateShareScreen(document: widget.document),
      ),
    ).then((_) {
      _loadActiveShares(); // Refresh shares after creating new one
    });
  }

  void _downloadDocument() {
    final downloadUrl = _ipfsService.getFileUrl(widget.document.ipfsCid);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You can access your document at:'),
            const SizedBox(height: 8),
            SelectableText(
              downloadUrl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(downloadUrl);
              Navigator.of(context).pop();
            },
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDocument() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteDocument();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _firebaseService.deleteDocument(widget.document.id, authProvider.userId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    // In a real app, use Clipboard.setData from 'package:flutter/services.dart'
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${text.length > 30 ? '${text.substring(0, 30)}...' : text}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQRCode(ShareRecord share) {
    final shareUrl = '${dotenv.env['SHARE_BASE_URL'] ?? 'https://example.com/share'}/${share.shareId}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: shareUrl,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              shareUrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            if (share.pinHash != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'This share requires a PIN to access',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(shareUrl);
              Navigator.of(context).pop();
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeShare(ShareRecord share) async {
    try {
      await _firebaseService.deactivateShare(share.shareId);
      await _loadActiveShares();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share access revoked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _retryBlockchainVerification() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Retrying blockchain verification...'),
            ],
          ),
        ),
      );

      // Import blockchain service
      final BlockchainService blockchainService = BlockchainService();
      await blockchainService.initialize();

      // Generate a new record ID (you might want to use a different strategy)
      final recordId = DateTime.now().millisecondsSinceEpoch;
      
      // Retry storing the document on blockchain
      final transactionHash = await blockchainService.storeDocument(
        recordId,
        widget.document.ipfsCid,
        widget.document.metadataHash,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (transactionHash != null) {
        // Update the document with blockchain info
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await _firebaseService.updateDocument(
          authProvider.userId!,
          widget.document.id,
          {
            'blockchainRecordId': recordId,
            'transactionHash': transactionHash,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blockchain verification successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the page to show updated status
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blockchain verification failed. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}