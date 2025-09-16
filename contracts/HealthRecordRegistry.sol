// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title HealthRecordRegistry
 * @dev Smart contract for storing health document records on blockchain
 * @author Health Record Wallet Team
 */
contract HealthRecordRegistry {
    
    // Structure to store health record information
    struct HealthRecord {
        string cid;           // IPFS Content Identifier
        string metadataHash;  // SHA256 hash of document metadata
        address owner;        // Document owner's wallet address
        uint256 timestamp;    // Block timestamp when record was created
        bool exists;          // Flag to check if record exists
        bool isActive;        // Flag to mark if record is active (for soft delete)
    }
    
    // Mapping from record ID to HealthRecord
    mapping(uint256 => HealthRecord) public records;
    
    // Mapping from owner address to array of their record IDs
    mapping(address => uint256[]) public userRecords;
    
    // Mapping to track if a record ID is already used
    mapping(uint256 => bool) public recordExists;
    
    // Contract state variables
    uint256 public totalRecords;
    address public contractOwner;
    bool public contractPaused;
    
    // Events
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
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this");
        _;
    }
    
    modifier onlyRecordOwner(uint256 recordId) {
        require(recordExists[recordId], "Record does not exist");
        require(records[recordId].owner == msg.sender, "Not record owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }
    
    modifier validRecordId(uint256 recordId) {
        require(recordId > 0, "Record ID must be greater than 0");
        _;
    }
    
    modifier validInputs(string memory cid, string memory metadataHash) {
        require(bytes(cid).length > 0, "CID cannot be empty");
        require(bytes(metadataHash).length > 0, "Metadata hash cannot be empty");
        require(bytes(cid).length <= 100, "CID too long");
        require(bytes(metadataHash).length == 64, "Invalid metadata hash length");
        _;
    }
    
    // Constructor
    constructor() {
        contractOwner = msg.sender;
        contractPaused = false;
        totalRecords = 0;
    }
    
    /**
     * @dev Store a new health document record
     * @param recordId Unique identifier for the record
     * @param cid IPFS Content Identifier
     * @param metadataHash SHA256 hash of document metadata
     */
    function storeDocument(
        uint256 recordId,
        string memory cid,
        string memory metadataHash
    ) 
        external 
        whenNotPaused 
        validRecordId(recordId)
        validInputs(cid, metadataHash)
    {
        require(!recordExists[recordId], "Record ID already exists");
        
        // Create new health record
        records[recordId] = HealthRecord({
            cid: cid,
            metadataHash: metadataHash,
            owner: msg.sender,
            timestamp: block.timestamp,
            exists: true,
            isActive: true
        });
        
        // Mark record as existing and add to user's records
        recordExists[recordId] = true;
        userRecords[msg.sender].push(recordId);
        totalRecords++;
        
        emit DocumentStored(recordId, msg.sender, cid, metadataHash, block.timestamp);
    }
    
    /**
     * @dev Get document record information
     * @param recordId The record ID to retrieve
     * @return cid IPFS Content Identifier
     * @return metadataHash SHA256 hash of metadata
     * @return owner Address of the record owner
     * @return timestamp When the record was created
     * @return isActive Whether the record is active
     */
    function getDocument(uint256 recordId) 
        external 
        view 
        validRecordId(recordId)
        returns (
            string memory cid,
            string memory metadataHash,
            address owner,
            uint256 timestamp,
            bool isActive
        ) 
    {
        require(recordExists[recordId], "Record does not exist");
        HealthRecord memory record = records[recordId];
        
        return (
            record.cid,
            record.metadataHash,
            record.owner,
            record.timestamp,
            record.isActive
        );
    }
    
    /**
     * @dev Get all record IDs owned by a specific user
     * @param user Address of the user
     * @return Array of record IDs owned by the user
     */
    function getUserRecords(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userRecords[user];
    }
    
    /**
     * @dev Get active record IDs owned by a specific user
     * @param user Address of the user
     * @return Array of active record IDs owned by the user
     */
    function getUserActiveRecords(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory allRecords = userRecords[user];
        uint256 activeCount = 0;
        
        // Count active records
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (records[allRecords[i]].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active records
        uint256[] memory activeRecords = new uint256[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (records[allRecords[i]].isActive) {
                activeRecords[currentIndex] = allRecords[i];
                currentIndex++;
            }
        }
        
        return activeRecords;
    }
    
    /**
     * @dev Update metadata hash for an existing record
     * @param recordId The record ID to update
     * @param newMetadataHash New SHA256 hash of updated metadata
     */
    function updateDocumentMetadata(
        uint256 recordId,
        string memory newMetadataHash
    ) 
        external 
        whenNotPaused 
        onlyRecordOwner(recordId)
    {
        require(bytes(newMetadataHash).length == 64, "Invalid metadata hash length");
        require(records[recordId].isActive, "Record is not active");
        
        records[recordId].metadataHash = newMetadataHash;
        
        emit DocumentUpdated(recordId, msg.sender, newMetadataHash, block.timestamp);
    }
    
    /**
     * @dev Deactivate a document record (soft delete)
     * @param recordId The record ID to deactivate
     */
    function deactivateDocument(uint256 recordId) 
        external 
        whenNotPaused 
        onlyRecordOwner(recordId)
    {
        require(records[recordId].isActive, "Record already inactive");
        
        records[recordId].isActive = false;
        
        emit DocumentDeactivated(recordId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Verify document integrity by comparing metadata hash
     * @param recordId The record ID to verify
     * @param expectedMetadataHash Expected metadata hash
     * @return True if metadata hash matches, false otherwise
     */
    function verifyDocument(
        uint256 recordId, 
        string memory expectedMetadataHash
    ) 
        external 
        view 
        validRecordId(recordId)
        returns (bool) 
    {
        if (!recordExists[recordId] || !records[recordId].isActive) {
            return false;
        }
        
        return keccak256(abi.encodePacked(records[recordId].metadataHash)) == 
               keccak256(abi.encodePacked(expectedMetadataHash));
    }
    
    /**
     * @dev Check if a record exists and is active
     * @param recordId The record ID to check
     * @return exists True if record exists
     * @return isActive True if record is active
     */
    function recordStatus(uint256 recordId) 
        external 
        view 
        returns (bool exists, bool isActive) 
    {
        if (!recordExists[recordId]) {
            return (false, false);
        }
        
        return (records[recordId].exists, records[recordId].isActive);
    }
    
    /**
     * @dev Get total number of records for a user
     * @param user Address of the user
     * @return total Total number of records
     * @return active Number of active records
     */
    function getUserRecordCount(address user) 
        external 
        view 
        returns (uint256 total, uint256 active) 
    {
        total = userRecords[user].length;
        active = 0;
        
        for (uint256 i = 0; i < total; i++) {
            if (records[userRecords[user][i]].isActive) {
                active++;
            }
        }
    }
    
    // Admin functions (only contract owner)
    
    /**
     * @dev Pause contract operations
     */
    function pauseContract() external onlyOwner {
        contractPaused = true;
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev Unpause contract operations
     */
    function unpauseContract() external onlyOwner {
        contractPaused = false;
        emit ContractUnpaused(msg.sender);
    }
    
    /**
     * @dev Transfer contract ownership
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        contractOwner = newOwner;
    }
    
    /**
     * @dev Get contract statistics
     * @return totalRecords_ Total number of records
     * @return contractOwner_ Contract owner address
     * @return contractPaused_ Contract pause status
     */
    function getContractInfo() 
        external 
        view 
        returns (
            uint256 totalRecords_,
            address contractOwner_,
            bool contractPaused_
        ) 
    {
        return (totalRecords, contractOwner, contractPaused);
    }
}