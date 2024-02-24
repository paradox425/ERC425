// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC425 {
  /**
   * The caller must own the token or be an approved operator.
   */
  error ApprovalCallerNotOwnerNorApproved();

  /**
   * Cannot query the balance for the zero address.
   */
  error BalanceQueryForZeroAddress();

  /**
   * Cannot mint to the zero address.
   */
  error MintToZeroAddress();

  /**
   * The quantity of tokens minted must be more than zero.
   */
  error MintZeroQuantity();

  /**
   * Cannot burn from the zero address.
   */
  error BurnFromZeroAddress();

  /**
   * Cannot burn from the address that doesn't owne the token.
   */
  error BurnFromNonOnwerAddress();

  /**
   * The caller must own the token or be an approved operator.
   */
  error TransferCallerNotOwnerNorApproved();

  /**
   * The token must be owned by `from` or the `amount` is not 1.
   */
  error TransferFromIncorrectOwnerOrInvalidAmount();

  /**
   * Cannot safely transfer to a contract that does not implement the
   * ERC1155Receiver interface.
   */
  error TransferToNonERC1155ReceiverImplementer();

  /**
   * Cannot transfer to the zero address.
   */
  error TransferToZeroAddress();

  /**
   * The length of input arraies is not matching.
   */
  error InputLengthMistmatch();

  error InvalidQueryRange();

  error DecimalsTooLow();

  error ERC425InvalidSelfTransfer(address from, address to);

  error NFTTransferToNFTExemptAddress(address to);

  error CannotRemoveFromNFTsTransferExempt();

  error InvalidNFTId();

  function isOwnerOf(address account, uint256 id) external view returns (bool);

  function balanceOf(
    address owner,
    uint256 start,
    uint256 stop
  ) external view returns (uint256);

  function totalNFTsOwned(address owner) external view returns (uint256);

  function tokensOfOwnerIn(
    address owner,
    uint256 start,
    uint256 stop
  ) external view returns (uint256[] memory);

  function tokensOfOwner(
    address owner
  ) external view returns (uint256[] memory);

  function tokenURI(uint256 id_) external view returns (string memory);
}
