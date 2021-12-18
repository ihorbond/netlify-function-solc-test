`// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract StonerSharks is ERC721, EIP712, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint;
    using SafeMath for uint;
    using Strings for uint64;
    using Address for address;

    Counters.Counter private _tokenIds;

    uint64 public constant COLLECTION_SIZE = 10000;
    uint64 public constant TOKEN_PRICE = 0.04 ether;
    uint64 public constant PRESALE_TOKEN_PRICE = 0.02 ether;

    bool public isPublicSaleActive = false;
    bool public isWhitelistSaleActive = false;
    bool public canReveal = false;
    
    string private _hiddenURI;
    string private _baseUri;
    address private _voucherSigner;

    constructor(string memory delayedRevealUri, string memory baseUri, address voucherSigner, uint reserveCount) 
        ERC721("StonerSharks", "SS")
        EIP712("StonerSharks", "1")
        Ownable() {
            _hiddenURI = delayedRevealUri;
            _baseUri = baseUri;
            _voucherSigner = voucherSigner;
            
            reserve(reserveCount);
        }

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        address redeemer;
        bool whitelisted;
        uint numberOfTokens;
    }

    /// @notice Reserve tokens for owner
    function reserve(uint numberOfTokens) onlyOwner public {
        for(uint index = _tokenIds.current(); index < numberOfTokens; index++) {

            _tokenIds.increment();
            uint newItemId = _tokenIds.current();

            _safeMint(owner(), newItemId);
        }
    }

    function totalSupply() external view returns (uint) {
        return _tokenIds.current();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev override base uri. It will be combined with token ID
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }

    /// @notice Set hidden metadata uri
    function setHiddenUri(string memory uri) onlyOwner external {
        _hiddenURI = uri;
    }

    /// @notice Set base uri
    function setBaseUri(string memory uri) onlyOwner external {
        _baseUri = uri;
    }

    /// @notice Flip public sale
    function flipSaleState() onlyOwner external {
        isPublicSaleActive = !isPublicSaleActive;
        if(isPublicSaleActive) {
            isWhitelistSaleActive = false;
        }
    }

    /// @notice Flip presale
    function flipPresaleState() onlyOwner external {
        isWhitelistSaleActive = !isWhitelistSaleActive;
    }

    /// @notice Reveal metadata for all the tokens
    function reveal() onlyOwner external {
        canReveal = true;
    }

    /// @notice Withdraw's contract's balance to the owner's wallet
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "No balance");

        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Get token's URI. In case of delayed reveal we give user the json of the placeholer metadata.
    /// @param tokenId token ID
    function tokenURI(uint tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();

        if(canReveal) {
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
        }

        return _hiddenURI;
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher An NFTVoucher that describes the NFT to be redeemed.
    /// @param signer address of the signer
    /// @param signature An EIP712 signature of the voucher, produced by the NFT creator.
    function redeem(NFTVoucher calldata voucher, address signer, bytes memory signature) external payable {

        require(_verify(signer, _hash(voucher), signature), "Transaction is not authorized (invalid signature)");
        require(isWhitelistSaleActive || isPublicSaleActive, "Sale must be active to mint");
        require(_tokenIds.current() < COLLECTION_SIZE, "All tokens have been minted");
        require(_tokenIds.current().add(voucher.numberOfTokens) <= COLLECTION_SIZE, "Number of requested tokens will exceed collection size");
        require(voucher.numberOfTokens > 0, "Number of requested tokens has to be greater than 0");
        require(voucher.numberOfTokens <= COLLECTION_SIZE, "Number of requested tokens exceeds collection size");
        
        if(isWhitelistSaleActive) {
            require(msg.value >= voucher.numberOfTokens.mul(PRESALE_TOKEN_PRICE), "Ether value sent is not sufficient");
        }
        else {
            require(msg.value >= voucher.numberOfTokens.mul(TOKEN_PRICE), "Ether value sent is not sufficient");
        }
        
        // require(voucher.numberOfTokens <= TOKENS_PER_TRAN_LIMIT, string(abi.encodePacked("Max ", TOKENS_PER_TRAN_LIMIT.toString(), " token(s) per transaction")));

        for(uint index = 0; index < voucher.numberOfTokens; index++) {

            _tokenIds.increment();
            uint newItemId = _tokenIds.current();

            require(_tokenIds.current() < COLLECTION_SIZE, "All tokens have been minted");

            // first assign the token to the signer, to establish provenance on-chain
            _safeMint(owner(), newItemId);
            
            // transfer the token to the redeemer
            _transfer(owner(), voucher.redeemer, newItemId);
        }
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher)
    internal view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(address redeemer,bool whitelisted,uint numberOfTokens)"),
            voucher.redeemer,
            voucher.whitelisted,
            voucher.numberOfTokens
        )));
    }

    function _verify(address signer, bytes32 digest, bytes memory signature)
    internal view returns (bool)
    {
        return _voucherSigner == signer && SignatureChecker.isValidSignatureNow(signer, digest, signature);
    }
}
`