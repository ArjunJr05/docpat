import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../models/health_document.dart';
import '../../services/firebase_service.dart';
import '../../services/ipfs_service.dart';
import '../document/image_viewer_screen.dart';
import '../document/pdf_viewer_screen.dart';

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
  StreamSubscription<DocumentSnapshot>? _shareStatusSubscription;

  // Theme colors
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color lightGreen = Color(0xFFECFDF5);
  static const Color darkGreen = Color(0xFF047857);
  static const Color greyText = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    if (widget.shareId != null) {
      _loadShareRecord(widget.shareId!);
    }
  }

  @override
  void dispose() {
    _shareStatusSubscription?.cancel();
    _scannerController?.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Setup real-time listener for share status changes
  void _setupShareStatusListener(String shareId) {
    _shareStatusSubscription?.cancel();
    
    _shareStatusSubscription = FirebaseFirestore.instance
        .collection('shares')
        .doc(shareId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) {
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final isActive = data['active'] as bool? ?? true;
      final status = data['status'] as String? ?? 'pending';

      // Check if access has been revoked
      if (!isActive || status == 'revoked') {
        _handleAccessRevoked();
      }
    });
  }

  void _handleAccessRevoked() {
    // Cancel the listener
    _shareStatusSubscription?.cancel();

    // Show dialog and navigate away
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 12),
              Text('Access Revoked'),
            ],
          ),
          content: const Text(
            'The document owner has revoked your access to this document. You will be redirected to the home page.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ).then((_) {
        // Ensure navigation happens even if dialog is dismissed
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'View Shared Document',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_isScanning)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: _startQRScan,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: primaryGreen),
                ),
                tooltip: 'Scan QR Code',
              ),
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
        ),
      );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan QR Code or Enter Share Link',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Access shared medical documents securely',
            style: TextStyle(
              fontSize: 16,
              color: greyText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Paste share link here',
                    hintStyle: const TextStyle(color: greyText),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.link, color: primaryGreen),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onSubmitted: _handleShareLink,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startQRScan,
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
              Container(
                decoration: ShapeDecoration(
                  shape: QrScannerOverlayShape(
                    borderColor: primaryGreen,
                    borderRadius: 16,
                    borderLength: 30,
                    borderWidth: 4,
                    cutOutSize: 280,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Position the QR code within the frame',
                  style: TextStyle(
                    fontSize: 16,
                    color: greyText,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _scannerController?.toggleTorch(),
                        icon: const Icon(Icons.flash_on, color: primaryGreen),
                        label: const Text(
                          'Flash',
                          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isScanning = false;
                          });
                          _scannerController?.dispose();
                          _scannerController = null;
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty,
                      size: 64,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for Patient Approval',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The document owner needs to approve your access request. Please wait...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: greyText,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryGreen.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, color: primaryGreen, size: 28),
                        const SizedBox(height: 12),
                        const Text(
                          'Access Request Sent',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: darkGreen,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The patient will be notified to unlock this document for you.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: darkGreen.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _loadShareRecord(_shareRecord!.shareId),
                          icon: const Icon(Icons.refresh, color: primaryGreen),
                          label: const Text(
                            'Check Status',
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Auto-checking...',
                              style: TextStyle(
                                fontSize: 12,
                                color: darkGreen,
                                fontWeight: FontWeight.w600,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is a shared medical document. Handle with confidentiality.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _document!.fileType == 'image'
                ? GestureDetector(
                    onTap: () => _openImageViewer(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _ipfsService.getFileUrl(_document!.ipfsCid),
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 48, color: Colors.red),
                              SizedBox(height: 8),
                              Text('Failed to load image'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _openPdfViewer(),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                          SizedBox(height: 12),
                          Text(
                            'PDF Document',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to view full document',
                            style: TextStyle(color: greyText),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingDocument() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading document...',
            style: TextStyle(
              color: greyText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: greyText,
                fontSize: 14,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: greyText)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

    final uri = Uri.tryParse(link);
    String? shareId;

    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[uri.pathSegments.length - 2] == 'share') {
      shareId = uri.pathSegments.last;
    } else if (link.contains('/share/')) {
      shareId = link.split('/share/').last;
    } else {
      shareId = link;
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

      // Setup real-time listener for revocation
      _setupShareStatusListener(shareId);

      if (!shareRecord.unlocked) {
        if (!shareRecord.accessRequested) {
          await _requestAccess();
        }
        return;
      }

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
      await _firebaseService.updateShareRecord(_shareRecord!.shareId, {
        'accessRequested': true,
      });

      setState(() {
        _shareRecord = _shareRecord!.copyWith(accessRequested: true);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access request sent to document owner'),
          backgroundColor: primaryGreen,
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
      _document = HealthDocument(
        id: _shareRecord!.documentId,
        fileName: 'Shared Document',
        fileType: 'image',
        ipfsCid: _shareRecord!.ipfsCid,
        documentType: 'Shared',
        doctorName: 'Shared Document',
        hospitalName: 'Via Share',
        documentDate: DateTime.now(),
        notes: '',
        metadataHash: '',
        createdAt: DateTime.now(),
      );

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
        viewerId: null,
        viewerIp: null,
        accessedAt: DateTime.now(),
        action: 'viewed',
      );

      await _firebaseService.logAccess(accessLog);
    } catch (e) {
      debugPrint('Failed to log access: $e');
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
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openImageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          imageUrl: _ipfsService.getFileUrl(_document!.ipfsCid),
          title: _document!.fileName,
        ),
      ),
    );
  }

  void _openPdfViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: _ipfsService.getFileUrl(_document!.ipfsCid),
          title: _document!.fileName,
        ),
      ),
    );
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
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
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