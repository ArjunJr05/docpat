import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/auth_provider.dart';
import '../../services/ipfs_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/firebase_service.dart';
import '../../services/encryption_utils.dart';
import '../../models/health_document.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();

  File? _selectedFile;
  String _fileType = '';
  String _documentType = 'Prescription';
  DateTime _documentDate = DateTime.now();
  bool _isUploading = false;
  String _uploadStatus = '';

  final IpfsService _ipfsService = IpfsService();
  final BlockchainService _blockchainService = BlockchainService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // File selection card
            _buildFileSelectionCard(),
            const SizedBox(height: 16),

            // Document metadata card
            _buildMetadataCard(),
            const SizedBox(height: 24),

            // Upload progress (only show when uploading)
            if (_isUploading) _buildUploadProgress(),

            // Upload button
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Select Document',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedFile == null) ...[
              const Text(
                'Choose how you want to add your document:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildFilePickerButton(
                      onPressed: _pickImageFromCamera,
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilePickerButton(
                      onPressed: _pickImageFromGallery,
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilePickerButton(
                      onPressed: _pickPDFFile,
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildSelectedFileDisplay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSelectedFileDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fileType == 'pdf' ? Colors.red[100] : Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
              size: 32,
              color: _fileType == 'pdf' ? Colors.red[700] : Colors.blue[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFile!.path.split('/').last,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_selectedFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  _fileType == 'pdf' ? 'PDF Document' : 'Image File',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _fileType = '';
              });
            },
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Document Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Document type dropdown
            DropdownButtonFormField<String>(
              value: _documentType,
              decoration: InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.category),
              ),
              items: ['Prescription', 'Lab Report', 'Discharge Summary', 'Other']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _documentType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Doctor name field
            TextFormField(
              controller: _doctorController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Doctor Name',
                hintText: 'Enter doctor\'s full name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter doctor name';
                }
                if (value.trim().length < 2) {
                  return 'Doctor name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Hospital/Clinic field
            TextFormField(
              controller: _hospitalController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Hospital/Clinic',
                hintText: 'Enter hospital or clinic name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.local_hospital),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter hospital/clinic name';
                }
                if (value.trim().length < 2) {
                  return 'Hospital name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Document date picker
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Document Date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_documentDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any additional notes about this document',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.note_alt_outlined),
                alignLabelWithHint: true,
              ),
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _uploadStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final bool canUpload = _selectedFile != null && !_isUploading;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canUpload ? _uploadDocument : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _isUploading
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
                  Text('Uploading...', style: TextStyle(fontSize: 16)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFile == null ? 'Select a file first' : 'Upload Document',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _fileType = 'image';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _fileType = 'image';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickPDFFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Check file size (limit to 50MB)
        final fileSizeInMB = file.lengthSync() / (1024 * 1024);
        if (fileSizeInMB > 50) {
          _showErrorSnackBar('File size must be less than 50MB');
          return;
        }
        
        setState(() {
          _selectedFile = file;
          _fileType = 'pdf';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick PDF: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select document date',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (picked != null && picked != _documentDate) {
      setState(() {
        _documentDate = picked;
      });
    }
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparing upload...';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId!;
      final fileName = _selectedFile!.path.split('/').last;

      // Step 1: Upload to IPFS
      _showUploadStep('Uploading file to IPFS...');
      final cid = await _ipfsService.uploadFile(_selectedFile!, fileName);
      
      if (cid == null) {
        throw Exception('Failed to upload file to IPFS');
      }

      // Step 2: Create document metadata
      _showUploadStep('Creating document record...');
      final document = HealthDocument(
        id: const Uuid().v4(),
        fileName: fileName,
        fileType: _fileType,
        ipfsCid: cid,
        documentType: _documentType,
        doctorName: _doctorController.text.trim(),
        hospitalName: _hospitalController.text.trim(),
        documentDate: _documentDate,
        notes: _notesController.text.trim(),
        metadataHash: '',
        createdAt: DateTime.now(),
      );

      // Hash metadata for blockchain
      final metadataHash = EncryptionUtils.hashMetadata(document.getMetadataForHashing());
      final updatedDocument = HealthDocument(
        id: document.id,
        fileName: document.fileName,
        fileType: document.fileType,
        ipfsCid: document.ipfsCid,
        documentType: document.documentType,
        doctorName: document.doctorName,
        hospitalName: document.hospitalName,
        documentDate: document.documentDate,
        notes: document.notes,
        metadataHash: metadataHash,
        createdAt: document.createdAt,
      );

      // Step 3: Store in Firestore
      _showUploadStep('Saving to database...');
      final documentId = await _firebaseService.saveDocument(userId, updatedDocument);

      // Step 4: Store on blockchain
      _showUploadStep('Recording on blockchain...');
      final recordId = DateTime.now().millisecondsSinceEpoch;
      
      try {
        final txHash = await _blockchainService.storeDocument(recordId, cid, metadataHash);

        if (txHash != null) {
          // Update document with blockchain info
          await _firebaseService.updateDocument(userId, documentId, {
            'blockchainRecordId': recordId,
            'transactionHash': txHash,
          });
          _showUploadStep('Document verified on blockchain!');
        } else {
          // Blockchain failed but document is still saved
          debugPrint('Blockchain storage failed, but document is saved in database');
        }
      } catch (blockchainError) {
        // Continue even if blockchain fails
        debugPrint('Blockchain error: $blockchainError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Document uploaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }

    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _showUploadStep(String message) {
    if (mounted) {
      setState(() {
        _uploadStatus = message;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}