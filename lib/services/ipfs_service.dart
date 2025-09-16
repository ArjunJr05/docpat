import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class IpfsService {
  static const String _web3StorageUrl = 'https://api.web3.storage';
  static const String _pinataUrl = 'https://api.pinata.cloud';
  
  String get _apiKey => dotenv.env['WEB3_STORAGE_API_KEY'] ?? '';
  String get _pinataApiKey => dotenv.env['PINATA_API_KEY'] ?? '';
  String get _pinataSecretKey => dotenv.env['PINATA_SECRET_KEY'] ?? '';
  String get _gatewayUrl => dotenv.env['IPFS_GATEWAY_URL'] ?? 'https://gateway.pinata.cloud/ipfs/';

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      // Try Pinata first (free tier available)
      if (_pinataApiKey.isNotEmpty && _pinataSecretKey.isNotEmpty) {
        return await _uploadToPinata(file, fileName);
      }
      
      // Fallback to self-hosted IPFS node
      return await _uploadToSelfHostedNode(file, fileName);
    } catch (e) {
      print('IPFS upload error: $e');
      return null;
    }
  }

  // Pinata IPFS upload (Free tier: 1GB storage, 100GB bandwidth/month)
  Future<String?> _uploadToPinata(File file, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_pinataUrl/pinning/pinFileToIPFS'),
    );

    request.headers['pinata_api_key'] = _pinataApiKey;
    request.headers['pinata_secret_api_key'] = _pinataSecretKey;
    
    request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));
    
    // Add metadata
    request.fields['pinataMetadata'] = json.encode({
      'name': fileName,
      'keyvalues': {
        'type': 'health_document',
        'uploaded_at': DateTime.now().toIso8601String(),
      }
    });

    final response = await request.send();
    
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      print('Pinata upload successful: ${jsonResponse['IpfsHash']}');
      return jsonResponse['IpfsHash']; // Returns the IPFS hash/CID
    } else {
      print('Pinata upload failed: ${response.statusCode}');
      final errorBody = await response.stream.bytesToString();
      print('Error body: $errorBody');
      return null;
    }
  }

  // Alternative: Self-hosted IPFS node upload
  Future<String?> _uploadToSelfHostedNode(File file, String fileName) async {
    // Replace with your IPFS node URL
    const String ipfsNodeUrl = 'http://localhost:5001/api/v0/add';
    
    final request = http.MultipartRequest('POST', Uri.parse(ipfsNodeUrl));
    request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));

    final response = await request.send();
    
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      return jsonResponse['Hash']; // IPFS hash/CID
    } else {
      print('IPFS node upload failed: ${response.statusCode}');
      return null;
    }
  }

  String getFileUrl(String cid) {
    return '$_gatewayUrl$cid';
  }

  // Pin file to ensure persistence (Web3.Storage automatically pins)
  Future<bool> pinFile(String cid) async {
    try {
      final response = await http.post(
        Uri.parse('$_web3StorageUrl/pins'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'cid': cid,
          'name': 'Health Document $cid',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Pin error: $e');
      return false;
    }
  }
}