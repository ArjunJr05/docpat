# Health Record Wallet - Decentralized Medical Document Management System

A comprehensive Flutter-based mobile application for secure, decentralized health document management using blockchain technology, IPFS storage, and Firebase backend services.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Core Features](#core-features)
- [System Flow](#system-flow)
- [Smart Contract](#smart-contract)
- [Services & Components](#services--components)
- [Data Models](#data-models)
- [Screens & UI](#screens--ui)
- [Setup & Installation](#setup--installation)
- [Environment Configuration](#environment-configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Security Features](#security-features)
- [API Reference](#api-reference)

---

## 🎯 Overview

**Health Record Wallet** is a decentralized application (dApp) that enables patients to:
- Securely store medical documents on IPFS (InterPlanetary File System)
- Record document metadata on blockchain for immutability and verification
- Share documents with healthcare providers using time-limited, PIN-protected links
- Track document access with comprehensive audit logs
- Maintain complete ownership and control over their health data

### Key Benefits
- **Decentralization**: Documents stored on IPFS, metadata on blockchain
- **Security**: End-to-end encryption, PIN protection, secure sharing
- **Transparency**: Immutable blockchain records, access logs
- **Privacy**: Patient-controlled access, time-limited shares
- **Portability**: Access documents anywhere, anytime

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   UI Layer   │  │  Providers   │  │   Services   │      │
│  │  (Screens)   │◄─┤  (State Mgmt)│◄─┤  (Business)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Firebase       │  │   IPFS Network   │  │   Blockchain     │
│   - Auth         │  │   - Pinata       │  │   - Polygon      │
│   - Firestore    │  │   - Web3.Storage │  │   - Mumbai       │
│   - Storage      │  │   - Self-hosted  │  │   - Sepolia      │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

### Data Flow

```
1. Document Upload Flow:
   User → Upload Screen → File Picker → IPFS Service → IPFS Network
                                              ↓
                                    Get CID (Content ID)
                                              ↓
                                    Blockchain Service
                                              ↓
                                    Smart Contract (Store)
                                              ↓
                                    Firebase Service
                                              ↓
                                    Firestore Database

2. Document Share Flow:
   User → Create Share → Generate PIN → Firebase (Share Record)
                              ↓
                        Generate QR Code
                              ↓
                    Receiver Scans QR → Request Access
                              ↓
                    Patient Approves → Unlock Document
                              ↓
                    Receiver Views → Access Log Created

3. Document Verification Flow:
   Document → Calculate Metadata Hash → Blockchain Service
                                              ↓
                                    Smart Contract (Verify)
                                              ↓
                                    Compare Hashes
                                              ↓
                                    Return Verification Status
```

---

## 🛠️ Technology Stack

### Frontend
- **Framework**: Flutter 3.9.2+ (Dart SDK)
- **State Management**: Provider Pattern
- **UI Components**: Material Design
- **Image Processing**: image_picker, cached_network_image
- **PDF Handling**: syncfusion_flutter_pdf, flutter_pdfview
- **QR Code**: qr_flutter, mobile_scanner
- **OCR**: google_mlkit_text_recognition

### Backend Services
- **Authentication**: Firebase Auth (Email/Password, Google Sign-In)
- **Database**: Cloud Firestore (NoSQL)
- **File Storage**: IPFS (Pinata, Web3.Storage)
- **Blockchain**: 
  - Ethereum/Polygon Networks
  - Web3Dart for blockchain interaction
  - Hardhat for smart contract development

### Smart Contract
- **Language**: Solidity ^0.8.28
- **Framework**: Hardhat
- **Testing**: Chai, Mocha
- **Networks**: Polygon Mumbai (testnet), Ethereum Sepolia (testnet)

### Security
- **Encryption**: SHA-256 hashing
- **PIN Protection**: Salted hash storage
- **Access Control**: Time-limited shares, PIN verification

---

## 📁 Project Structure

```
docpat2/
├── lib/
│   ├── main.dart                      # App entry point, Firebase initialization
│   ├── models/                        # Data models
│   │   ├── health_document.dart       # Document, ShareRecord, AccessLog models
│   │   └── share_record.dart          # Share record model (alternative)
│   ├── providers/                     # State management
│   │   ├── auth_provider.dart         # Authentication state
│   │   └── document_provider.dart     # Document state & filtering
│   ├── services/                      # Business logic layer
│   │   ├── blockchain_service.dart    # Web3 blockchain interactions
│   │   ├── ipfs_service.dart          # IPFS upload/retrieval
│   │   ├── firebase_service.dart      # Firestore CRUD operations
│   │   └── encryption_utils.dart      # Hashing & encryption utilities
│   └── screens/                       # UI screens
│       ├── auth/                      # Authentication screens
│       │   ├── auth_screen.dart       # Main auth wrapper
│       │   ├── login_screen.dart      # Login form
│       │   └── signin.dart            # Sign-in form
│       ├── home/                      # Home dashboard
│       │   └── home_screen.dart       # Main dashboard
│       ├── upload/                    # Document upload
│       │   └── upload_screen.dart     # Upload & metadata form
│       ├── document/                  # Document viewing
│       │   ├── document_detail_screen.dart  # Document details
│       │   ├── image_viewer_screen.dart     # Image viewer
│       │   └── pdf_viewer_screen.dart       # PDF viewer
│       ├── share/                     # Document sharing
│       │   ├── create_share_screen.dart     # Create share link
│       │   ├── share_view_screen.dart       # View shared document
│       │   ├── patient_approval_screen.dart # Approve access requests
│       │   ├── pending_requests_screen.dart # Pending requests list
│       │   └── sender_notifications_screen.dart # Share notifications
│       └── profile/                   # User profile
│           └── profile_screen.dart    # Profile & settings
├── contracts/                         # Smart contracts
│   └── HealthRecordRegistry.sol       # Main registry contract
├── scripts/                           # Deployment scripts
│   ├── deploy.js                      # Contract deployment
│   ├── deploy-and-test.js             # Deploy & test
│   └── test-contract.js               # Contract testing
├── test/                              # Test files
│   ├── HealthRecordRegistry.test.js   # Contract unit tests
│   └── widget_test.dart               # Flutter widget tests
├── hardhat.config.js                  # Hardhat configuration
├── pubspec.yaml                       # Flutter dependencies
├── package.json                       # Node.js dependencies
└── .env.example                       # Environment variables template
```

---

## ✨ Core Features

### 1. **User Authentication**
- Email/Password authentication
- Google Sign-In integration
- Automatic user profile creation in Firestore
- Session management with Firebase Auth

### 2. **Document Management**
- Upload medical documents (images, PDFs)
- OCR text extraction from images
- Document metadata (type, doctor, hospital, date, notes)
- Search and filter documents
- Sort by date or name
- Delete documents

### 3. **Blockchain Integration**
- Store document metadata hash on blockchain
- Immutable record of document existence
- Verify document integrity
- Track blockchain transaction hashes
- Support for multiple networks (Mumbai, Sepolia, Mainnet)

### 4. **IPFS Storage**
- Decentralized file storage
- Content-addressed storage (CID)
- Multiple IPFS providers (Pinata, Web3.Storage, self-hosted)
- File pinning for persistence
- Gateway access for retrieval

### 5. **Secure Sharing**
- Generate time-limited share links
- PIN-protected access
- QR code generation for easy sharing
- Access request workflow
- Patient approval required
- Automatic expiration

### 6. **Access Control & Audit**
- Comprehensive access logs
- Track who viewed documents
- Timestamp all access events
- View access history per document
- Reject access requests

### 7. **Document Verification**
- Verify document integrity via blockchain
- Compare metadata hashes
- Detect tampering or modifications
- Blockchain-based proof of authenticity

---

## 🔄 System Flow

### Complete Document Lifecycle

#### 1. **User Registration & Login**
```
User Opens App
    ↓
AuthWrapper checks Firebase Auth state
    ↓
If not authenticated → AuthScreen (Login/Signup)
    ↓
User enters credentials
    ↓
AuthProvider.signInWithEmailAndPassword()
    ↓
Firebase Auth validates
    ↓
User profile saved to Firestore
    ↓
Navigate to HomeScreen
```

#### 2. **Document Upload Process**
```
User clicks "Upload Document"
    ↓
UploadScreen opens
    ↓
User selects file (image/PDF)
    ↓
User fills metadata form:
    - Document Type (Prescription, Lab Report, etc.)
    - Doctor Name
    - Hospital Name
    - Document Date
    - Notes
    ↓
User clicks "Upload"
    ↓
IpfsService.uploadFile()
    ├─ Upload to Pinata/Web3.Storage
    └─ Returns IPFS CID
    ↓
EncryptionUtils.hashMetadata()
    └─ Generate SHA-256 hash of metadata
    ↓
BlockchainService.storeDocument()
    ├─ Connect to Web3 provider
    ├─ Call smart contract storeDocument()
    ├─ Wait for transaction confirmation
    └─ Returns transaction hash
    ↓
FirebaseService.saveDocument()
    ├─ Save to Firestore: users/{userId}/documents/{docId}
    └─ Store: CID, metadata hash, blockchain record ID, tx hash
    ↓
DocumentProvider.loadDocuments()
    └─ Refresh document list
    ↓
Success message → Navigate to HomeScreen
```

#### 3. **Document Sharing Workflow**
```
Patient selects document
    ↓
Clicks "Share Document"
    ↓
CreateShareScreen opens
    ↓
Patient sets:
    - Expiration time (1 hour, 24 hours, 7 days)
    - Optional PIN protection
    ↓
EncryptionUtils.generateShareId()
    └─ Generate unique 32-character share ID
    ↓
If PIN enabled:
    EncryptionUtils.generatePin(6)
    EncryptionUtils.hashPin(pin, salt)
    ↓
FirebaseService.createShareRecord()
    ├─ Save to Firestore: shares/{shareId}
    └─ Store: shareId, documentId, ownerId, ipfsCid, pin, expiresAt
    ↓
Generate QR Code with share link
    ↓
Patient shares QR code with receiver
    ↓
Receiver scans QR code
    ↓
ShareViewScreen opens with shareId
    ↓
Receiver clicks "Request Access"
    ↓
FirebaseService.updateShareRecord()
    └─ Set accessRequested = true
    ↓
Patient receives notification
    ↓
Patient opens PendingRequestsScreen
    ↓
Patient reviews request
    ↓
Patient approves:
    FirebaseService.updateShareRecord()
    └─ Set unlocked = true
    ↓
Receiver enters PIN (if required)
    ↓
EncryptionUtils.verifyPin()
    ↓
If valid:
    IpfsService.getFileUrl(cid)
    Display document
    ↓
    FirebaseService.logAccess()
    └─ Create access log entry
```

#### 4. **Document Verification**
```
User selects document
    ↓
DocumentDetailScreen opens
    ↓
User clicks "Verify on Blockchain"
    ↓
EncryptionUtils.hashMetadata()
    └─ Calculate current metadata hash
    ↓
BlockchainService.verifyDocument(recordId, hash)
    ├─ Call smart contract verifyDocument()
    └─ Compare stored hash with calculated hash
    ↓
Display verification result:
    ✓ Verified (hashes match)
    ✗ Modified (hashes don't match)
    ✗ Not found (record doesn't exist)
```

---

## 📜 Smart Contract

### HealthRecordRegistry.sol

**Purpose**: Immutable storage of health document metadata on blockchain

#### Contract Structure

```solidity
struct HealthRecord {
    string cid;              // IPFS Content Identifier
    string metadataHash;     // SHA256 hash of document metadata
    address owner;           // Document owner's wallet address
    uint256 timestamp;       // Block timestamp when record was created
    bool exists;             // Flag to check if record exists
    bool isActive;           // Flag for soft delete
}
```

#### Key Functions

##### 1. **storeDocument**
```solidity
function storeDocument(
    uint256 recordId,
    string memory cid,
    string memory metadataHash
) external whenNotPaused validRecordId(recordId) validInputs(cid, metadataHash)
```
- **Purpose**: Store new health document record
- **Access**: Public (any user)
- **Validations**:
  - Contract not paused
  - Record ID > 0
  - Record ID not already used
  - CID not empty, max 100 chars
  - Metadata hash exactly 64 chars (SHA-256)
- **Events**: Emits `DocumentStored`
- **State Changes**: 
  - Creates new HealthRecord
  - Increments totalRecords
  - Adds to userRecords mapping

##### 2. **getDocument**
```solidity
function getDocument(uint256 recordId) external view
    returns (
        string memory cid,
        string memory metadataHash,
        address owner,
        uint256 timestamp,
        bool isActive
    )
```
- **Purpose**: Retrieve document record information
- **Access**: Public view (read-only)
- **Returns**: All document details

##### 3. **getUserRecords**
```solidity
function getUserRecords(address user) external view
    returns (uint256[] memory)
```
- **Purpose**: Get all record IDs owned by a user
- **Access**: Public view
- **Returns**: Array of record IDs

##### 4. **getUserActiveRecords**
```solidity
function getUserActiveRecords(address user) external view
    returns (uint256[] memory)
```
- **Purpose**: Get only active (not deactivated) record IDs
- **Access**: Public view
- **Returns**: Array of active record IDs

##### 5. **verifyDocument**
```solidity
function verifyDocument(
    uint256 recordId,
    string memory expectedMetadataHash
) external view returns (bool)
```
- **Purpose**: Verify document integrity by comparing metadata hash
- **Access**: Public view
- **Returns**: true if hashes match, false otherwise

##### 6. **updateDocumentMetadata**
```solidity
function updateDocumentMetadata(
    uint256 recordId,
    string memory newMetadataHash
) external whenNotPaused onlyRecordOwner(recordId)
```
- **Purpose**: Update metadata hash for existing record
- **Access**: Only record owner
- **Events**: Emits `DocumentUpdated`

##### 7. **deactivateDocument**
```solidity
function deactivateDocument(uint256 recordId)
    external whenNotPaused onlyRecordOwner(recordId)
```
- **Purpose**: Soft delete a document record
- **Access**: Only record owner
- **Events**: Emits `DocumentDeactivated`

##### 8. **recordStatus**
```solidity
function recordStatus(uint256 recordId) external view
    returns (bool exists, bool isActive)
```
- **Purpose**: Check if record exists and is active
- **Access**: Public view

##### 9. **getUserRecordCount**
```solidity
function getUserRecordCount(address user) external view
    returns (uint256 total, uint256 active)
```
- **Purpose**: Get count of total and active records for a user
- **Access**: Public view

#### Admin Functions

##### 10. **pauseContract / unpauseContract**
```solidity
function pauseContract() external onlyOwner
function unpauseContract() external onlyOwner
```
- **Purpose**: Emergency pause/unpause contract operations
- **Access**: Only contract owner

##### 11. **transferOwnership**
```solidity
function transferOwnership(address newOwner) external onlyOwner
```
- **Purpose**: Transfer contract ownership
- **Access**: Only contract owner

##### 12. **getContractInfo**
```solidity
function getContractInfo() external view
    returns (
        uint256 totalRecords_,
        address contractOwner_,
        bool contractPaused_
    )
```
- **Purpose**: Get contract statistics
- **Access**: Public view

#### Events

```solidity
event DocumentStored(
    uint256 indexed recordId,
    address indexed owner,
    string cid,
    string metadataHash,
    uint256 timestamp
);

event DocumentUpdated(
    uint256 indexed recordId,
    address indexed owner,
    string newMetadataHash,
    uint256 timestamp
);

event DocumentDeactivated(
    uint256 indexed recordId,
    address indexed owner,
    uint256 timestamp
);

event ContractPaused(address indexed owner);
event ContractUnpaused(address indexed owner);
```

---

## 🔧 Services & Components

### 1. BlockchainService (`blockchain_service.dart`)

**Purpose**: Interface between Flutter app and Ethereum blockchain

#### Key Methods

##### `initialize()`
```dart
Future<bool> initialize() async
```
- Initializes Web3 client with RPC URL
- Loads private key credentials
- Loads smart contract ABI and address
- Tests connection by calling contract view function
- **Returns**: true if successful

##### `storeDocument(recordId, cid, metadataHash)`
```dart
Future<String?> storeDocument(int recordId, String cid, String metadataHash) async
```
- Estimates gas required for transaction
- Calls smart contract `storeDocument` function
- Waits for transaction confirmation (max 30 seconds)
- **Returns**: Transaction hash or null

##### `getDocument(recordId)`
```dart
Future<Map<String, dynamic>?> getDocument(int recordId) async
```
- Calls smart contract `getDocument` view function
- **Returns**: Map with cid, metadataHash, owner, timestamp, isActive

##### `getUserRecords(userAddress)`
```dart
Future<List<int>?> getUserRecords(String userAddress) async
```
- Retrieves all record IDs for a user address
- **Returns**: List of record IDs

##### `verifyDocument(recordId, expectedMetadataHash)`
```dart
Future<bool?> verifyDocument(int recordId, String expectedMetadataHash) async
```
- Calls smart contract verification function
- **Returns**: true if verified, false if tampered

##### Utility Methods
- `getBalance([address])` - Get wallet balance
- `getGasPrice()` - Get current gas price
- `getNetworkId()` - Get network chain ID
- `getBlockNumber()` - Get current block number
- `formatEther(amount)` - Format Wei to Ether
- `parseEther(etherString)` - Parse Ether to Wei

#### Properties
- `walletAddress` - Current wallet address
- `contractAddress` - Deployed contract address
- `chainId` - Network chain ID
- `networkName` - Human-readable network name
- `isInitialized` - Initialization status

---

### 2. IpfsService (`ipfs_service.dart`)

**Purpose**: Upload and retrieve files from IPFS network

#### Key Methods

##### `uploadFile(file, fileName)`
```dart
Future<String?> uploadFile(File file, String fileName) async
```
- Tries Pinata API first (if credentials available)
- Falls back to self-hosted IPFS node
- Adds metadata (type, upload timestamp)
- **Returns**: IPFS CID (Content Identifier)

##### `_uploadToPinata(file, fileName)` (Private)
```dart
Future<String?> _uploadToPinata(File file, String fileName) async
```
- Uploads to Pinata IPFS service
- Uses multipart form data
- Includes pinata metadata
- **Returns**: IPFS hash

##### `_uploadToSelfHostedNode(file, fileName)` (Private)
```dart
Future<String?> _uploadToSelfHostedNode(File file, String fileName) async
```
- Uploads to local IPFS node (http://localhost:5001)
- **Returns**: IPFS hash

##### `getFileUrl(cid)`
```dart
String getFileUrl(String cid)
```
- Constructs IPFS gateway URL
- **Returns**: Full URL to access file

##### `pinFile(cid)`
```dart
Future<bool> pinFile(String cid) async
```
- Pins file to ensure persistence
- **Returns**: true if successful

#### Configuration
- Supports Pinata (free tier: 1GB storage, 100GB bandwidth/month)
- Supports Web3.Storage
- Supports self-hosted IPFS nodes
- Configurable gateway URL

---

### 3. FirebaseService (`firebase_service.dart`)

**Purpose**: Firestore database operations for documents, shares, and logs

#### Document Methods

##### `getUserDocuments(userId)`
```dart
Future<List<HealthDocument>> getUserDocuments(String userId) async
```
- Retrieves all documents for a user
- Orders by createdAt descending
- **Returns**: List of HealthDocument objects

##### `getDocument(userId, documentId)`
```dart
Future<HealthDocument?> getDocument(String userId, String documentId) async
```
- Retrieves single document
- **Returns**: HealthDocument or null

##### `saveDocument(userId, document)`
```dart
Future<String> saveDocument(String userId, HealthDocument document) async
```
- Saves new document to Firestore
- Path: `users/{userId}/documents/{docId}`
- **Returns**: Document ID

##### `updateDocument(userId, documentId, updates)`
```dart
Future<void> updateDocument(String userId, String documentId, Map<String, dynamic> updates) async
```
- Updates existing document fields

##### `deleteDocument(documentId, userId)`
```dart
Future<void> deleteDocument(String documentId, String userId) async
```
- Deletes document from Firestore

#### Share Record Methods

##### `createShareRecord(shareRecord)`
```dart
Future<String> createShareRecord(ShareRecord shareRecord) async
```
- Creates new share record
- Path: `shares/{shareId}`
- **Returns**: Share record ID

##### `getShareRecord(shareId)`
```dart
Future<ShareRecord?> getShareRecord(String shareId) async
```
- Retrieves share record by shareId
- Filters: active = true
- **Returns**: ShareRecord or null

##### `getUserActiveShares(userId)`
```dart
Future<List<ShareRecord>> getUserActiveShares(String userId) async
```
- Gets all active shares for a user
- Filters: ownerId = userId, active = true
- Orders by createdAt descending

##### `updateShareRecord(shareId, updates)`
```dart
Future<void> updateShareRecord(String shareId, Map<String, dynamic> updates) async
```
- Updates share record fields

##### `deactivateShare(shareId)`
```dart
Future<void> deactivateShare(String shareId) async
```
- Sets active = false

#### Access Log Methods

##### `logAccess(accessLog)`
```dart
Future<void> logAccess(AccessLog accessLog) async
```
- Creates access log entry
- Path: `access_logs/{logId}`

##### `getDocumentAccessLogs(documentId)`
```dart
Future<List<AccessLog>> getDocumentAccessLogs(String documentId) async
```
- Retrieves all access logs for a document
- Orders by accessedAt descending

##### `getUserAccessLogs(userId)`
```dart
Future<List<AccessLog>> getUserAccessLogs(String userId) async
```
- Gets access logs for all user's documents
- Limit: 50 most recent

##### `logDocumentAccess(documentId, viewerId, viewerName, {shareId, action})`
```dart
Future<void> logDocumentAccess(String documentId, String viewerId, String viewerName, {String shareId = '', String action = 'viewed'}) async
```
- Convenience method to log document access

#### User PIN Methods

##### `getUserPermanentPin(userId)`
```dart
Future<String?> getUserPermanentPin(String userId) async
```
- Retrieves user's permanent PIN hash

##### `setUserPermanentPin(userId, pinHash)`
```dart
Future<void> setUserPermanentPin(String userId, String pinHash) async
```
- Stores user's permanent PIN hash

---

### 4. EncryptionUtils (`encryption_utils.dart`)

**Purpose**: Cryptographic utilities for hashing and security

#### Methods

##### `hashPin(pin, salt)`
```dart
static String hashPin(String pin, String salt)
```
- Hashes PIN using SHA-256 with salt
- **Returns**: Hex string hash

##### `generateSalt()`
```dart
static String generateSalt()
```
- Generates random 16-byte salt
- **Returns**: Base64 encoded salt

##### `hashMetadata(metadata)`
```dart
static String hashMetadata(Map<String, dynamic> metadata)
```
- Hashes document metadata using SHA-256
- Converts metadata to JSON first
- **Returns**: Hex string hash (64 characters)

##### `generateShareId()`
```dart
static String generateShareId()
```
- Generates secure random 32-character alphanumeric string
- **Returns**: Share ID

##### `verifyPin(pin, hash, salt)`
```dart
static bool verifyPin(String pin, String hash, String salt)
```
- Verifies PIN against stored hash
- **Returns**: true if match

##### `generatePin(length)`
```dart
static String generatePin(int length)
```
- Generates random numeric PIN
- **Returns**: PIN string

---

### 5. AuthProvider (`auth_provider.dart`)

**Purpose**: Authentication state management using Provider pattern

#### Properties
- `userId` - Current user ID
- `user` - Firebase User object
- `isAuthenticated` - Authentication status
- `isLoading` - Loading state
- `error` - Error message

#### Methods

##### `signInWithEmailAndPassword(email, password)`
```dart
Future<void> signInWithEmailAndPassword(String email, String password) async
```
- Signs in user with Firebase Auth
- Saves/updates user in Firestore
- Notifies listeners on state change

##### `createUserWithEmailAndPassword(email, password)`
```dart
Future<void> createUserWithEmailAndPassword(String email, String password) async
```
- Creates new user account
- Saves user profile to Firestore
- Notifies listeners

##### `signOut()`
```dart
Future<void> signOut() async
```
- Signs out current user
- Clears user state
- Notifies listeners

##### `clearError()`
```dart
void clearError()
```
- Clears error state

#### Private Methods
- `_initializeAuth()` - Initializes auth state listener
- `_updateAuthState(user)` - Updates auth state
- `_saveUserToFirestore(user)` - Saves user profile
- `_getErrorMessage(error)` - Formats error messages

---

### 6. DocumentProvider (`document_provider.dart`)

**Purpose**: Document list state management and filtering

#### Properties
- `documents` - Filtered document list
- `isLoading` - Loading state
- `searchQuery` - Current search query
- `selectedType` - Selected document type filter
- `sortBy` - Current sort order

#### Methods

##### `loadDocuments(userId)`
```dart
Future<void> loadDocuments(String userId) async
```
- Loads all documents for user
- Notifies listeners

##### `setSearchQuery(query)`
```dart
void setSearchQuery(String query)
```
- Updates search filter
- Notifies listeners

##### `setTypeFilter(type)`
```dart
void setTypeFilter(String type)
```
- Updates document type filter
- Notifies listeners

##### `setSortBy(sortBy)`
```dart
void setSortBy(String sortBy)
```
- Updates sort order
- Options: date_desc, date_asc, name_asc, name_desc

##### `deleteDocument(documentId, userId)`
```dart
Future<bool> deleteDocument(String documentId, String userId) async
```
- Deletes document
- Updates local state
- **Returns**: true if successful

#### Private Methods
- `_getFilteredDocuments()` - Applies filters and sorting

---

## 📊 Data Models

### 1. HealthDocument

```dart
class HealthDocument {
  final String id;
  final String fileName;
  final String fileType;           // 'image' or 'pdf'
  final String ipfsCid;             // IPFS Content ID
  final String documentType;        // Prescription, Lab Report, etc.
  final String doctorName;
  final String hospitalName;
  final DateTime documentDate;
  final String notes;
  final String metadataHash;        // SHA-256 hash
  final DateTime createdAt;
  final int? blockchainRecordId;
  final String? transactionHash;
}
```

**Methods**:
- `fromFirestore(doc)` - Create from Firestore document
- `toFirestore()` - Convert to Firestore map
- `getMetadataForHashing()` - Get metadata for hash calculation

---

### 2. ShareRecord

```dart
class ShareRecord {
  final String id;
  final String shareId;             // Unique share identifier
  final String documentId;
  final String ownerId;
  final String? receiverId;
  final String? receiverName;
  final String ipfsCid;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;
  final bool unlocked;              // Patient unlocked for receiver
  final bool accessRequested;       // Receiver requested access
  final String? pin;                // Hashed PIN
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final DateTime? accessedAt;
  final String status;              // 'pending', 'accessed', 'rejected', 'expired'
}
```

**Methods**:
- `fromFirestore(doc)` - Create from Firestore document
- `toFirestore()` - Convert to Firestore map
- `copyWith({...})` - Create copy with updated fields

---

### 3. AccessLog

```dart
class AccessLog {
  final String id;
  final String shareId;
  final String documentId;
  final String? viewerId;
  final String? viewerName;
  final String? viewerIp;
  final DateTime accessedAt;
  final String action;              // 'viewed', 'downloaded', 'rejected'
}
```

**Methods**:
- `fromFirestore(doc)` - Create from Firestore document
- `toFirestore()` - Convert to Firestore map

---

## 🖥️ Screens & UI

### Authentication Screens

#### 1. **AuthScreen** (`auth_screen.dart`)
- Main authentication wrapper
- Switches between login and signup
- Google Sign-In button
- Email/Password forms

#### 2. **LoginScreen** (`login_screen.dart`)
- Email/Password login form
- Form validation
- Error handling
- Navigate to signup

---

### Home & Dashboard

#### 3. **HomeScreen** (`home_screen.dart`)
- Document list view
- Search bar
- Filter by document type
- Sort options
- Quick actions (Upload, Share, Profile)
- Document cards with preview
- Pull-to-refresh

---

### Document Management

#### 4. **UploadScreen** (`upload_screen.dart`)
- File picker (image/PDF)
- OCR text extraction for images
- Metadata form:
  - Document type dropdown
  - Doctor name
  - Hospital name
  - Document date picker
  - Notes textarea
- Upload progress indicator
- Blockchain transaction status

#### 5. **DocumentDetailScreen** (`document_detail_screen.dart`)
- Document metadata display
- File preview
- Actions:
  - View full document
  - Share document
  - Verify on blockchain
  - Delete document
- Access history
- Share history
- Blockchain info (record ID, tx hash)

#### 6. **ImageViewerScreen** (`image_viewer_screen.dart`)
- Full-screen image viewer
- Zoom and pan
- Download option

#### 7. **PdfViewerScreen** (`pdf_viewer_screen.dart`)
- PDF document viewer
- Page navigation
- Zoom controls

---

### Sharing Screens

#### 8. **CreateShareScreen** (`create_share_screen.dart`)
- Expiration time selector (1h, 24h, 7d, custom)
- PIN protection toggle
- PIN generation/input
- Generate QR code
- Copy share link
- Share via other apps

#### 9. **ShareViewScreen** (`share_view_screen.dart`)
- View shared document (receiver side)
- Request access button
- PIN entry (if required)
- Document preview after approval
- Access denied message
- Expiration status

#### 10. **PatientApprovalScreen** (`patient_approval_screen.dart`)
- Pending access requests list
- Request details (receiver info, document, time)
- Approve/Reject buttons
- Notification badges

#### 11. **PendingRequestsScreen** (`pending_requests_screen.dart`)
- List of all pending share requests
- Filter by status
- Quick approve/reject actions

#### 12. **SenderNotificationsScreen** (`sender_notifications_screen.dart`)
- Share activity notifications
- Access logs
- Share status updates

---

### Profile

#### 13. **ProfileScreen** (`profile_screen.dart`)
- User information
- Account settings
- Blockchain wallet info
- Network status
- Logout button
- App version

---

## 🚀 Setup & Installation

### Prerequisites

1. **Flutter SDK** (3.9.2 or higher)
   ```bash
   flutter --version
   ```

2. **Node.js** (v16 or higher) for Hardhat
   ```bash
   node --version
   npm --version
   ```

3. **Firebase Project**
   - Create project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password, Google)
   - Create Firestore database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

4. **IPFS Provider Account**
   - [Pinata](https://pinata.cloud/) - Free tier available
   - OR [Web3.Storage](https://web3.storage/)
   - OR self-hosted IPFS node

5. **Blockchain Network Access**
   - [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/) account for RPC URL
   - Testnet wallet with test tokens (Mumbai MATIC or Sepolia ETH)

### Installation Steps

#### 1. Clone Repository
```bash
git clone <repository-url>
cd docpat2
```

#### 2. Install Flutter Dependencies
```bash
flutter pub get
```

#### 3. Install Node.js Dependencies
```bash
npm install
```

#### 4. Configure Firebase
- Place `google-services.json` in `android/app/`
- Place `GoogleService-Info.plist` in `ios/Runner/`
- Update Firebase configuration in code if needed

#### 5. Set Up Environment Variables
```bash
cp .env.example .env
```

Edit `.env` file with your credentials:
```env
# Blockchain Configuration
RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/YOUR_API_KEY
CONTRACT_ADDRESS=0xYourDeployedContractAddress
PRIVATE_KEY=your_wallet_private_key
CHAIN_ID=80001

# IPFS Configuration
IPFS_GATEWAY=https://gateway.pinata.cloud/ipfs/
PINATA_API_KEY=your_pinata_api_key
PINATA_SECRET_KEY=your_pinata_secret_key

# Firebase (optional, if not using google-services.json)
FIREBASE_PROJECT_ID=your_firebase_project_id
```

#### 6. Deploy Smart Contract

**Compile Contract**:
```bash
npx hardhat compile
```

**Deploy to Mumbai Testnet**:
```bash
npx hardhat run scripts/deploy.js --network mumbai
```

**Copy Contract Address** to `.env` file

#### 7. Run Application

**Android**:
```bash
flutter run -d android
```

**iOS**:
```bash
flutter run -d ios
```

**Web**:
```bash
flutter run -d chrome
```

---

## ⚙️ Environment Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RPC_URL` | Blockchain RPC endpoint | `https://polygon-mumbai.g.alchemy.com/v2/API_KEY` |
| `CONTRACT_ADDRESS` | Deployed contract address | `0x1234...5678` |
| `PRIVATE_KEY` | Wallet private key (NEVER commit!) | `0xabc...def` |
| `CHAIN_ID` | Network chain ID | `80001` (Mumbai) |
| `IPFS_GATEWAY` | IPFS gateway URL | `https://gateway.pinata.cloud/ipfs/` |
| `PINATA_API_KEY` | Pinata API key | `your_api_key` |
| `PINATA_SECRET_KEY` | Pinata secret key | `your_secret_key` |

### Network Chain IDs

| Network | Chain ID |
|---------|----------|
| Ethereum Mainnet | 1 |
| Ethereum Sepolia | 11155111 |
| Polygon Mainnet | 137 |
| Polygon Mumbai | 80001 |
| Hardhat Local | 31337 |

---

## 📦 Deployment

### Smart Contract Deployment

#### Deploy to Mumbai Testnet
```bash
npx hardhat run scripts/deploy.js --network mumbai
```

#### Deploy to Sepolia Testnet
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

#### Verify Contract on Polygonscan
```bash
npx hardhat verify --network mumbai DEPLOYED_CONTRACT_ADDRESS
```

### Flutter App Deployment

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

---

## 🧪 Testing

### Smart Contract Tests

**Run All Tests**:
```bash
npx hardhat test
```

**Run Specific Test**:
```bash
npx hardhat test test/HealthRecordRegistry.test.js
```

**Test Coverage**:
```bash
npx hardhat coverage
```

### Test Cases Covered

1. **Deployment**
   - Contract owner set correctly
   - Initial state (zero records, unpaused)

2. **Document Storage**
   - Successful document storage
   - Validation (empty CID, invalid hash, duplicate ID)
   - Event emission

3. **Document Retrieval**
   - Get document by ID
   - Get user records
   - Get active records
   - Non-existent record handling

4. **Document Management**
   - Update metadata
   - Deactivate document
   - Owner-only access control

5. **Document Verification**
   - Verify correct hash
   - Reject incorrect hash
   - Non-existent record handling

6. **Admin Functions**
   - Pause/unpause contract
   - Transfer ownership
   - Access control

### Flutter Widget Tests

```bash
flutter test
```

---

## 🔒 Security Features

### 1. **Data Encryption**
- SHA-256 hashing for metadata
- Salted PIN hashing
- Secure random generation

### 2. **Access Control**
- Firebase Auth for user authentication
- Owner-only document operations
- Time-limited share links
- PIN-protected shares
- Access request approval workflow

### 3. **Blockchain Security**
- Immutable record storage
- Smart contract access modifiers
- Input validation
- Reentrancy protection
- Pausable contract

### 4. **Privacy**
- Documents stored on decentralized IPFS
- Only metadata hash on blockchain
- Patient-controlled sharing
- Comprehensive audit logs
- Soft delete (deactivation)

### 5. **Best Practices**
- Environment variables for secrets
- Never commit private keys
- HTTPS for all API calls
- Input sanitization
- Error handling

---

## 📚 API Reference

### Blockchain Service API

```dart
// Initialize service
await blockchainService.initialize();

// Store document
String? txHash = await blockchainService.storeDocument(
  recordId: 12345,
  cid: 'QmXxx...',
  metadataHash: 'abc123...'
);

// Get document
Map<String, dynamic>? doc = await blockchainService.getDocument(12345);

// Verify document
bool? isValid = await blockchainService.verifyDocument(
  12345,
  'abc123...'
);

// Get user records
List<int>? recordIds = await blockchainService.getUserRecords(
  '0x1234...'
);
```

### IPFS Service API

```dart
// Upload file
String? cid = await ipfsService.uploadFile(
  file,
  'document.pdf'
);

// Get file URL
String url = ipfsService.getFileUrl('QmXxx...');

// Pin file
bool success = await ipfsService.pinFile('QmXxx...');
```

### Firebase Service API

```dart
// Save document
String docId = await firebaseService.saveDocument(
  userId,
  healthDocument
);

// Get documents
List<HealthDocument> docs = await firebaseService.getUserDocuments(
  userId
);

// Create share
String shareId = await firebaseService.createShareRecord(
  shareRecord
);

// Log access
await firebaseService.logAccess(accessLog);
```

---

## 📝 License

This project is licensed under the MIT License.

---

## 👥 Contributors

Health Record Wallet Team

---

## 📞 Support

For issues and questions:
- GitHub Issues: [Project Issues]
- Email: support@healthrecordwallet.com

---

## 🗺️ Roadmap

### Future Features
- [ ] Multi-signature document approval
- [ ] Integration with healthcare provider systems
- [ ] AI-powered document categorization
- [ ] Telemedicine integration
- [ ] Insurance claim automation
- [ ] Cross-chain support
- [ ] Mobile biometric authentication
- [ ] Offline document access
- [ ] Document templates
- [ ] Batch document upload

---

## 📖 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Web3Dart Documentation](https://pub.dev/packages/web3dart)
- [Hardhat Documentation](https://hardhat.org/docs)
- [IPFS Documentation](https://docs.ipfs.tech/)
- [Solidity Documentation](https://docs.soliditylang.org/)

---

**Built with ❤️ for better healthcare data management**
