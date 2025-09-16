import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class BlockchainService {
  Web3Client? _client;
  EthPrivateKey? _credentials;
  DeployedContract? _contract;
  ContractFunction? _storeDocumentFunction;
  ContractFunction? _getDocumentFunction;
  ContractFunction? _getUserRecordsFunction;
  ContractFunction? _verifyDocumentFunction;
  ContractFunction? _getContractInfoFunction;
  
  String get _rpcUrl => dotenv.env['RPC_URL'] ?? 'https://polygon-mumbai.g.alchemy.com/v2/demo';
  String get _contractAddress => dotenv.env['CONTRACT_ADDRESS'] ?? '';
  String get _privateKey => dotenv.env['PRIVATE_KEY'] ?? '';
  int get _chainId => int.parse(dotenv.env['CHAIN_ID'] ?? '80001');

  // Updated ABI for the enhanced HealthRecordRegistry contract
  static const String contractAbi = '''
  [
    {
      "inputs": [
        {"internalType": "uint256", "name": "recordId", "type": "uint256"},
        {"internalType": "string", "name": "cid", "type": "string"},
        {"internalType": "string", "name": "metadataHash", "type": "string"}
      ],
      "name": "storeDocument",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "recordId", "type": "uint256"}],
      "name": "getDocument",
      "outputs": [
        {"internalType": "string", "name": "cid", "type": "string"},
        {"internalType": "string", "name": "metadataHash", "type": "string"},
        {"internalType": "address", "name": "owner", "type": "address"},
        {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
        {"internalType": "bool", "name": "isActive", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
      "name": "getUserRecords",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
      "name": "getUserActiveRecords",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "recordId", "type": "uint256"},
        {"internalType": "string", "name": "expectedMetadataHash", "type": "string"}
      ],
      "name": "verifyDocument",
      "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getContractInfo",
      "outputs": [
        {"internalType": "uint256", "name": "totalRecords_", "type": "uint256"},
        {"internalType": "address", "name": "contractOwner_", "type": "address"},
        {"internalType": "bool", "name": "contractPaused_", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
      "name": "getUserRecordCount",
      "outputs": [
        {"internalType": "uint256", "name": "total", "type": "uint256"},
        {"internalType": "uint256", "name": "active", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "anonymous": false,
      "inputs": [
        {"indexed": true, "internalType": "uint256", "name": "recordId", "type": "uint256"},
        {"indexed": true, "internalType": "address", "name": "owner", "type": "address"},
        {"indexed": false, "internalType": "string", "name": "cid", "type": "string"},
        {"indexed": false, "internalType": "string", "name": "metadataHash", "type": "string"},
        {"indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256"}
      ],
      "name": "DocumentStored",
      "type": "event"
    }
  ]
  ''';

  bool get isInitialized => _client != null && _contract != null;

  Future<bool> initialize() async {
    try {
      // Allow initialization without private key for read-only operations
      if (_rpcUrl.isEmpty) {
        debugPrint('Missing RPC_URL in .env file');
        return false;
      }

      _client = Web3Client(_rpcUrl, Client());
      
      // Only initialize credentials if private key is provided
      if (_privateKey.isNotEmpty) {
        _credentials = EthPrivateKey.fromHex(_privateKey);
      }
      
      // Only initialize contract if address is provided
      if (_contractAddress.isNotEmpty) {
        _contract = DeployedContract(
          ContractAbi.fromJson(contractAbi, 'HealthRecordRegistry'),
          EthereumAddress.fromHex(_contractAddress),
        );
        
        _storeDocumentFunction = _contract!.function('storeDocument');
        _getDocumentFunction = _contract!.function('getDocument');
        _getUserRecordsFunction = _contract!.function('getUserRecords');
        _verifyDocumentFunction = _contract!.function('verifyDocument');
        _getContractInfoFunction = _contract!.function('getContractInfo');

        // Test connection by calling a view function
        try {
          await getContractInfo();
        } catch (e) {
          debugPrint('Contract connection test failed: $e');
          // Continue initialization even if contract test fails
        }
      }
      
      debugPrint('Blockchain service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Blockchain initialization error: $e');
      return false;
    }
  }

  Future<String?> storeDocument(int recordId, String cid, String metadataHash) async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      // Check if we have enough gas
      final gasPrice = await _client!.getGasPrice();
      final estimatedGas = await _client!.estimateGas(
        sender: _credentials!.address,
        to: _contract!.address,
        data: _storeDocumentFunction!.encodeCall([
          BigInt.from(recordId),
          cid,
          metadataHash,
        ]),
      );

      debugPrint('Estimated gas: $estimatedGas');
      debugPrint('Gas price: ${gasPrice.getInWei} wei');

      final transaction = Transaction.callContract(
        contract: _contract!,
        function: _storeDocumentFunction!,
        parameters: [BigInt.from(recordId), cid, metadataHash],
        from: _credentials!.address,
        gasPrice: gasPrice,
        maxGas: estimatedGas.toInt() + 50000, // Add buffer
      );

      final result = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: _chainId,
      );

      debugPrint('Transaction sent: $result');
      
      // Wait for transaction confirmation
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 30; // 30 seconds timeout
      
      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        receipt = await _client!.getTransactionReceipt(result);
        attempts++;
      }

      if (receipt != null) {
        debugPrint('Transaction confirmed in block: ${receipt.blockNumber}');
        debugPrint('Gas used: ${receipt.gasUsed}');
        return result;
      } else {
        debugPrint('Transaction timeout - check manually: $result');
        return result; // Return hash even if we couldn't confirm
      }

    } catch (e) {
      debugPrint('Blockchain store error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDocument(int recordId) async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }
      
      final result = await _client!.call(
        contract: _contract!,
        function: _getDocumentFunction!,
        params: [BigInt.from(recordId)],
      );

      return {
        'cid': result[0] as String,
        'metadataHash': result[1] as String,
        'owner': (result[2] as EthereumAddress).hex,
        'timestamp': (result[3] as BigInt).toInt(),
        'isActive': result[4] as bool,
      };
    } catch (e) {
      debugPrint('Blockchain get document error: $e');
      return null;
    }
  }

  Future<List<int>?> getUserRecords(String userAddress) async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }
      
      final result = await _client!.call(
        contract: _contract!,
        function: _getUserRecordsFunction!,
        params: [EthereumAddress.fromHex(userAddress)],
      );

      final List<BigInt> recordIds = result[0] as List<BigInt>;
      return recordIds.map((id) => id.toInt()).toList();
    } catch (e) {
      debugPrint('Blockchain get user records error: $e');
      return null;
    }
  }

  Future<bool?> verifyDocument(int recordId, String expectedMetadataHash) async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }
      
      final result = await _client!.call(
        contract: _contract!,
        function: _verifyDocumentFunction!,
        params: [BigInt.from(recordId), expectedMetadataHash],
      );

      return result[0] as bool;
    } catch (e) {
      debugPrint('Blockchain verify document error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getContractInfo() async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }
      
      final result = await _client!.call(
        contract: _contract!,
        function: _getContractInfoFunction!,
        params: [],
      );

      return {
        'totalRecords': (result[0] as BigInt).toInt(),
        'contractOwner': (result[1] as EthereumAddress).hex,
        'contractPaused': result[2] as bool,
      };
    } catch (e) {
      debugPrint('Blockchain get contract info error: $e');
      return null;
    }
  }

  Future<EtherAmount?> getBalance([String? address]) async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      EthereumAddress targetAddress;
      if (address != null) {
        targetAddress = EthereumAddress.fromHex(address);
      } else {
        targetAddress = _credentials!.address;
      }

      return await _client!.getBalance(targetAddress);
    } catch (e) {
      debugPrint('Blockchain get balance error: $e');
      return null;
    }
  }

  Future<EtherAmount?> getGasPrice() async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      return await _client!.getGasPrice();
    } catch (e) {
      debugPrint('Get gas price error: $e');
      return null;
    }
  }

  Future<int?> getNetworkId() async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      return await _client!.getNetworkId();
    } catch (e) {
      debugPrint('Get network ID error: $e');
      return null;
    }
  }

  Future<int?> getBlockNumber() async {
    try {
      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      final blockNumber = await _client!.getBlockNumber();
      return blockNumber;
    } catch (e) {
      debugPrint('Get block number error: $e');
      return null;
    }
  }

  String get walletAddress => _credentials?.address.hex ?? '';

  String get contractAddress => _contractAddress;

  int get chainId => _chainId;

  String get networkName {
    switch (_chainId) {
      case 1:
        return 'Ethereum Mainnet';
      case 137:
        return 'Polygon Mainnet';
      case 80001:
        return 'Polygon Mumbai';
      case 11155111:
        return 'Ethereum Sepolia';
      default:
        return 'Unknown Network ($_chainId)';
    }
  }

  void dispose() {
    _client?.dispose();
    _client = null;
    _contract = null;
    _credentials = null;
  }

  // Utility method to format Wei to Ether
  static String formatEther(EtherAmount amount, [int decimals = 4]) {
    final etherValue = amount.getValueInUnit(EtherUnit.ether);
    return etherValue.toStringAsFixed(decimals);
  }

  // Utility method to convert Ether to Wei
  static EtherAmount parseEther(String etherString) {
    final double etherValue = double.parse(etherString);
    return EtherAmount.fromUnitAndValue(EtherUnit.ether, etherValue);
  }
}