# ERC425

## Introduction

ERC425 is an hybrid of ERC1155 and ERC20, created to provide liquidity to illiquid NFTs. 

## Features

- Cheapest gas fee ever for NFTs
  - 95%+ cheaper than ERC404, and
  - 90%+ cheaper than DN404 & ERCX
- Uses least storage space than any other NFT token standard.
- Each token is unique.
-  Gas savings are possible by implementing Kornecker Delta Function using bitmap storage architecture.
-  After burning or transfer of NFTs, the storage spaces in bitmap are released, which means reducing the impact on blockchain storage space.
-  Branching of transfers of NFTs and ERC20 tokens through different functions.
-  NFT minting and transfers are as cheap as ERC20 transfers.
-  Native support for both ERC20 and ERC1155.
   -  Works just like ERC20 at all Decentralised exchanges.
   -  Works just like ERC1155 on all NFT marketplaces.
- Fixed all vulnerabilities in ERC404.
  
## Fixed the major exploit in ERC404 and other hybrids

The major exploit in ERC404 and all of its adaptations(DN404, MINER, etc) is: that when token ID becomes as high as dust decimals of associated ERC20, the single transfer logic implemented for all these tokens contains a major vulnerability, which is when a transfer of ERC20 is signed by user, an NFT with token ID equivalent to the ERC20 token amount will be transferred instead of the small amount of tokens transfer actually requested. 

Some adaptations of ERC404 fixed this by implementing an NFT token IDs banking mechanism and reusing the burned NFT token IDs. This mechanism puts additional pressure on the already unsustainable gas costs of ERC404.

In ERC425, instead of adding a patch to this exploit, we fixed this once and for all by branching the transfer function for ERC1155 NFTs and associated ERC20 tokens. Making ERC425 as robust as published ERC token standards.

## Interfaces

This project incorporates a set of standardized interfaces located in the `interfaces` folder. These interfaces are fundamental to ensuring our smart contracts are interoperable, follow Ethereum community standards, and can easily integrate with external contracts and services.