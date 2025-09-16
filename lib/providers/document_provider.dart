import 'package:flutter/foundation.dart';
import '../models/health_document.dart';
import '../services/firebase_service.dart';

class DocumentProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<HealthDocument> _documents = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedType = 'All';
  String _sortBy = 'date_desc';

  List<HealthDocument> get documents => _getFilteredDocuments();
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedType => _selectedType;
  String get sortBy => _sortBy;

  List<HealthDocument> _getFilteredDocuments() {
    var filtered = _documents.where((doc) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!doc.fileName.toLowerCase().contains(query) &&
            !doc.doctorName.toLowerCase().contains(query) &&
            !doc.hospitalName.toLowerCase().contains(query) &&
            !doc.notes.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Type filter
      if (_selectedType != 'All' && doc.documentType != _selectedType) {
        return false;
      }
      
      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.fileName.compareTo(b.fileName));
        break;
      case 'name_desc':
        filtered.sort((a, b) => b.fileName.compareTo(a.fileName));
        break;
    }
    
    return filtered;
  }

  Future<void> loadDocuments(String userId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _documents = await _firebaseService.getUserDocuments(userId);
    } catch (e) {
      debugPrint('Error loading documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  Future<bool> deleteDocument(String documentId, String userId) async {
    try {
      await _firebaseService.deleteDocument(documentId, userId);
      _documents.removeWhere((doc) => doc.id == documentId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }
}