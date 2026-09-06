// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DigitalAsset {
    
    struct Asset {
        uint256 id;
        string assetType;  // "gold", "stock", "crypto"
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

    event AssetMinted(uint256 id, address owner, string assetType);
    event AssetRevoked(uint256 id);

    constructor() {
        superAdmin = msg.sender;
        admins[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
        _;
    }

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
        assetCounter++;
        assets[assetCounter] = Asset(
            assetCounter,
            _assetType,
            _assetName,
            _quantity,
            _metadataURI,
            _owner,
            true
        );
        ownerAssets[_owner].push(assetCounter);
        emit AssetMinted(assetCounter, _owner, _assetType);
        return assetCounter;
    }

    function getOwnerAssets(address _owner) public view returns (uint256[] memory) {
        return ownerAssets[_owner];
    }

    function revokeAsset(uint256 _id) public onlyAdmin {
        assets[_id].isValid = false;
        emit AssetRevoked(_id);
    }
}