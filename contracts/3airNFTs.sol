// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPriceConverter.sol";
import "./interfaces/IERC2981.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract AirNFTs is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {

    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    struct NFTType {
        uint256 collectionId;
        string ipfsLink;
        uint256 limit;
        uint256 price;
        address author;
        uint256 royaltyAmount;

        uint256 available;
    }

    struct Collection {
        string name;
        uint256 expires;
    }

    struct ApprovedCurrencyInfo {
        bool approved;
        bool stableCoin;

        //Converter in case the currency is not a stablecoin
        address priceConverter;
    }

    Counters.Counter _nextNFTId;

    mapping(address => ApprovedCurrencyInfo) public approvedCurrencies;
    mapping(uint256 => uint256) public tokenTypes;

    Collection[] public collections;
    NFTType[] public NFTTypes;

    address proxyRegistryAddress;
    address airMarket;

    event CollectionAdded(uint256 indexed collectionId, string collection_name, uint256 expires);
    event NFTTypeAdded(uint256 indexed tokenTypeId, uint256 indexed collectionId, address indexed author, string ipfsLink, uint256 limit, uint256 price, uint256 royaltyAmount);
    event CurrencyInfoSet(address indexed currency, bool indexed approved, bool indexed stableCoin, address priceConverter);
    event NFTMinted(uint256 indexed nftId, uint256 indexed nftType, uint256 indexed collectionId, address currency, uint256 paymentAmount, address buyer);

    constructor(address _proxyRegistryAddress) ERC721("3air NFTs", "3aNFT") {

        proxyRegistryAddress = _proxyRegistryAddress;

        _nextNFTId.increment();
    }

    function addCollection(string memory collectionName, uint256 expiryTime) public onlyOwner {

        require(expiryTime > block.timestamp, "Expiry needs to be in the future");

        uint256 newCollectionId = collections.length;
        collections.push(Collection(collectionName, expiryTime));

        emit CollectionAdded(newCollectionId, collectionName, expiryTime);
    }

    function addNFTType(uint256 collectionId, string memory ipfsLink, uint256 limit, uint256 price, address author, uint256 royaltyAmount) public onlyOwner {

        require(collectionId < collections.length, "nonexistent collection");
        require(limit > 0, "Limit can't be set to 0");
        require(price > 0, "NFT can't be free");
        require(royaltyAmount <= 10000, "Royalty amount can't be higher than 100%");

        uint256 nextTokenTypeId = NFTTypes.length;
        NFTTypes.push(NFTType(collectionId, ipfsLink, limit, price, author, royaltyAmount, limit));

        emit NFTTypeAdded(nextTokenTypeId, collectionId, author, ipfsLink, limit, price, royaltyAmount);
    }

    function setCurrencyInfo(address currency, bool approved, bool stableCoin, address priceConverter) public onlyOwner {

        if(!stableCoin && approved) {
            require(priceConverter != address(0), "Price converter is required for non stablecoins");
        }

        approvedCurrencies[currency] = ApprovedCurrencyInfo(approved, stableCoin, priceConverter);

        emit CurrencyInfoSet(currency, approved, stableCoin, priceConverter);
    }

    function buyNFT(uint256 nftTypeId, address currency) public {

        require(nftTypeId < NFTTypes.length, "NFT of this type does not exist");

        NFTType memory nftType = NFTTypes[nftTypeId];

        require(nftType.available > 0, "NFT limit exceeded");

        ApprovedCurrencyInfo memory currencyInfo = approvedCurrencies[currency];
        require(currencyInfo.approved, "This currency is not approved");

        NFTTypes[nftTypeId].available--;

        uint256 totalPrice = nftType.price;
        if (!currencyInfo.stableCoin) {
            totalPrice = IPriceConverter(currencyInfo.priceConverter).getTokenAmount(totalPrice);
        }

        uint256 amountToPay = totalPrice;

        uint256 newTokenId = _nextNFTId.current();
        _nextNFTId.increment();

        tokenTypes[newTokenId] = nftTypeId;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, nftType.ipfsLink);


        if (nftType.author != address(0) && nftType.royaltyAmount > 0) {

            uint256 royaltyAmount = (amountToPay * nftType.royaltyAmount) / 10000;
            amountToPay -= royaltyAmount;

            IERC20(currency).safeTransferFrom(msg.sender, nftType.author, royaltyAmount);

        }

        IERC20(currency).safeTransferFrom(msg.sender, address(this), amountToPay);

        emit NFTMinted(newTokenId, nftTypeId, nftType.collectionId, currency, totalPrice, msg.sender);
    }

    function setMarketAddress(address marketAddress) public onlyOwner {
        airMarket = marketAddress;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function royaltyInfo(uint256 tokenId, uint256 value) external view returns (address receiver, uint256 royaltyAmount){
        NFTType memory nftType = NFTTypes[tokenTypes[tokenId]];
        if (nftType.royaltyAmount == 0 || nftType.author == address(0)) {
            return (address(0), 0);
        }
        receiver = nftType.author;
        royaltyAmount = (value * nftType.royaltyAmount) / 10000;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return
        super.supportsInterface(interfaceId) ||
        interfaceId == type(IERC2981).interfaceId;
    }

    function totalSupply() public view override(ERC721Enumerable) returns (uint256) {
        return super.totalSupply();
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view override(ERC721Enumerable) returns (uint256) {
        return super.tokenOfOwnerByIndex(owner, index);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function isApprovedForAll(address owner, address operator)
    override
    public
    view
    returns (bool)
    {

        if (operator == airMarket) {
            return true;
        }

        // Whitelist OpenSea proxy contract for easy trading.
        if(proxyRegistryAddress != address(0)) {
            ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
            if (address(proxyRegistry.proxies(owner)) == operator) {
                return true;
            }
        }

        return super.isApprovedForAll(owner, operator);
    }

}