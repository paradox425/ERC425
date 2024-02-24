//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC425} from "../ERC425.sol";

contract PARADOX is ERC425 {
  string public dataURI;
  string public baseTokenURI;

  mapping(address => bool) private blacklist;
  uint256 public maxWallet;
  uint256 private deploymentBlock;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 _erc20TokensSupply,
    string memory uri_
  ) ERC425(name_, symbol_, decimals_, _erc20TokensSupply, uri_) {
    maxWallet = ((_erc20TokensSupply * 10 ** decimals_) * 2) / 100;
    deploymentBlock = block.number;
    dataURI = uri_;
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids
  ) internal override {
    require(!blacklist[from], "Sender is blacklisted.");
    require(!blacklist[to], "Recipient is blacklisted.");

    require(
      block.number > deploymentBlock + 50,
      "Transfers are blocked for the first 50 blocks after deployment."
    );

    super._beforeTokenTransfer(operator, from, to, ids);
  }

  function _afterTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids
  ) internal override {
    if (!nftsTransferExempt[to]) {
      require(
        balanceOf(to) <= maxWallet,
        "Transfer exceeds allowed holding per wallet"
      );
    }

    super._afterTokenTransfer(operator, from, to, ids);
  }

  function setDataURI(string memory _dataURI) public onlyOwner {
    dataURI = _dataURI;
  }

  function setTokenURI(string memory _tokenURI) public onlyOwner {
    baseTokenURI = _tokenURI;
  }

  function setURI(string memory _uri) external onlyOwner {
    _setURI(_uri);
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
    if (id >= _nextTokenId()) revert InvalidNFTId();

    if (bytes(baseTokenURI).length > 0) {
      return string.concat(baseTokenURI, Strings.toString(id));
    } else {
      uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id))));
      string memory image;
      string memory color;

      if (seed <= 100) {
        image = "1.gif";
        color = "Blue";
      } else if (seed <= 160) {
        image = "2.gif";
        color = "Red";
      } else if (seed <= 210) {
        image = "3.gif";
        color = "Grey";
      } else if (seed <= 240) {
        image = "4.gif";
        color = "Green";
      } else if (seed <= 255) {
        image = "5.gif";
        color = "Black";
      }

      string memory jsonPreImage = string.concat(
        string.concat(
          string.concat('{"name": "Paradox #', Strings.toString(id)),
          '","description":"A collection of 10,000 NFTs enabled by ERC425, a gas optimized experimental token standard. Earn yield on your semi-fungible tokens by transforming existing illiquid NFTS into liquid assets.","external_url":"https://pdx.build","image":"'
        ),
        string.concat(dataURI, image)
      );
      string memory jsonPostImage = string.concat(
        '","attributes":[{"trait_type":"Color","value":"',
        color
      );
      string memory jsonPostTraits = '"}]}';

      return
        string.concat(
          "data:application/json;utf8,",
          string.concat(
            string.concat(jsonPreImage, jsonPostImage),
            jsonPostTraits
          )
        );
    }
  }

  function uri(uint256 id) public view override returns (string memory) {
    return tokenURI(id);
  }

  function setBlacklist(address target, bool state) public virtual onlyOwner {
    blacklist[target] = state;
  }

  function setMaxWallet(uint256 percentage) external onlyOwner {
    maxWallet = (totalSupply() * percentage) / 100;
  }
}
