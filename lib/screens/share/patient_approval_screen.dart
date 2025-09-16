import 'package:flutter/material.dart';

import '../../models/health_document.dart';
import '../../services/firebase_service.dart';
import '../../services/encryption_utils.dart';

class PatientApprovalScreen extends StatefulWidget {
  final ShareRecord shareRecord;

  const PatientApprovalScreen({
    super.key,
    required this.shareRecord,
  });

  @override
  State<PatientApprovalScreen> createState() => _PatientApprovalScreenState();
}

class _PatientApprovalScreenState extends State<PatientApprovalScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _pinController = TextEditingController();
  bool _isUnlocking = false;
  bool _pinVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Document Access'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon and title
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.security,
                            size: 64,
                            color: Colors.orange[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Access Request Received',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Someone is requesting access to your shared document.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share ID: ${widget.shareRecord.shareId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // PIN entry section
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Enter your PIN to approve access:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: !_pinVisible,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Enter PIN',
                            hintText: 'Your 6-digit PIN',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _pinVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _pinVisible = !_pinVisible;
                                });
                              },
                            ),
                          ),
                          onSubmitted: (_) => _unlockDocument(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isUnlocking ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isUnlocking ? null : _unlockDocument,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                                child: _isUnlocking
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Approve Access'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Warning footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Only approve access if you trust the person requesting it. This will grant them temporary access to your medical document.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlockDocument() async {
    if (_pinController.text.isEmpty) {
      _showError('Please enter your PIN');
      return;
    }

    setState(() {
      _isUnlocking = true;
    });

    try {
      // Verify PIN
      final pinParts = widget.shareRecord.pinHash!.split(':');
      if (pinParts.length != 2) {
        _showError('Invalid PIN format');
        return;
      }

      final hash = pinParts[0];
      final salt = pinParts[1];

      if (!EncryptionUtils.verifyPin(_pinController.text, hash, salt)) {
        _showError('Incorrect PIN');
        return;
      }

      // Update share record to unlock document
      await _firebaseService.updateShareRecord(widget.shareRecord.shareId, {
        'unlocked': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document access approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true); // Return true to indicate success
      }

    } catch (e) {
      _showError('Failed to approve access: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
        });
      }
    }
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

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
