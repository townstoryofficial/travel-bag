// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../IERC1155GameItems.sol";

contract LineaTravelbag is Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;
    
    enum ItemsType {
        Backpack,
        AvatarCustomization,
        Inventory,
        Building
    }

    address private signer;
    uint8 public mintPerMax;
    mapping(bytes32 => bool) public executed;
    mapping(address => uint8) public mintedAmountList;
    mapping(ItemsType => address) public itemsContract;

    constructor(
        address _signer,
        address _avatarCustomization
    ) {
        signer = _signer;
        setMintPerMax(1);
        itemsContract[ItemsType.AvatarCustomization] = _avatarCustomization;
    }

    modifier _notContract() {
        uint256 size;
        address addr = _msgSender();
        assembly {
            size := extcodesize(addr)
        }
        require(size == 0, "Contract is not allowed");
        require(_msgSender() == tx.origin, "Proxy contract is not allowed");
        _;
    }

    function claimLineaTravelbag(
        bytes memory signature,
        address _addr,
        uint deadline
    ) public whenNotPaused _notContract nonReentrant {
        require(deadline >= block.timestamp, "Deadline Passed");
        require(getMintedAmount(_addr) < mintPerMax, "Minted reached the limit");

        bytes32 txHash = keccak256(abi.encode(_addr, deadline, _msgSender()));
        require(!executed[txHash], "Tx Executed");
        require(verify(txHash, signature), "Unauthorised");
        executed[txHash] = true;

        uint256[] memory mintId = new uint256[](1);
        mintId[0] = 73001;

        uint256[] memory mintAmount = new uint256[](1);
        mintAmount[0] = 1;

        mintedAmountList[_addr] += 1; 
        IERC1155GameItems(itemsContract[ItemsType.AvatarCustomization]).gameMintBatch(_addr, mintId, mintAmount, "");
    }

    function verify(bytes32 hash, bytes memory signature) private view returns (bool) {
        bytes32 ethSignedHash = hash.toEthSignedMessageHash();
        return ethSignedHash.recover(signature) == signer;
    }

    function getMintedAmount(address _addr) public view returns (uint8) {
        return mintedAmountList[_addr];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transferSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function setMintPerMax(uint8 _mintPerMax) public onlyOwner {
        mintPerMax = _mintPerMax;
    }

    function setItemsContract(ItemsType _type, address _addr) public onlyOwner {
        itemsContract[_type] = _addr;
    }
}