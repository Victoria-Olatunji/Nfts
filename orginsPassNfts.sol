// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/acce
ss/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OriginsPass is ERC721Enumerable, Ownable {

    using Strings for uint256;
    using SafeMath for uint256;
    

    string private baseExtension;
    uint256 public maxSupply;
    uint256 public nftPrice;
    uint256 public maxPerMint = 10;
    uint256 public maxPerWallet = 10;
    uint256 public maxNftReserved = 100;
    uint256 public saleStartTimeStamp;
    uint256 public reservedNftAmount;
    address public withdrawWallet;
    uint256 public maxNumberOfWhitelistedAddresses;
    uint256 public numberOfAddressesWhitelisted;
    address[] public whitelistusers;
    uint96 tradingFees;
    IERC20 public governanceToken;
   

    //event Claim(address indexed claimer);

    mapping(address => uint) public claimTime;
    mapping(address => bool) whitelist;
    

    mapping(address => bool) public firstMintSession;
    mapping(address => uint256) public secondMintSession;
    mapping(address => uint256) public originalMinters;

    constructor(uint256 _maxSupply, uint256 _nftPrice, uint256 _saleStartTimestamp, uint256 _maxNumberOfWhitelistedAddresses, address _governanceTokenAddr) ERC721("Origins-Pass NFTs", "OPN") {
        maxSupply = _maxSupply;
        nftPrice = _nftPrice;
        saleStartTimeStamp = _saleStartTimestamp;
        maxNumberOfWhitelistedAddresses = _maxNumberOfWhitelistedAddresses;
        governanceToken = ERC20(_governanceTokenAddr);
        uint256 supply = totalSupply();
        
        //_baseURI = "https://ipfs.io/ipfs/QmahKj76NfY3J8PXtY59qV8ZmgTvTQBtW1oVzajdL3SemU?filename=Eru-nft.json";
        for(uint256 i = 1; i <= maxNftReserved; i++) {
            _safeMint(msg.sender, i);
        }
        supply = maxNftReserved;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseExtension;
    }
   
    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseExtension = baseURI_;
    }

    function setNftPrice(uint256 _nftPrice) external onlyOwner {
        nftPrice = _nftPrice;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = withdrawWallet.call{value: address(this).balance }("");
        require(success, "Withdrawal failed");
    }

    function reserveNFTs(address _to, uint256 _amount) external onlyOwner {
     require(
        reservedNftAmount.add(_amount) < maxNftReserved, "Not enough NFTs"
     );
     for (uint i = 0; i < _amount; i++) {
          if (totalSupply() < maxSupply) {
                _safeMint(_to, totalSupply());
            }
        }
        reservedNftAmount = reservedNftAmount.add(_amount);
    }

    function walletOfOwner(address _owner)public view returns (uint256[] memory) {
            uint256 ownerTokenCount = balanceOf(_owner);
            if (ownerTokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](ownerTokenCount);
            for (uint256 index; index < ownerTokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
 
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
        }

    function addUserToWhitelist(address userAddress) public onlyOwner{
        
        require(
            numberOfAddressesWhitelisted < maxNumberOfWhitelistedAddresses,
            "Error: Whitelist Limit exceeded"
        );
          for (uint i = 0; i < whitelistusers.length; i++){
            if (whitelistusers[i] == userAddress)
                return;
            }
            whitelistusers.push(userAddress);
            numberOfAddressesWhitelisted = numberOfAddressesWhitelisted.add(1);
      }

    function getWhitelist() public view returns (address[] memory ret){
        return whitelistusers;
    }

    function verifyWhitelistUser(address userAddress) public view returns (bool) {
    for (uint i = 0; i < whitelistusers.length; i++) {
      if (whitelistusers[i] == userAddress) {
          return true;
      }
    }
    return false;
    }

    function removeFromWhitelist(address toRemoveAddresses) external onlyOwner {
        uint removeAt;
        for (uint i = 0; i < whitelistusers.length; i++) {
            if (whitelistusers[i] == toRemoveAddresses)  {
                removeAt = i;
                delete whitelistusers[removeAt];
                numberOfAddressesWhitelisted = numberOfAddressesWhitelisted.sub(1);
                whitelistusers.pop();
            }
        }
        return;
    }
    
    function getNumberOfWhitelistedAddresses() public view returns (uint256) {
        return numberOfAddressesWhitelisted;
    }

    function getMaxNumberOfWhitelistedAddresses() public view returns (uint256) {
        return maxNumberOfWhitelistedAddresses;
    }

    function mintingRounds(address userAddress) public payable {
        require(block.timestamp >= saleStartTimeStamp, "Sale has not commenced.");
        require(block.timestamp < saleStartTimeStamp + 1 days, "First minting session has ended.");
        require(verifyWhitelistUser(userAddress), "user is not whitelisted");
        require(!firstMintSession[msg.sender], "Minted Already");

        firstMintSession[msg.sender] = true;
        originalMinters[msg.sender] = 1;
        _mintTo(msg.sender, 1);
    }

    function mintOriginsPassPublic(uint256 amount) public payable {
        require(block.timestamp >= saleStartTimeStamp + 2 days, "Public minting has not commenced.");
        require(block.timestamp < saleStartTimeStamp + 5 days, "Public minting session has ended.");
        require(amount <= maxPerMint, "You can not mint more than 10 NFTs at a time");
        require(balanceOf(msg.sender).add(amount) <= 10, "Maximum Mint Per Wallet is 10 NFTs");
        require(nftPrice.mul(amount) == msg.value, "Incorrect Value");

        originalMinters[msg.sender] = originalMinters[msg.sender].add(amount);
        _mintTo(msg.sender, amount);
    }

    function _mintTo(address account, uint amount) internal {
        require(totalSupply().add(amount) <= maxSupply, "Max supply exceeded.");

        for (uint256 i = 0; i < amount; i++) {
            if (totalSupply() < maxSupply) {
                _safeMint(account, totalSupply());
            }
        }
    }

    function calculateReward(uint256 _tradingPrice, bool reward, uint128 percentage)  external pure returns (uint256) {
        uint128 bps = percentage * 100;
        uint256 discount = (_tradingPrice * bps)/10000;
        uint256 response;
        if (reward){
            response = add(_tradingPrice, discount);
        }
        else{
            response = subtract(_tradingPrice, discount);
        }
        return response;
    }

    function add(uint256 price, uint256 discount) pure public returns (uint256) {
        return(price.add(discount));
    }
   
    function subtract(uint256 price, uint256 discount) pure public returns (uint256) {
        return(price.sub(discount));
    }
 
   function airdrop(address[] memory whitelistAddresses, uint256 numberOfTokens) public onlyOwner {
        uint256 totalToMint = whitelistAddresses.length * numberOfTokens;
        require(totalSupply() + totalToMint <= maxSupply, "Maximum Supply exceeded");
        for(uint256 i = 0; i < whitelistAddresses.length; i++) {
            _safeMint(whitelistAddresses[i], numberOfTokens, '');
        }
    }     
}