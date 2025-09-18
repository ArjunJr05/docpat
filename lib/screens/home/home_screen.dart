import 'package:docpat2/screens/profile/profile_screen.dart';
import 'package:docpat2/screens/upload/upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/health_document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/firebase_service.dart';
import '../document/document_detail_screen.dart';
import '../share/share_view_screen.dart';
import '../share/pending_requests_screen.dart';
import '../share/sender_notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  int _pendingRequestsCount = 0;
  final _searchController = TextEditingController();
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start with FAB visible if we're on documents tab
    if (_currentIndex == 0) {
      _fabAnimationController.forward();
    }
    
    // Defer loading documents to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userId != null) {
        Provider.of<DocumentProvider>(context, listen: false).loadDocuments(authProvider.userId!);
        _loadPendingRequestsCount();
      }
    });
  }

  Future<void> _loadPendingRequestsCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.userId != null) {
      try {
        final shares = await _firebaseService.getUserActiveShares(authProvider.userId!);
        final pendingCount = shares.where((share) => 
          share.accessRequested && !share.unlocked
        ).length;
        
        setState(() {
          _pendingRequestsCount = pendingCount;
        });
      } catch (e) {
        debugPrint('Error loading pending requests count: $e');
      }
    }
  }

  Future<void> _loadDocuments() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId != null) {
      await Provider.of<DocumentProvider>(context, listen: false).loadDocuments(authProvider.userId!);
      await _loadPendingRequestsCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
      
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDocumentsTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      title: const Text('Health Documents', style: TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: 2,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Consumer<DocumentProvider>(
          builder: (context, provider, child) {
            return PopupMenuButton<String>(
              onSelected: (value) {
                provider.setSortBy(value);
              },
              icon: const Icon(Icons.sort, color: Colors.white),
              tooltip: 'Sort documents',
              color: Colors.white,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'date_desc',
                  child: Row(
                    children: [
                      Icon(Icons.access_time, 
                           color: provider.sortBy == 'date_desc' ? const Color(0xFF10B981) : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Date (Newest First)', 
                           style: TextStyle(color: provider.sortBy == 'date_desc' ? const Color(0xFF10B981) : Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'date_asc',
                  child: Row(
                    children: [
                      Icon(Icons.history, 
                           color: provider.sortBy == 'date_asc' ? const Color(0xFF10B981) : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Date (Oldest First)', 
                           style: TextStyle(color: provider.sortBy == 'date_asc' ? const Color(0xFF10B981) : Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name_asc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, 
                           color: provider.sortBy == 'name_asc' ? const Color(0xFF10B981) : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Name (A-Z)', 
                           style: TextStyle(color: provider.sortBy == 'name_asc' ? const Color(0xFF10B981) : Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name_desc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, 
                           color: provider.sortBy == 'name_desc' ? const Color(0xFF10B981) : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Name (Z-A)', 
                           style: TextStyle(color: provider.sortBy == 'name_desc' ? const Color(0xFF10B981) : Colors.black87)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ShareViewScreen(),
              ),
            );
          },
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          tooltip: 'Scan Shared Document',
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SenderNotificationsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.share, color: Colors.white),
          tooltip: 'My Shared Documents',
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PendingRequestsScreen(),
                  ),
                ).then((_) => _loadPendingRequestsCount());
              },
              icon: const Icon(Icons.notifications, color: Colors.white),
              tooltip: 'Pending Requests',
            ),
            if (_pendingRequestsCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_pendingRequestsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Animate FAB based on tab selection
          if (index == 0) {
            _fabAnimationController.forward();
          } else {
            _fabAnimationController.reverse();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Visibility(
          visible: _currentIndex == 0,
          child: Transform.scale(
            scale: _fabAnimationController.value,
            child: Opacity(
              opacity: _fabAnimationController.value,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UploadScreen()),
                  ).then((_) => _loadDocuments());
                },
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                tooltip: 'Upload Document',
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    return Column(
      children: [
        // Search and filters section
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[50],
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<DocumentProvider>(context, listen: false)
                                .setSearchQuery('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {}); // Update UI for clear button
                  Provider.of<DocumentProvider>(context, listen: false)
                      .setSearchQuery(value);
                },
              ),
              const SizedBox(height: 12),
              
              // Type filter chips
              Consumer<DocumentProvider>(
                builder: (context, provider, child) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Prescription',
                        'Lab Report',
                        'Discharge Summary',
                        'Other'
                      ].map((type) {
                        final isSelected = provider.selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              type,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              provider.setTypeFilter(type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Documents list
        Expanded(
          child: Consumer<DocumentProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF10B981)),
                      SizedBox(height: 16),
                      Text('Loading documents...'),
                    ],
                  ),
                );
              }

              final documents = provider.documents;
              
              if (documents.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async => _loadDocuments(),
                color: const Color(0xFF10B981),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    return _buildDocumentCard(documents[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.folder_open,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No documents found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Consumer<DocumentProvider>(
              builder: (context, provider, child) {
                return Text(
                  (provider.searchQuery.isNotEmpty || provider.selectedType != 'All')
                      ? ''
                      : '',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 24),
            Consumer<DocumentProvider>(
              builder: (context, provider, child) {
                if (provider.searchQuery.isNotEmpty || provider.selectedType != 'All') {
                  return ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                      provider.setTypeFilter('All');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(HealthDocument document) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTypeColor(document.documentType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTypeIcon(document.documentType),
            color: _getTypeColor(document.documentType),
            size: 24,
          ),
        ),
        title: Text(
          document.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(document.documentType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    document.documentType,
                    style: TextStyle(
                      color: _getTypeColor(document.documentType),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    document.doctorName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.local_hospital, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    document.hospitalName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(document.documentDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (document.transactionHash != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 16,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(document: document),
            ),
          ).then((_) {
            // Refresh documents when returning from detail screen
            _loadDocuments();
          });
        },
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Prescription':
        return const Color(0xFF10B981);
      case 'Lab Report':
        return Colors.blue;
      case 'Discharge Summary':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Prescription':
        return Icons.medication;
      case 'Lab Report':
        return Icons.science;
      case 'Discharge Summary':
        return Icons.local_hospital;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health Record Wallet', style: TextStyle(color: Color(0xFF10B981))),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secure, decentralized health document storage'),
            SizedBox(height: 8),
            Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Upload medical documents'),
            Text('• Blockchain verification'),
            Text('• Secure sharing with QR codes'),
            Text('• Access logging and audit trails'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
}