import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/health_document.dart';
import '../../services/firebase_service.dart';
import '../../services/ipfs_service.dart';

class ShareViewScreen extends StatefulWidget {
  final String? shareId;

  const ShareViewScreen({super.key, this.shareId});

  @override
  State<ShareViewScreen> createState() => _ShareViewScreenState();
}

class _ShareViewScreenState extends State<ShareViewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final IpfsService _ipfsService = IpfsService();
  final _pinController = TextEditingController();

  ShareRecord? _shareRecord;
  HealthDocument? _document;
  bool _isLoading = false;
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    if (widget.shareId != null) {
      _loadShareRecord(widget.shareId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Shared Document'),
        actions: [
          if (!_isScanning)
            IconButton(
              onPressed: _startQRScan,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan QR Code',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return _buildQRScanner();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_shareRecord == null) {
      return _buildInitialState();
    }

    if (!_shareRecord!.unlocked) {
      return _buildWaitingForApproval();
    }

    if (_document != null) {
      return _buildDocumentView();
    }

    return _buildLoadingDocument();
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Scan QR Code or Enter Share Link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Or paste share link here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              onSubmitted: _handleShareLink,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startQRScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (BarcodeCapture barcodeCapture) {
                  final List<Barcode> barcodes = barcodeCapture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _handleShareLink(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
              // Overlay with scanning area
              Container(
                decoration: ShapeDecoration(
                  shape: QrScannerOverlayShape(
                    borderColor: Colors.blue,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 250,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Position the QR code within the frame',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _scannerController?.toggleTorch(),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Flash'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isScanning = false;
                        });
                        _scannerController?.dispose();
                        _scannerController = null;
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Stream<ShareRecord?> _watchShareRecord() {
    // Real-time monitoring for document unlock status
    return Stream.periodic(const Duration(milliseconds: 500), (count) async {
      try {
        return await _firebaseService.getShareRecord(_shareRecord!.shareId);
      } catch (e) {
        return _shareRecord;
      }
    }).asyncMap((future) => future);
  }

  Widget _buildWaitingForApproval() {
    return StreamBuilder<ShareRecord?>(
      stream: _watchShareRecord(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final shareRecord = snapshot.data!;
          
          // If document is now unlocked, immediately load it
          if (shareRecord.unlocked && !_shareRecord!.unlocked) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _shareRecord = shareRecord;
              });
              _loadDocument();
            });
          }
        }
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Waiting for Patient Approval',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The document owner needs to approve your access request. Please wait...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(height: 8),
                          const Text(
                            'Access Request Sent',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The patient will be notified to unlock this document for you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _loadShareRecord(_shareRecord!.shareId),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check Status'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Auto-checking...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildDocumentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a shared medical document. Handle with confidentiality.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Document preview
          Card(
            child: Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(16),
              child: _document!.fileType == 'image'
                  ? CachedNetworkImage(
                      imageUrl: _ipfsService.getFileUrl(_document!.ipfsCid),
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 48, color: Colors.red),
                            Text('Failed to load image'),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                          SizedBox(height: 8),
                          Text('PDF Document'),
                          SizedBox(height: 4),
                          Text('Tap download to view full document'),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Document information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Document Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('File Name', _document!.fileName),
                  _buildInfoRow('Type', _document!.documentType),
                  _buildInfoRow('Doctor', _document!.doctorName),
                  _buildInfoRow('Hospital', _document!.hospitalName),
                  _buildInfoRow('Date', _formatDate(_document!.documentDate)),
                  if (_document!.notes.isNotEmpty)
                    _buildInfoRow('Notes', _document!.notes),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadDocument,
                      icon: const Icon(Icons.download),
                      label: const Text('Download Document'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share expires: ${_formatDateTime(_shareRecord!.expiresAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDocument() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading document...'),
        ],
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
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _handleShareLink(String link) {
    setState(() {
      _isScanning = false;
    });
    
    _scannerController?.dispose();
    _scannerController = null;

    // Extract shareId from URL
    final uri = Uri.tryParse(link);
    String? shareId;

    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[uri.pathSegments.length - 2] == 'share') {
      shareId = uri.pathSegments.last;
    } else if (link.contains('/share/')) {
      shareId = link.split('/share/').last;
    } else {
      shareId = link; // Assume direct share ID
    }

    if (shareId != null) {
      _loadShareRecord(shareId);
    } else {
      _showError('Invalid share link');
    }
  }

  Future<void> _loadShareRecord(String shareId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final shareRecord = await _firebaseService.getShareRecord(shareId);
      
      if (shareRecord == null) {
        _showError('Share not found or expired');
        return;
      }

      if (!shareRecord.active) {
        _showError('This share has been revoked');
        return;
      }

      if (shareRecord.expiresAt.isBefore(DateTime.now())) {
        _showError('This share has expired');
        return;
      }

      setState(() {
        _shareRecord = shareRecord;
      });

      // Check if document is unlocked
      if (!shareRecord.unlocked) {
        // Request access if not already requested
        if (!shareRecord.accessRequested) {
          await _requestAccess();
        }
        return;
      }

      // Once unlocked, load document immediately (no PIN required from receiver)
      await _loadDocument();

    } catch (e) {
      _showError('Failed to load share: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestAccess() async {
    try {
      // Update the share record to mark access as requested
      await _firebaseService.updateShareRecord(_shareRecord!.shareId, {
        'accessRequested': true,
      });

      // Update local state
      setState(() {
        _shareRecord = _shareRecord!.copyWith(accessRequested: true);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access request sent to document owner'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to request access: $e');
    }
  }


  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real implementation, you would fetch the document metadata
      // For now, create a mock document with the IPFS CID
      _document = HealthDocument(
        id: _shareRecord!.documentId,
        fileName: 'Shared Document',
        fileType: 'image', // You'd determine this from metadata
        ipfsCid: _shareRecord!.ipfsCid,
        documentType: 'Shared',
        doctorName: 'Shared Document',
        hospitalName: 'Via Share',
        documentDate: DateTime.now(),
        notes: '',
        metadataHash: '',
        createdAt: DateTime.now(),
      );

      // Always log access when document is loaded
      await _logAccess();

    } catch (e) {
      _showError('Failed to load document: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logAccess() async {
    try {
      final accessLog = AccessLog(
        id: '',
        shareId: _shareRecord!.shareId,
        documentId: _shareRecord!.documentId,
        viewerId: null, // Anonymous access
        viewerIp: null, // Would be populated on server side
        accessedAt: DateTime.now(),
        action: 'viewed',
      );

      await _firebaseService.logAccess(accessLog);
    } catch (e) {
      debugPrint('Failed to log access: $e');
    }
  }

  void _downloadDocument() async {
    try {
      final accessLog = AccessLog(
        id: '',
        shareId: _shareRecord!.shareId,
        documentId: _shareRecord!.documentId,
        viewerId: null,
        viewerIp: null,
        accessedAt: DateTime.now(),
        action: 'downloaded',
      );

      await _firebaseService.logAccess(accessLog);

      final downloadUrl = _ipfsService.getFileUrl(_document!.ipfsCid);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download URL: $downloadUrl'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              // In a real app, you would open the URL in browser or download the file
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Download failed: $e');
    }
  }

  void _startQRScan() {
    _scannerController = MobileScannerController();
    setState(() {
      _isScanning = true;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _pinController.dispose();
    super.dispose();
  }
}

// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mLeftTopX = borderWidthSize - cutOutSize / 2 + borderOffset;
    final mLeftTopY = height / 2 - cutOutSize / 2 + borderOffset;
    final mRightBottomX = borderWidthSize + cutOutSize / 2 - borderOffset;
    final mRightBottomY = height / 2 + cutOutSize / 2 - borderOffset;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTRB(
      mLeftTopX,
      mLeftTopY,
      mRightBottomX,
      mRightBottomY,
    );

    canvas
      ..saveLayer(
        rect,
        Paint(),
      )
      ..drawRect(rect, Paint()..color = overlayColor)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      );

    canvas.restore();

    final path = Path()
      ..moveTo(mLeftTopX - borderOffset, mLeftTopY + borderLength)
      ..lineTo(mLeftTopX - borderOffset, mLeftTopY)
      ..lineTo(mLeftTopX + borderLength, mLeftTopY - borderOffset)
      ..moveTo(mRightBottomX + borderOffset, mRightBottomY - borderLength)
      ..lineTo(mRightBottomX + borderOffset, mRightBottomY)
      ..lineTo(mRightBottomX - borderLength, mRightBottomY + borderOffset)
      ..moveTo(mLeftTopX - borderOffset, mRightBottomY - borderLength)
      ..lineTo(mLeftTopX - borderOffset, mRightBottomY)
      ..lineTo(mLeftTopX + borderLength, mRightBottomY + borderOffset)
      ..moveTo(mRightBottomX + borderOffset, mLeftTopY + borderLength)
      ..lineTo(mRightBottomX + borderOffset, mLeftTopY)
      ..lineTo(mRightBottomX - borderLength, mLeftTopY - borderOffset);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}