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

This project incorporates a set of standardized interfaces located in the `contracts/interfaces` folder. These interfaces are fundamental to ensuring our smart contracts are interoperable, follow Ethereum community standards, and can easily integrate with external contracts and services.

## Contracts

All the 19 contracts of ERC425 are placed inside the `contracts` folder or imported from respective libraries. 

## Contributing

We highly enocourage everyone to contribute to the ERC425 standard, please take a note of following contribution notes.

1. **Clone the Repository**: Fork the project on GitHub, then clone your fork to your local machine.

2. **Install Dependencies**: Navigate to the project directory and run `npm install` to install Hardhat and other dependencies.

3. **Create a Feature Branch**: Switch to a new branch for your feature or bug fix using `git checkout -b feature/your-feature-name`.

4. **Develop and Test**: Make your changes in the codebase. Use Hardhat commands like `npx hardhat compile` to compile contracts and `npx hardhat test` to run the test suite. Ensure your changes pass all existing tests and write new tests as necessary.

5. **Update Documentation**: If your changes involve modifications to how users interact with the project, update the README.md or other relevant documentation files.

6. **Commit Your Changes**: Use descriptive commit messages that clearly explain your changes. Commit your code changes to your branch.

7. **Push Your Changes**: Push your feature branch to your GitHub fork with `git push -u origin feature/your-feature-name`.

8. **Create a Pull Request**: Go to the original project repository on GitHub and click the "New pull request" button. Choose your feature branch and submit the pull request with a clear title and description of your changes.

9.  **Respond to Feedback**: Be prepared to respond to feedback and make revisions based on comments from project maintainers.


## License

This software is released under the MIT License.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
