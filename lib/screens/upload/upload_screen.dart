import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  // Theme colors
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color lightGreen = Color(0xFFECFDF5);
  static const Color darkGreen = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isUploading ? _buildUploadProgressScreen() : _buildUploadForm(),
    );
  }

  Widget _buildUploadForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // File selection section
            _buildFileSelectionSection(),
            const SizedBox(height: 24),
            
            // Form section
            _buildFormSection(),
            const SizedBox(height: 32),
            
            // Upload button
            _buildUploadButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_upload, color: primaryGreen, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Document Upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your files are encrypted and stored securely on blockchain',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Document',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_selectedFile == null) ...[
            Text(
              'Choose how you want to upload your health document:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                _buildUploadOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: primaryGreen,
                  onTap: _pickImageFromCamera,
                ),
                const SizedBox(width: 12),
                _buildUploadOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: const Color(0xFF3B82F6),
                  onTap: _pickImageFromGallery,
                ),
                const SizedBox(width: 12),
                _buildUploadOption(
                  icon: Icons.picture_as_pdf,
                  label: 'PDF',
                  color: const Color(0xFFEF4444),
                  onTap: _pickPDFFile,
                ),
              ],
            ),
          ] else ...[
            _buildSelectedFilePreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
              color: _fileType == 'pdf' ? const Color(0xFFEF4444) : primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFile!.path.split('/').last,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_selectedFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _fileType = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          
          // Document Type
          _buildFormField(
            label: 'Document Type',
            icon: Icons.category,
            child: DropdownButtonFormField<String>(
              value: _documentType,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
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
          ),
          const SizedBox(height: 16),
          
          // Doctor Name (Auto-detected)
          _buildFormField(
            label: 'Doctor Name (Auto-detected)',
            icon: Icons.person,
            child: TextFormField(
              controller: _doctorController,
              readOnly: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Will be auto-detected from document',
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Doctor name not detected. Please select a clearer document.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Hospital/Clinic (Auto-detected)
          _buildFormField(
            label: 'Hospital/Clinic (Auto-detected)',
            icon: Icons.local_hospital,
            child: TextFormField(
              controller: _hospitalController,
              readOnly: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Will be auto-detected from document',
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Hospital name not detected. Please select a clearer document.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Document Date
          _buildFormField(
            label: 'Document Date',
            icon: Icons.calendar_today,
            child: InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_documentDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    Icon(Icons.calendar_month, color: primaryGreen),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Notes
          _buildFormField(
            label: 'Notes (Optional)',
            icon: Icons.note,
            child: TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Add any additional notes...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: primaryGreen),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: darkGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final bool canUpload = _selectedFile != null;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canUpload ? _uploadDocument : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: primaryGreen.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 24),
            const SizedBox(width: 12),
            Text(
              canUpload ? 'Upload Document' : 'Select a file first',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgressScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
                  strokeWidth: 4,
                ),
                Icon(Icons.cloud_upload, color: primaryGreen, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _uploadStatus,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your document is being securely uploaded and encrypted...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LinearProgressIndicator(
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  // Advanced ML-based text extraction with preprocessing
  Future<String> _extractTextFromImage(File imageFile) async {
    try {
      // Preprocess image for better OCR accuracy
      final preprocessedImage = await _preprocessImage(imageFile);
      
      final inputImage = mlkit.InputImage.fromFile(preprocessedImage);
      final textRecognizer = mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);
      final mlkit.RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // Extract structured text with confidence scoring
      String extractedText = _processRecognizedText(recognizedText);
      
      await textRecognizer.close();
      
      // Clean up temporary preprocessed image
      if (preprocessedImage.path != imageFile.path) {
        await preprocessedImage.delete();
      }
      
      return extractedText;
    } catch (e) {
      throw Exception('Failed to extract text from image: $e');
    }
  }

  // Image preprocessing for better OCR accuracy
  Future<File> _preprocessImage(File originalImage) async {
    try {
      // For now, return original image
      // In production, you could add image enhancement here:
      // - Contrast adjustment
      // - Noise reduction
      // - Deskewing
      // - Resolution enhancement
      return originalImage;
    } catch (e) {
      return originalImage;
    }
  }

  // Process recognized text with confidence scoring
  String _processRecognizedText(mlkit.RecognizedText recognizedText) {
    StringBuffer processedText = StringBuffer();
    
    for (mlkit.TextBlock block in recognizedText.blocks) {
      for (mlkit.TextLine line in block.lines) {
        // Include all text (confidence scoring not available in current ML Kit version)
        processedText.writeln(line.text);
      }
    }
    
    return processedText.toString();
  }

  // Extract text from PDF
  Future<String> _extractTextFromPDF(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  // Helper method to get month name variations
  List<String> _getMonthVariations(int month) {
    const monthNames = {
      1: ['Jan', 'January'],
      2: ['Feb', 'February'],
      3: ['Mar', 'March'],
      4: ['Apr', 'April'],
      5: ['May', 'May'],
      6: ['Jun', 'June'],
      7: ['Jul', 'July'],
      8: ['Aug', 'August'],
      9: ['sep', 'sept', 'September'],
      10: ['Oct', 'October'],
      11: ['Nov', 'November'],
      12: ['Dec', 'December'],
    };
    return monthNames[month] ?? [];
  }

  // Auto-extract document information from OCR text
  Map<String, String> _extractDocumentInfo(String extractedText) {
    // Extract doctor name
    String doctorName = _extractDoctorName(extractedText);
    
    // Extract hospital name
    String hospitalName = _extractHospitalName(extractedText);
    
    // Extract date
    String documentDate = _extractDocumentDate(extractedText);
    
    return {
      'doctor': doctorName,
      'hospital': hospitalName,
      'date': documentDate,
    };
  }

  // Replace these methods in your _UploadScreenState class

String _extractDoctorName(String text) {
  List<String> lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  
  // Strategy 1: Direct "Dr." or "Doctor" prefix patterns
  List<RegExp> directDoctorPatterns = [
    // Dr. Name or Dr Name
    RegExp(r'Dr\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})', caseSensitive: false),
    // Doctor Name
    RegExp(r'Doctor\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})', caseSensitive: false),
    // Dr. ALL CAPS NAME
    RegExp(r'Dr\.?\s+([A-Z]+(?:\s+[A-Z]+){1,3})', caseSensitive: false),
    // With qualifications: Dr. Name MD/MBBS/MS
    RegExp(r'Dr\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})\s*,?\s*(?:M\.?D\.?|MBBS|M\.?S\.?|DNB)?', caseSensitive: false),
  ];
  
  for (String line in lines) {
    for (RegExp pattern in directDoctorPatterns) {
      Match? match = pattern.firstMatch(line);
      if (match != null && match.group(1) != null) {
        String doctorName = match.group(1)!.trim();
        
        // Clean up any trailing punctuation or qualifications
        doctorName = doctorName.replaceAll(RegExp(r'[,\.\:\-]+$'), '');
        
        if (_isValidDoctorName(doctorName)) {
          return _formatDoctorName(doctorName);
        }
      }
    }
  }
  
  // Strategy 2: Look for names near medical keywords
  List<String> medicalKeywords = ['consultant', 'doctor', 'physician', 'specialist', 'surgeon', 'practitioner'];
  
  for (int i = 0; i < lines.length; i++) {
    String lineLower = lines[i].toLowerCase();
    
    // Check if line contains medical keyword
    bool hasMedicalKeyword = medicalKeywords.any((keyword) => lineLower.contains(keyword));
    
    if (hasMedicalKeyword) {
      // Search current line and next 2 lines
      for (int j = i; j <= i + 2 && j < lines.length; j++) {
        String candidateLine = lines[j].trim();
        
        // Check if line starts with Dr. or Doctor
        if (RegExp(r'^(?:Dr\.?|Doctor)\s', caseSensitive: false).hasMatch(candidateLine)) {
          RegExp nameExtract = RegExp(r'^(?:Dr\.?|Doctor)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})', caseSensitive: false);
          Match? match = nameExtract.firstMatch(candidateLine);
          if (match != null && match.group(1) != null) {
            String name = match.group(1)!.trim();
            if (_isValidDoctorName(name)) {
              return _formatDoctorName(name);
            }
          }
        }
        
        // Check for capitalized names (2-4 words)
        RegExp capsNamePattern = RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})(?:\s|,|$)');
        Match? match = capsNamePattern.firstMatch(candidateLine);
        if (match != null && _isValidDoctorName(match.group(1)!)) {
          return _formatDoctorName(match.group(1)!);
        }
      }
    }
  }
  
  // Strategy 3: Look for signature-like patterns at the bottom
  // Check last 5 lines for doctor signatures
  int startIndex = lines.length > 5 ? lines.length - 5 : 0;
  for (int i = startIndex; i < lines.length; i++) {
    String line = lines[i];
    
    // Signature pattern: Dr. Name or just capitalized names
    if (RegExp(r'^Dr\.?\s', caseSensitive: false).hasMatch(line)) {
      RegExp sigPattern = RegExp(r'^Dr\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})', caseSensitive: false);
      Match? match = sigPattern.firstMatch(line);
      if (match != null && _isValidDoctorName(match.group(1)!)) {
        return _formatDoctorName(match.group(1)!);
      }
    }
  }
  
  // Strategy 4: Find lines that are just names (for letterheads)
  for (int i = 0; i < math.min(10, lines.length); i++) {
    String line = lines[i];
    
    // Check if it's a name-only line (2-4 capitalized words)
    RegExp nameOnlyPattern = RegExp(r'^([A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})$');
    Match? match = nameOnlyPattern.firstMatch(line);
    
    if (match != null) {
      String potentialName = match.group(1)!;
      
      // Check next line for qualifications or medical keywords
      if (i + 1 < lines.length) {
        String nextLine = lines[i + 1].toLowerCase();
        if (nextLine.contains('mbbs') || nextLine.contains('m.d') || 
            nextLine.contains('consultant') || nextLine.contains('specialist') ||
            nextLine.contains('doctor') || nextLine.contains('physician')) {
          
          if (_isValidDoctorName(potentialName)) {
            return _formatDoctorName(potentialName);
          }
        }
      }
    }
  }
  
  return '';
}

bool _isValidDoctorName(String name) {
  String cleanName = name.trim();
  if (cleanName.isEmpty) return false;
  
  List<String> words = cleanName.split(RegExp(r'\s+'));
  
  // Should have 2-4 words
  if (words.length < 2 || words.length > 4) return false;
  
  // Each word validation
  for (String word in words) {
    // Should be at least 2 characters
    if (word.length < 2) return false;
    
    // Should not contain numbers
    if (RegExp(r'\d').hasMatch(word)) return false;
    
    // Should not contain special characters except hyphen
    if (RegExp(r'[^\w\s\-]').hasMatch(word)) return false;
    
    // Should start with a letter
    if (!RegExp(r'^[A-Za-z]').hasMatch(word)) return false;
  }
  
  // Exclude common non-name words
  List<String> excludeWords = [
    'DEPARTMENT', 'HOSPITAL', 'MEDICAL', 'CLINIC', 'CENTRE', 'CENTER', 
    'TRUST', 'OFFICE', 'BUILDING', 'FLOOR', 'ROOM', 'SUITE', 'BLOCK',
    'HEALTHCARE', 'HEALTH', 'CARE', 'PRESCRIPTION', 'PATIENT', 'NAME',
    'ADDRESS', 'DATE', 'TIME', 'PHONE', 'EMAIL', 'WEBSITE', 'REGISTRATION',
    'LICENSE', 'NUMBER', 'REGISTRY', 'COUNCIL', 'BOARD', 'ASSOCIATION'
  ];
  
  String upperName = cleanName.toUpperCase();
  for (String excluded in excludeWords) {
    if (upperName.contains(excluded)) return false;
  }
  
  return true;
}

String _formatDoctorName(String name) {
  // Convert to proper title case
  return name.trim().split(' ').map((word) {
    if (word.isEmpty) return word;
    
    // Keep all-caps short words (like initials) as uppercase
    if (word.length <= 2 && word.toUpperCase() == word) {
      return word.toUpperCase();
    }
    
    // Convert to title case
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

String _extractHospitalName(String text) {
  List<String> lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  
  // Strategy 1: Explicit hospital patterns with keywords
  List<RegExp> hospitalPatterns = [
    // Name + Hospital/Medical/Clinic/etc
    RegExp(r'^([A-Z][\w\s&,\.\-]+?)\s*(?:Hospital|Medical|Clinic|Healthcare|Health\s+Care|Nursing\s+Home|Polyclinic)', caseSensitive: false),
    RegExp(r'^([A-Z][\w\s&,\.\-]+?)\s*(?:Charitable\s+Trust|Trust|Foundation)', caseSensitive: false),
    // With location: Name Hospital, City
    RegExp(r'^([A-Z][\w\s&,\.\-]+?Hospital)[\s,]', caseSensitive: false),
    RegExp(r'^([A-Z][\w\s&,\.\-]+?Medical)[\s,]', caseSensitive: false),
    RegExp(r'^([A-Z][\w\s&,\.\-]+?Clinic)[\s,]', caseSensitive: false),
    // Registered Office pattern
    RegExp(r'Registered\s+Office\s*[:\-]?\s*([^,\n]+)', caseSensitive: false),
  ];
  
  for (String line in lines) {
    for (RegExp pattern in hospitalPatterns) {
      Match? match = pattern.firstMatch(line);
      if (match != null && match.group(1) != null) {
        String hospital = match.group(1)!.trim();
        
        // Clean up trailing punctuation
        hospital = hospital.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
        
        if (_isValidHospitalName(hospital)) {
          return _formatHospitalName(hospital);
        }
      }
    }
  }
  
  // Strategy 2: Look at first few lines (letterhead)
  for (int i = 0; i < math.min(8, lines.length); i++) {
    String line = lines[i];
    
    // Skip very short lines
    if (line.length < 10) continue;
    
    String lineLower = line.toLowerCase();
    
    // Check if contains hospital-related keywords
    bool hasHospitalKeyword = RegExp(
      r'hospital|medical|clinic|healthcare|health\s+care|nursing|polyclinic|trust|foundation|charitable',
      caseSensitive: false
    ).hasMatch(line);
    
    if (hasHospitalKeyword && _isValidHospitalName(line)) {
      // This line likely contains the hospital name
      String cleaned = line.replaceAll(RegExp(r'[\.\,\:\-]+$'), '').trim();
      return _formatHospitalName(cleaned);
    }
    
    // Check if it's a prominent organization name (all caps, prominent position)
    if (i < 3 && line.length > 15 && _isValidHospitalName(line)) {
      // Check if next line has address or contact info (confirms this is organization name)
      if (i + 1 < lines.length) {
        String nextLine = lines[i + 1].toLowerCase();
        if (nextLine.contains('address') || nextLine.contains('ph:') || 
            nextLine.contains('phone') || nextLine.contains('email') ||
            RegExp(r'\d{6}').hasMatch(nextLine)) { // Pincode pattern
          return _formatHospitalName(line);
        }
      }
    }
  }
  
  // Strategy 3: Look for organization names with full words
  for (int i = 0; i < math.min(5, lines.length); i++) {
    String line = lines[i];
    
    // Pattern: Multi-word capitalized organization names
    if (RegExp(r'^[A-Z][\w\s&,\.\-]{15,}$').hasMatch(line)) {
      // Must contain at least 3 words
      List<String> words = line.split(RegExp(r'\s+'));
      if (words.length >= 3 && _isValidHospitalName(line)) {
        return _formatHospitalName(line);
      }
    }
  }
  
  return '';
}

bool _isValidHospitalName(String name) {
  String cleanName = name.trim();
  
  // Minimum length check
  if (cleanName.length < 5) return false;
  
  // Should not be just numbers
  if (RegExp(r'^\d+$').hasMatch(cleanName)) return false;
  
  // Should contain at least 2 words
  if (!cleanName.contains(' ')) return false;
  
  // Exclude common non-hospital text patterns
  List<String> excludePatterns = [
    'PATIENT', 'AGE', 'SEX', 'DATE', 'TIME', 'DIAGNOSIS', 'PRESCRIPTION',
    'MEDICINE', 'DOSAGE', 'QUANTITY', 'EPISODE', 'VISIT', 'APPOINTMENT',
    'BILL', 'INVOICE', 'RECEIPT', 'AMOUNT', 'TOTAL', 'PAYMENT',
    'MORNING', 'AFTERNOON', 'EVENING', 'NIGHT', 'MALE', 'FEMALE',
    'YEARS', 'MONTHS', 'DAYS', 'ADDRESS OF PATIENT', 'PHONE NUMBER'
  ];
  
  String upperName = cleanName.toUpperCase();
  for (String excluded in excludePatterns) {
    if (upperName.contains(excluded)) return false;
  }
  
  // Should not be mostly numbers
  int digitCount = cleanName.replaceAll(RegExp(r'\D'), '').length;
  if (digitCount > cleanName.length * 0.3) return false;
  
  return true;
}

String _formatHospitalName(String name) {
  String cleaned = name.trim();
  
  // Remove common prefixes/suffixes that might be included
  cleaned = cleaned.replaceAll(RegExp(r'^(The\s+)', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s*[\-\,].*$'), ''); // Remove everything after dash or comma
  
  // Convert to proper title case while preserving acronyms and special formatting
  return cleaned.split(' ').map((word) {
    if (word.isEmpty) return word;
    
    // Keep short all-caps words (acronyms) as-is
    if (word.length <= 4 && word.toUpperCase() == word && !RegExp(r'[a-z]').hasMatch(word)) {
      return word.toUpperCase();
    }
    
    // Special words that should be lowercase
    List<String> lowercaseWords = ['and', 'of', 'the', 'for', 'in', 'at', 'to', 'a', 'an'];
    if (lowercaseWords.contains(word.toLowerCase())) {
      return word.toLowerCase();
    }
    
    // Convert to title case
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

  

 
  

  

  

  String _extractDocumentDate(String text) {
    // Common date patterns
    List<RegExp> datePatterns = [
      RegExp(r'Episode Date\s*:\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false),
      RegExp(r'Date\s*:\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false),
      RegExp(r'(\d{2}/\d{2}/\d{4})\s*\d{2}:\d{2}[AP]M', caseSensitive: false),
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{4})'),
      RegExp(r'(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})', caseSensitive: false),
    ];
    
    for (RegExp pattern in datePatterns) {
      Match? match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    
    return '';
  }

  // Enhanced date validation with intelligent parsing
  bool _validateDateInText(String text, DateTime targetDate) {
    String normalizedText = text.toLowerCase();
    
    int day = targetDate.day;
    int month = targetDate.month;
    int year = targetDate.year;
    
    // Get all possible month variations
    List<String> monthVariations = _getMonthVariations(month);
    
    // Generate various date format patterns to search for
    List<String> datePatterns = [];
    
    // Numeric formats
    datePatterns.addAll([
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year',
      '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year',
      '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year',
      '$day/${month.toString().padLeft(2, '0')}/$year',
      '$day-${month.toString().padLeft(2, '0')}-$year',
      '$day.${month.toString().padLeft(2, '0')}.$year',
      '${day.toString().padLeft(2, '0')}/$month/$year',
      '${day.toString().padLeft(2, '0')}-$month-$year',
      '${day.toString().padLeft(2, '0')}.$month.$year',
      '$day/$month/$year',
      '$day-$month-$year',
      '$day.$month.$year',
    ]);
    
    // Month name formats
    for (String monthName in monthVariations) {
      datePatterns.addAll([
        '${day.toString().padLeft(2, '0')} $monthName $year',
        '$day $monthName $year',
        '${day.toString().padLeft(2, '0')}/$monthName/$year',
        '$day/$monthName/$year',
        '${day.toString().padLeft(2, '0')}-$monthName-$year',
        '$day-$monthName-$year',
        '${day.toString().padLeft(2, '0')} / $monthName / $year',
        '$day / $monthName / $year',
        '${day.toString().padLeft(2, '0')} - $monthName - $year',
        '$day - $monthName - $year',
        '$monthName ${day.toString().padLeft(2, '0')}, $year',
        '$monthName $day, $year',
        '${day.toString().padLeft(2, '0')}th $monthName $year',
        '${day.toString().padLeft(2, '0')}st $monthName $year',
        '${day.toString().padLeft(2, '0')}nd $monthName $year',
        '${day.toString().padLeft(2, '0')}rd $monthName $year',
        '${day}th $monthName $year',
        '${day}st $monthName $year',
        '${day}nd $monthName $year',
        '${day}rd $monthName $year',
      ]);
    }
    
    // Check if any date pattern exists in the text
    for (String pattern in datePatterns) {
      if (normalizedText.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  // Validate document content against form data
  Future<bool> _processAndValidateDocument() async {
    if (_selectedFile == null) return false;
    
    try {
      String extractedText;
      
      if (_fileType == 'image') {
        extractedText = await _extractTextFromImage(_selectedFile!);
      } else if (_fileType == 'pdf') {
        extractedText = await _extractTextFromPDF(_selectedFile!);
      } else {
        return false;
      }
      
      // Auto-extract document information
      Map<String, String> extractedInfo = _extractDocumentInfo(extractedText);
      
      // Auto-populate the form fields
      setState(() {
        _doctorController.text = extractedInfo['doctor'] ?? '';
        _hospitalController.text = extractedInfo['hospital'] ?? '';
        
        // Parse and set the date
        String dateStr = extractedInfo['date'] ?? '';
        if (dateStr.isNotEmpty) {
          try {
            // Try different date formats
            DateTime? parsedDate = _parseDate(dateStr);
            if (parsedDate != null) {
              _documentDate = parsedDate;
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      });

      // Debug information
      debugPrint('=== AUTO-EXTRACTION DEBUG ===');
      debugPrint('Extracted Text: $extractedText');
      debugPrint('Auto-detected Doctor: "${extractedInfo['doctor']}"');
      debugPrint('Auto-detected Hospital: "${extractedInfo['hospital']}"');
      debugPrint('Auto-detected Date: "${extractedInfo['date']}"');
      debugPrint('Parsed Date: ${DateFormat('dd/MM/yyyy').format(_documentDate)}');
      debugPrint('===============================');

      // Return true if we successfully extracted at least some information
      return extractedInfo['doctor']!.isNotEmpty || 
             extractedInfo['hospital']!.isNotEmpty || 
             extractedInfo['date']!.isNotEmpty;
    } catch (e) {
      _showErrorSnackBar('Error processing document: $e');
      return false;
    }
  }

  DateTime? _parseDate(String dateStr) {
    // Try different date formats
    List<String> formats = [
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'dd.MM.yyyy',
      'd/M/yyyy',
      'd-M-yyyy',
    ];
    
    for (String format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (e) {
        // Continue to next format
      }
    }
    
    // Try parsing month names
    try {
      return DateFormat('d MMM yyyy').parse(dateStr);
    } catch (e) {
      try {
        return DateFormat('d MMMM yyyy').parse(dateStr);
      } catch (e) {
        return null;
      }
    }
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
        
        // Auto-extract information from the selected document
        await _processAndValidateDocument();
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
        
        // Auto-extract information from the selected document
        await _processAndValidateDocument();
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
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileType = 'pdf';
        });
        
        // Auto-extract information from the selected document
        await _processAndValidateDocument();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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
      _uploadStatus = 'Validating document content...';
    });

    try {
      // First process and auto-extract document content
      bool isValid = await _processAndValidateDocument();
      
      if (!isValid) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
        _showErrorSnackBar(
          'Upload failed: The provided details do not match the document content. Please verify:\n'
          '• Doctor name matches the document\n'
          '• Hospital/Clinic name matches the document\n'
          '• Document date is correct'
        );
        return;
      }

      setState(() {
        _uploadStatus = 'Preparing upload...';
      });

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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Document uploaded successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
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