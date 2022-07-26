// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "hardhat/console.sol";

contract BullnBear is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    KeeperCompatibleInterface,
    VRFConsumerBaseV2
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    AggregatorV3Interface internal priceFeed;

    int256 private _lastPrice;
    uint256 private _vrfRequestId;

    string private _shouldUpdateToTrend;

    uint256 private _randomIndex;

    VRFCoordinatorV2Interface internal COORDINATOR;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 s_keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 callbackGasLimit = 600000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    constructor(uint64 subscriptionId)
        ERC721("BullnBear", "BBNFT")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        priceFeed = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );

        _lastPrice = getLatestPrice();

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function getLatestPrice() public view returns (int256) {
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return price;
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        // Default to a bull NFT
        string memory defaultUri = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);

        console.log(
            "Minted token ",
            tokenId,
            " and assigned token url: ",
            defaultUri
        );
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = getLatestPrice() != _lastPrice;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        int256 newPrice = getLatestPrice();

        if (newPrice < _lastPrice) {
            // Bear
            _shouldUpdateToTrend = "bear";
        } else if (newPrice > _lastPrice) {
            // Bull
            _shouldUpdateToTrend = "bull";
        }

        if (newPrice != _lastPrice) {
            _lastPrice = newPrice;

            // Generate new number
            _vrfRequestId = COORDINATOR.requestRandomWords(
                s_keyHash,
                s_subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                numWords
            );
        }
    }

    // fulfillRandomWords function
    function fulfillRandomWords(uint256, uint256[] memory randomWords)
        internal
        override
    {
        // transform the result to a number between 0 to 2
        _randomIndex = (randomWords[0] % 2);

        // Update the tokenURIs
        _updateAllTokenURIs(_shouldUpdateToTrend);
    }

    function _updateAllTokenURIs(string memory trend) private {
        uint256 tokenId = _tokenIdCounter.current();

        if (compareString(trend, "bull")) {
            for (uint256 i = 0; i < tokenId; i++) {
                _setTokenURI(i, bullUrisIpfs[_randomIndex]);
            }
        } else if (compareString(trend, "bear")) {
            for (uint256 i = 0; i < tokenId; i++) {
                _setTokenURI(i, bearUrisIpfs[_randomIndex]);
            }
        }
    }

    function randomIndex() public view returns (uint256) {
        return _randomIndex;
    }

    function vrfRequestId() public view returns (uint256) {
        return _vrfRequestId;
    }

    function compareString(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
