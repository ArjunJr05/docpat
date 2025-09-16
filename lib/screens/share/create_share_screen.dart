import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/health_document.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/encryption_utils.dart';

class CreateShareScreen extends StatefulWidget {
  final HealthDocument document;

  const CreateShareScreen({super.key, required this.document});

  @override
  State<CreateShareScreen> createState() => _CreateShareScreenState();
}

class _CreateShareScreenState extends State<CreateShareScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  final _pinApprovalController = TextEditingController();
  final _pinSetupController = TextEditingController();

  bool _isCreating = false;
  ShareRecord? _createdShare;
  String? _permanentPin;
  bool _isLoadingPin = true;
  bool _pinVisible = false;
  bool _isApproving = false;
  bool _needsPinSetup = false;
  bool _isSettingUpPin = false;

  @override
  void initState() {
    super.initState();
    _loadPermanentPin();
  }

  Future<void> _loadPermanentPin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final pinData = await _firebaseService.getUserPermanentPin(authProvider.userId!);
      if (pinData != null) {
        // Extract the actual PIN from stored data
        final parts = pinData.split(':');
        if (parts.length >= 3) {
          // Format: hash:salt:actualPin
          final actualPin = parts[2];
          setState(() {
            _permanentPin = actualPin;
            _isLoadingPin = false;
            _needsPinSetup = false;
          });
        } else {
          // Old format without actual PIN, need setup
          setState(() {
            _needsPinSetup = true;
            _isLoadingPin = false;
          });
        }
      } else {
        // No PIN exists, first time user
        setState(() {
          _needsPinSetup = true;
          _isLoadingPin = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPin = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PIN: $e')),
        );
      }
    }
  }

  Future<void> _setupPermanentPin() async {
    final pin = _pinSetupController.text.trim();
    
    if (pin.length < 4 || pin.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4-6 digits')),
      );
      return;
    }
    
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must contain only numbers')),
      );
      return;
    }

    setState(() {
      _isSettingUpPin = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final salt = EncryptionUtils.generateSalt();
      final pinHash = EncryptionUtils.hashPin(pin, salt);
      
      // Store in format: hash:salt:actualPin
      final pinData = '$pinHash:$salt:$pin';
      
      await _firebaseService.setUserPermanentPin(authProvider.userId!, pinData);
      
      setState(() {
        _permanentPin = pin;
        _needsPinSetup = false;
        _isSettingUpPin = false;
        _isLoadingPin = false;
      });
      
      _pinSetupController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN set successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSettingUpPin = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting PIN: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Document'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _createdShare != null ? _buildShareResult() : _buildShareForm(),
      bottomNavigationBar: _createdShare != null ? null : _buildActivitySection(),
    );
  }

  Widget _buildPinSetupForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.blue[700],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Set Up Your Permanent PIN',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Create a 4-6 digit PIN that you\'ll use to approve document access requests.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinSetupController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: !_pinVisible,
                  decoration: InputDecoration(
                    labelText: 'Enter Your PIN (4-6 digits)',
                    hintText: 'Choose a memorable PIN',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.pin),
                    suffixIcon: IconButton(
                      icon: Icon(_pinVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _pinVisible = !_pinVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSettingUpPin ? null : _setupPermanentPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSettingUpPin
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Setting up PIN...'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check),
                              SizedBox(width: 8),
                              Text('Set PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareForm() {
    if (_needsPinSetup) {
      return _buildPinSetupForm();
    }
    
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Document info card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Document to Share',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getDocumentTypeColor(widget.document.documentType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getDocumentIcon(widget.document.documentType),
                            color: _getDocumentTypeColor(widget.document.documentType),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.document.fileName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.document.documentType} • ${widget.document.doctorName}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              Text(
                                widget.document.hospitalName,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PIN Display card
          if (_isLoadingPin)
            const Center(child: CircularProgressIndicator())
          else if (_permanentPin != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Your PIN',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _permanentPin!,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This is your permanent PIN for document sharing',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Create share button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isCreating || _permanentPin == null) ? null : _createShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isCreating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating Share Link...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Create Share Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareResult() {
    final shareUrl = '${dotenv.env['SHARE_BASE_URL'] ?? 'https://example.com/share'}/${_createdShare!.shareId}';
    
    return StreamBuilder<ShareRecord?>(
      stream: _watchShareRecord(),
      builder: (context, snapshot) {
        final currentShare = snapshot.data ?? _createdShare!;
        
        // If someone is waiting for approval, show PIN entry
        if (currentShare.accessRequested && !currentShare.unlocked) {
          return _buildPinApprovalView(shareUrl);
        }
        
        // Otherwise show normal QR code view
        return _buildQRCodeView(shareUrl, currentShare);
      },
    );
  }

  Stream<ShareRecord?> _watchShareRecord() {
    // Real-time Firestore stream listener for immediate updates
    return Stream.periodic(const Duration(milliseconds: 500), (count) async {
      try {   
        return await _firebaseService.getShareRecord(_createdShare!.shareId);
      } catch (e) {
        return _createdShare;
      }
    }).asyncMap((future) => future);
  }

  Widget _buildPinApprovalView(String shareUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Access request notification
          Card(
            elevation: 2,
            color: Colors.orange[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.notification_important,
                    color: Colors.orange[700],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Request Received!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Someone is requesting access to your document. Enter your PIN to approve.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PIN entry card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Enter Your PIN to Approve Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinApprovalController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: !_pinVisible,
                    decoration: InputDecoration(
                      labelText: 'Your PIN',
                      hintText: 'Enter your permanent PIN',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_pinVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _pinVisible = !_pinVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isApproving ? null : _approveAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isApproving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Approving...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle),
                                SizedBox(width: 8),
                                Text('Approve Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // QR code still visible but smaller
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Share Link (QR Code)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: QrImageView(
                      data: shareUrl,
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeView(String shareUrl, ShareRecord currentShare) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success header
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Share Link Created!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your document can now be securely shared',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // QR Code card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'QR Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      shareUrl,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Share info
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.description, 'Document', widget.document.fileName),
                  _buildInfoRow(Icons.person, 'Owner', 'Patient'),
                  _buildInfoRow(Icons.access_time, 'Expires', 
                    '${_createdShare!.expiresAt.day}/${_createdShare!.expiresAt.month}/${_createdShare!.expiresAt.year}'),
                  _buildInfoRow(Icons.security, 'Security', 'PIN Protected'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Documents'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement share functionality
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createShare() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final shareId = DateTime.now().millisecondsSinceEpoch.toString();
      final expiresAt = DateTime.now().add(const Duration(days: 1)); // Default 1 day expiry
      
      // Hash the permanent PIN for storage
      final salt = EncryptionUtils.generateSalt();
      final pinHash = '${EncryptionUtils.hashPin(_permanentPin!, salt)}:$salt:${_permanentPin!}';

      final shareRecord = ShareRecord(
        id: '',
        shareId: shareId,
        documentId: widget.document.id,
        ownerId: authProvider.userId!,
        ipfsCid: widget.document.ipfsCid,
        pinHash: pinHash,
        expiresAt: expiresAt,
        active: true,
        createdAt: DateTime.now(),
        unlocked: false,
        accessRequested: false,
      );

      final docId = await _firebaseService.createShareRecord(shareRecord);
      
      setState(() {
        _createdShare = shareRecord.copyWith(id: docId);
        _isCreating = false;
      });

    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveAccess() async {
    if (_pinApprovalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your PIN')),
      );
      return;
    }

    setState(() {
      _isApproving = true;
    });

    try {
      // Verify PIN against stored permanent PIN
      if (_pinApprovalController.text == _permanentPin) {
        // PIN is correct, unlock the document immediately
        await _firebaseService.updateShareRecord(_createdShare!.shareId, {
          'unlocked': true,
        });
        
        // Update local state immediately for instant UI feedback
        setState(() {
          _createdShare = _createdShare!.copyWith(unlocked: true);
        });
        
        _pinApprovalController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access approved! Document unlocked instantly.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving access: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isApproving = false;
      });
    }
  }

  Widget _buildActivitySection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AccessLog>>(
              future: _firebaseService.getDocumentRecentActivity(widget.document.id, limit: 4),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No recent activity',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return _buildActivityItem(activity);
                        },
                      ),
                    ),
                    if (activities.length >= 4)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _showAllActivity(),
                            child: const Text('View All Activity'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(AccessLog activity) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getActivityColor(activity.action),
        child: Icon(
          _getActivityIcon(activity.action),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        _getActivityTitle(activity.action),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatDateTime(activity.accessedAt),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: activity.viewerId != null 
        ? Icon(Icons.person, color: Colors.grey[400], size: 16)
        : Icon(Icons.public, color: Colors.grey[400], size: 16),
    );
  }

  Color _getActivityColor(String action) {
    switch (action.toLowerCase()) {
      case 'viewed':
        return Colors.blue;
      case 'downloaded':
        return Colors.green;
      case 'shared':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action.toLowerCase()) {
      case 'viewed':
        return Icons.visibility;
      case 'downloaded':
        return Icons.download;
      case 'shared':
        return Icons.share;
      default:
        return Icons.info;
    }
  }

  String _getActivityTitle(String action) {
    switch (action.toLowerCase()) {
      case 'viewed':
        return 'Document viewed';
      case 'downloaded':
        return 'Document downloaded';
      case 'shared':
        return 'Document shared';
      default:
        return 'Activity recorded';
    }
  }

  void _showAllActivity() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 8),
                    const Text(
                      'All Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<AccessLog>>(
                  future: _firebaseService.getDocumentAccessLogs(widget.document.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No activity found'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return _buildActivityItem(snapshot.data![index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _pinApprovalController.dispose();
    _pinSetupController.dispose();
    super.dispose();
  }

  Color _getDocumentTypeColor(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'prescription':
        return Colors.green;
      case 'lab report':
        return Colors.blue;
      case 'x-ray':
        return Colors.purple;
      case 'mri scan':
        return Colors.orange;
      case 'ct scan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getDocumentIcon(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'prescription':
        return Icons.medication;
      case 'lab report':
        return Icons.science;
      case 'x-ray':
        return Icons.medical_services;
      case 'mri scan':
        return Icons.monitor_heart;
      case 'ct scan':
        return Icons.local_hospital;
      default:
        return Icons.description;
    }
  }
}
