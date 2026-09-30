// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DigitalAsset {
    struct Asset {
        uint256 id;
        string assetType;
        string assetName;
        uint256 quantity;
        string metadataURI;
        address owner;
        bool isValid;
    }

    mapping(uint256 => Asset) public assets;
    mapping(address => uint256[]) public ownerAssets;
    mapping(address => bool) public admins;
    
    uint256 public assetCounter;
    address public superAdmin;

    // --- RECOVERY & IDENTITY STATE ---
    mapping(address => address) private _activeToOriginal;
    mapping(address => address) private _originalToActive;

    mapping(address => address[]) public guardians;
    mapping(address => mapping(address => bool)) public isGuardian;
    mapping(address => uint256) public recoveryThreshold;

    enum RecoveryStatus { None, Pending, Executed, Cancelled }

    struct RecoveryRequest {
        uint256 id;
        address identity;
        address proposedNewOwner;
        uint256 approvalCount;
        RecoveryStatus status;
    }

    mapping(uint256 => RecoveryRequest) public recoveryRequests;
    uint256 public recoveryCounter;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    mapping(address => uint256) public activeRecoveryId;

    // --- USER REGISTRY STATE ---
    struct UserProfile {
        address wallet;
        string profileURI;
        bool isRegistered;
    }
    mapping(address => UserProfile) public userProfiles;

    // --- EVENTS ---
    event AssetMinted(uint256 id, address owner, string assetType);
    event AssetRevoked(uint256 id);
    
    event GuardianAdded(address indexed identity, address guardian);
    event GuardianRemoved(address indexed identity, address guardian);
    event RecoveryThresholdChanged(address indexed identity, uint256 threshold);
    event RecoveryRequested(uint256 indexed recoveryId, address indexed identity, address proposedNewOwner);
    event RecoveryApproved(uint256 indexed recoveryId, address indexed guardian);
    event RecoveryExecuted(uint256 indexed recoveryId, address indexed identity, address previousOwner, address newOwner, uint256 approvalCount);
    event RecoveryCancelled(uint256 indexed recoveryId, address indexed identity);

    event UserRegistered(address indexed identity, string profileURI);
    event AuditLog(address indexed actor, string action, string details, uint256 timestamp);

    constructor() {
        superAdmin = msg.sender;
        admins[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
        _;
    }

    // --- IDENTITY RESOLUTION ---
    function getIdentity(address wallet) public view returns (address) {
        address id = _activeToOriginal[wallet];
        return id == address(0) ? wallet : id;
    }

    function getActiveWallet(address identity) public view returns (address) {
        address active = _originalToActive[identity];
        return active == address(0) ? identity : active;
    }

    function enforceActiveWallet(address wallet) internal view {
        address identity = getIdentity(wallet);
        require(getActiveWallet(identity) == wallet, "Wallet is no longer active for this identity");
    }

    // --- USER REGISTRY ---
    function registerUser(address _user, string memory _profileURI) public {
        address identity = getIdentity(_user);
        require(!userProfiles[identity].isRegistered, "User already registered");
        userProfiles[identity] = UserProfile(identity, _profileURI, true);
        emit UserRegistered(identity, _profileURI);
    }

    function getUserProfile(address _user) public view returns (UserProfile memory) {
        address identity = getIdentity(_user);
        return userProfiles[identity];
    }

    // --- AUDIT LOGGING ---
    function logAudit(string memory action, string memory details) public onlyAdmin {
        emit AuditLog(msg.sender, action, details, block.timestamp);
    }

    // --- EXISTING CORE ---
    function addAdmin(address _admin) public {
        require(msg.sender == superAdmin, "Not super admin");
        admins[_admin] = true;
    }

    function mintAsset(
        address _owner,
        string memory _assetType,
        string memory _assetName,
        uint256 _quantity,
        string memory _metadataURI
    ) public onlyAdmin returns (uint256) {
        require(_owner != address(0), "Invalid owner address");
        require(_quantity > 0, "Quantity must be greater than zero");
        require(bytes(_assetName).length > 0, "Asset name cannot be empty");
        require(bytes(_assetType).length > 0, "Asset type cannot be empty");

        address identity = getIdentity(_owner);
        
        // Auto-register user if not registered
        if (!userProfiles[identity].isRegistered) {
            userProfiles[identity] = UserProfile(identity, "", true);
        }

        assetCounter++;
        assets[assetCounter] = Asset(
            assetCounter,
            _assetType,
            _assetName,
            _quantity,
            _metadataURI,
            identity,
            true
        );
        ownerAssets[identity].push(assetCounter);
        emit AssetMinted(assetCounter, identity, _assetType);
        return assetCounter;
    }

    function getOwnerAssets(address _owner) public view returns (uint256[] memory) {
        address identity = getIdentity(_owner);
        return ownerAssets[identity];
    }

    function revokeAsset(uint256 _id) public onlyAdmin {
        assets[_id].isValid = false;
        emit AssetRevoked(_id);
    }

    // --- RECOVERY LOGIC ---
    function _cancelPendingRecovery(address identity) internal {
        uint256 currentReqId = activeRecoveryId[identity];
        if (currentReqId != 0 && recoveryRequests[currentReqId].status == RecoveryStatus.Pending) {
            recoveryRequests[currentReqId].status = RecoveryStatus.Cancelled;
            emit RecoveryCancelled(currentReqId, identity);
        }
    }

    function addGuardian(address guardian) public {
        enforceActiveWallet(msg.sender);
        address identity = getIdentity(msg.sender);
        
        require(guardian != address(0), "Guardian cannot be zero address");
        require(guardian != msg.sender && guardian != identity, "Cannot be own guardian");
        require(!isGuardian[identity][guardian], "Already a guardian");

        guardians[identity].push(guardian);
        isGuardian[identity][guardian] = true;
        
        if (recoveryThreshold[identity] == 0) {
            recoveryThreshold[identity] = 1;
        }

        _cancelPendingRecovery(identity);
        emit GuardianAdded(identity, guardian);
    }

    function removeGuardian(address guardian) public {
        enforceActiveWallet(msg.sender);
        address identity = getIdentity(msg.sender);
        
        require(isGuardian[identity][guardian], "Not a guardian");

        isGuardian[identity][guardian] = false;
        
        uint256 len = guardians[identity].length;
        for (uint256 i = 0; i < len; i++) {
            if (guardians[identity][i] == guardian) {
                guardians[identity][i] = guardians[identity][len - 1];
                guardians[identity].pop();
                break;
            }
        }
        
        if (recoveryThreshold[identity] > guardians[identity].length) {
            recoveryThreshold[identity] = guardians[identity].length;
            emit RecoveryThresholdChanged(identity, recoveryThreshold[identity]);
        }

        _cancelPendingRecovery(identity);
        emit GuardianRemoved(identity, guardian);
    }

    function setRecoveryThreshold(uint256 threshold) public {
        enforceActiveWallet(msg.sender);
        address identity = getIdentity(msg.sender);
        
        require(threshold > 0, "Threshold must be > 0");
        require(threshold <= guardians[identity].length, "Threshold exceeds guardian count");
        
        recoveryThreshold[identity] = threshold;
        _cancelPendingRecovery(identity);
        emit RecoveryThresholdChanged(identity, threshold);
    }

    function getGuardians(address identity) public view returns (address[] memory) {
        return guardians[identity];
    }

    function getRecoveryThreshold(address identity) public view returns (uint256) {
        return recoveryThreshold[identity];
    }

    function requestRecovery(address identityToRecover, address newOwner) public {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != identityToRecover, "New owner cannot be current owner");
        
        address currentActive = getActiveWallet(identityToRecover);
        require(newOwner != currentActive, "Already active wallet");
        require(guardians[identityToRecover].length > 0, "No guardians set");

        _cancelPendingRecovery(identityToRecover);

        recoveryCounter++;
        recoveryRequests[recoveryCounter] = RecoveryRequest({
            id: recoveryCounter,
            identity: identityToRecover,
            proposedNewOwner: newOwner,
            approvalCount: 0,
            status: RecoveryStatus.Pending
        });

        activeRecoveryId[identityToRecover] = recoveryCounter;
        emit RecoveryRequested(recoveryCounter, identityToRecover, newOwner);
    }

    function approveRecovery(uint256 recoveryId) public {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(req.status == RecoveryStatus.Pending, "Request not pending");
        require(isGuardian[req.identity][msg.sender], "Not a guardian");
        require(!hasApproved[recoveryId][msg.sender], "Already approved");

        hasApproved[recoveryId][msg.sender] = true;
        req.approvalCount++;

        emit RecoveryApproved(recoveryId, msg.sender);
    }

    function executeRecovery(uint256 recoveryId) public {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(req.status == RecoveryStatus.Pending, "Request not pending");
        
        uint256 threshold = recoveryThreshold[req.identity];
        require(req.approvalCount >= threshold, "Threshold not reached");

        req.status = RecoveryStatus.Executed;
        
        address previousActive = getActiveWallet(req.identity);
        
        _activeToOriginal[req.proposedNewOwner] = req.identity;
        _originalToActive[req.identity] = req.proposedNewOwner;

        if (previousActive != req.identity && previousActive != address(0)) {
            _activeToOriginal[previousActive] = address(0);
        }

        emit RecoveryExecuted(recoveryId, req.identity, previousActive, req.proposedNewOwner, req.approvalCount);
    }

    function cancelRecovery(uint256 recoveryId) public {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(req.status == RecoveryStatus.Pending, "Request not pending");
        
        address currentActive = getActiveWallet(req.identity);
        require(msg.sender == currentActive, "Only active wallet can cancel");

        req.status = RecoveryStatus.Cancelled;
        emit RecoveryCancelled(recoveryId, req.identity);
    }
}
