// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "solady/src/utils/LibBitmap.sol";

import "./interfaces/IERC425.sol";
import "./lib/Address.sol";

abstract contract ERC425 is
  Context,
  ERC165,
  IERC1155,
  IERC1155MetadataURI,
  IERC425,
  IERC20,
  IERC20Metadata,
  IERC20Errors,
  Ownable
{
  using Address for address;
  using LibBitmap for LibBitmap.Bitmap;

  // Mapping from accout to owned tokens
  mapping(address => LibBitmap.Bitmap) internal _owned;

  // Mapping from account to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
  string private _uri;

  // The next token ID to be minted.
  uint256 private _currentIndex;

  // NFT Whitelist
  mapping(address => bool) public nftsTransferExempt;

  // NFT Approvals
  mapping(uint256 => address) public getApproved;

  mapping(address account => uint256) private _balances;

  mapping(address account => mapping(address spender => uint256))
    private _allowances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;

  /// @dev Decimals for ERC-20 representation
  uint8 public immutable decimals;

  /// @dev Units for ERC-20 representation
  uint256 public immutable units;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 _erc20TokensSupply,
    string memory uri_
  ) Ownable(_msgSender()) {
    _name = name_;
    _symbol = symbol_;
    decimals = decimals_;
    units = 10 ** decimals;
    _totalSupply = _erc20TokensSupply * units;
    _setURI(uri_);
    _currentIndex = _startTokenId();
    nftsTransferExempt[_msgSender()] = true;
    _balances[msg.sender] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  function setNFTsTransferExempt(
    address target,
    bool state
  ) public virtual onlyOwner {
    if (balanceOf(target) >= units && !state) {
      revert CannotRemoveFromNFTsTransferExempt();
    }
    nftsTransferExempt[target] = state;
  }

  /**
   * @dev Returns the name of the token.
   */
  function name() public view virtual returns (string memory) {
    return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {IERC20-totalSupply}.
   */
  function totalSupply() public view virtual returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {IERC20-transfer}.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - the caller must have a balance of at least `value`.
   */
  function transfer(address to, uint256 value) public virtual returns (bool) {
    address owner = _msgSender();
    _transfer(owner, to, value, true);
    return true;
  }

  /**
   * @dev See {IERC20-allowance}.
   */
  function allowance(
    address owner,
    address spender
  ) public view virtual returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {IERC20-approve}.
   *
   * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
   * `transferFrom`. This is semantically equivalent to an infinite approval.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(
    address spender,
    uint256 value
  ) public virtual returns (bool) {
    address owner = _msgSender();
    _approve(owner, spender, value);
    return true;
  }

  /**
   * @dev See {IERC20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {ERC20}.
   *
   * NOTE: Does not update the allowance if the current allowance
   * is the maximum `uint256`.
   *
   * Requirements:
   *
   * - `from` and `to` cannot be the zero address.
   * - `from` must have a balance of at least `value`.
   * - the caller must have allowance for ``from``'s tokens of at least
   * `value`.
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public virtual returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, value);
    _transfer(from, to, value, true);
    return true;
  }

  /**
   * @dev Moves a `value` amount of tokens from `from` to `to`.
   *
   * This internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * NOTE: This function is not virtual, {_update} should be overridden instead.
   */
  function _transfer(
    address from,
    address to,
    uint256 value,
    bool isNFTTransfer
  ) internal virtual {
    if (from == address(0)) {
      revert ERC20InvalidSender(address(0));
    }
    if (to == address(0)) {
      revert ERC20InvalidReceiver(address(0));
    }
    if (from == to) {
      revert ERC425InvalidSelfTransfer(from, to);
    }
    _update(from, to, value, isNFTTransfer);
  }

  /**
   * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
   * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
   * this function.
   *
   * Emits a {Transfer} event.
   */
  function _update(
    address from,
    address to,
    uint256 value,
    bool isNFTTransfer
  ) internal virtual {
    uint256 fromBalance = _balances[from];
    uint256 toBalance = _balances[to];

    if (fromBalance < value) {
      revert ERC20InsufficientBalance(from, fromBalance, value);
    }
    unchecked {
      // Overflow not possible: value <= fromBalance <= totalSupply.
      _balances[from] = fromBalance - value;

      // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
      _balances[to] += value;
    }

    emit Transfer(from, to, value);

    if (isNFTTransfer) {
      // Preload for gas savings
      bool isFromNFTTransferExempt = nftsTransferExempt[from];
      bool isToNFTTransferExempt = nftsTransferExempt[to];
      uint256 wholeTokens = value / units;
      // Skip burning and/or minting of NFTs wherever needed/possible
      // to save gas, and
      // NFT transfer exempt addresses won't always have/need NFTs corresponding to their ERC20s.
      if (isFromNFTTransferExempt && isToNFTTransferExempt) {
        // Case 1. Both sender and recipient are NFT transfer exempt. So, no NFTs need to be transferred.
        // NOOP.
      } else if (isFromNFTTransferExempt) {
        // Case 2. The sender is NFT transfer exempt, but the recipient is not. Contract should not attempt
        //         to transfer NFTs from the sender, but the recipient should receive NFTs
        //         (by minting) for any whole number increase in their balance.
        // Only cares about whole number increments.
        if (wholeTokens > 0) {
          _mintWithoutCheck(to, wholeTokens);
        }
      } else if (isToNFTTransferExempt) {
        // Case 3. The sender is not NFT transfer exempt, but the recipient is. Contract should attempt
        //         to burn NFTs from the sender, but the recipient should not
        //         receive NFTs(no minting).
        // Only cares about whole number increments.
        if (wholeTokens > 0) {
          _burnBatch(from, wholeTokens);
        }
      } else {
        // Case 4. Neither the sender nor the recipient are NFT transfer exempt.
        // Strategy:
        // a. First deal with the whole tokens: Burn from sender and mint at receiver.
        // b. Look at the fractional part of the value:
        //   (i) If it causes the sender to lose a whole token that was represented by an NFT due to a
        //      fractional part being transferred, burn an additional NFT from the sender.
        //   (ii)) If it causes the receiver to gain a whole new token that should be represented by an NFT
        //      due to receiving a fractional part that completes a whole token, mint an NFT to the recevier.

        if (wholeTokens > 0) {
          _burnBatch(from, wholeTokens);
          _mintWithoutCheck(to, wholeTokens);
        }

        // Look if subtracting the fractional amount from the balance causes the balance to
        // drop below the original balance % units, which represents the number of whole tokens they started with.
        uint256 fractionalAmount = value % units;

        if ((fromBalance - fractionalAmount) / units < (fromBalance / units)) {
          _burnBatch(from, 1);
        }

        // Check if the receive causes the receiver to gain a whole new token that should be represented
        // by an NFT due to receiving a fractional part that completes a whole token.
        if ((toBalance + fractionalAmount) / units > (toBalance / units)) {
          _mintWithoutCheck(to, 1);
        }
      }
    }
  }

  /**
   * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
   *
   * This internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   *
   * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
   */
  function _approve(address owner, address spender, uint256 value) internal {
    _approve(owner, spender, value, true);
  }

  /**
   * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
   *
   * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
   * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
   * `Approval` event during `transferFrom` operations.
   *
   * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
   * true using the following override:
   * ```
   * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
   *     super._approve(owner, spender, value, true);
   * }
   * ```
   *
   * Requirements are the same as {_approve}.
   */
  function _approve(
    address owner,
    address spender,
    uint256 value,
    bool emitEvent
  ) internal virtual {
    if (owner == address(0)) {
      revert ERC20InvalidApprover(address(0));
    }
    if (spender == address(0)) {
      revert ERC20InvalidSpender(address(0));
    }
    _allowances[owner][spender] = value;
    if (emitEvent) {
      emit Approval(owner, spender, value);
    }
  }

  /**
   * @dev Updates `owner` s allowance for `spender` based on spent `value`.
   *
   * Does not update the allowance value in case of infinite allowance.
   * Revert if not enough allowance is available.
   *
   * Does not emit an {Approval} event.
   */
  function _spendAllowance(
    address owner,
    address spender,
    uint256 value
  ) internal virtual {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      if (currentAllowance < value) {
        revert ERC20InsufficientAllowance(spender, currentAllowance, value);
      }
      unchecked {
        _approve(owner, spender, currentAllowance - value, false);
      }
    }
  }

  /**
   * @dev Returns the starting token ID.
   * To change the starting token ID, please override this function.
   */
  function _startTokenId() internal pure virtual returns (uint256) {
    return 1;
  }

  /**
   * @dev Returns the next token ID to be minted.
   */
  function _nextTokenId() internal view returns (uint256) {
    return _currentIndex;
  }

  /**
   * @dev Returns the total amount of tokens minted in the contract.
   */
  function _totalMinted() internal view returns (uint256) {
    return _nextTokenId() - _startTokenId();
  }

  /// @notice tokenURI must be implemented by child contract
  function tokenURI(uint256 id_) public view virtual returns (string memory);

  /**
   * @dev Returns true if the account owns the `id` token.
   */
  function isOwnerOf(
    address account,
    uint256 id
  ) public view virtual override returns (bool) {
    return _owned[account].get(id);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(ERC165, IERC165) returns (bool) {
    return
      interfaceId == type(IERC1155).interfaceId ||
      interfaceId == type(IERC1155MetadataURI).interfaceId ||
      interfaceId == type(IERC425).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC1155MetadataURI-uri}.
   *
   * This implementation returns the same URI for *all* token types. It relies
   * on the token type ID substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * Clients calling this function must replace the `\{id\}` substring with the
   * actual token type ID.
   */
  function uri(uint256) public view virtual override returns (string memory) {
    return _uri;
  }

  /**
   * @dev See {IERC1155-balanceOf}.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function balanceOf(
    address account,
    uint256 id
  ) public view virtual override returns (uint256) {
    if (account == address(0)) {
      revert BalanceQueryForZeroAddress();
    }
    if (_owned[account].get(id)) {
      return 1;
    } else {
      return 0;
    }
  }

  /**
   * @dev See {IERC1155-balanceOfBatch}.
   *
   * Requirements:
   *
   * - `accounts` and `ids` must have the same length.
   */
  function balanceOfBatch(
    address[] memory accounts,
    uint256[] memory ids
  ) public view virtual override returns (uint256[] memory) {
    if (accounts.length != ids.length) {
      revert InputLengthMistmatch();
    }

    uint256[] memory batchBalances = new uint256[](accounts.length);

    for (uint256 i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts[i], ids[i]);
    }

    return batchBalances;
  }

  /**
   * @dev See {IERC1155-setApprovalForAll}.
   */
  function setApprovalForAll(
    address operator,
    bool approved
  ) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC1155-isApprovedForAll}.
   */
  function isApprovedForAll(
    address account,
    address operator
  ) public view virtual override returns (bool) {
    return _operatorApprovals[account][operator];
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public virtual override {
    if (nftsTransferExempt[to]) {
      revert NFTTransferToNFTExemptAddress(to);
    } else if (from == _msgSender() || isApprovedForAll(from, _msgSender())) {
      _safeTransferFrom(from, to, id, amount, data, true);
    } else {
      revert TransferCallerNotOwnerNorApproved();
    }
  }

  /**
   * @dev See {IERC1155-safeBatchTransferFrom}.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public virtual override {
    if (!(from == _msgSender() || isApprovedForAll(from, _msgSender()))) {
      revert TransferCallerNotOwnerNorApproved();
    }
    _safeBatchTransferFrom(from, to, ids, amounts, data);
  }

  /**
   * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `amount` cannot be zero.
   * - `from` must have a balance of tokens of type `id` of at least `amount`.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data,
    bool approvalCheck
  ) internal virtual {
    if (to == address(0)) {
      revert TransferToZeroAddress();
    }

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);

    _beforeTokenTransfer(operator, from, to, ids);

    if (amount == 1 && _owned[from].get(id)) {
      _owned[from].unset(id);
      _owned[to].set(id);
      _transfer(from, to, 1 * units, false);
    } else {
      revert TransferFromIncorrectOwnerOrInvalidAmount();
    }

    emit TransferSingle(operator, from, to, id, amount);

    _afterTokenTransfer(operator, from, to, ids);
    if (approvalCheck) {
      _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   */
  function _safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual {
    if (ids.length != amounts.length) {
      revert InputLengthMistmatch();
    }

    if (to == address(0)) {
      revert TransferToZeroAddress();
    }
    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, to, ids);

    for (uint256 i = 0; i < ids.length; ++i) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      if (amount == 1 && _owned[from].get(id)) {
        _owned[from].unset(id);
        _owned[to].set(id);
      } else {
        revert TransferFromIncorrectOwnerOrInvalidAmount();
      }
    }

    _transfer(from, to, 1 * units * ids.length, false);

    emit Transfer(from, to, 1 * units * ids.length);

    emit TransferBatch(operator, from, to, ids, amounts);

    _afterTokenTransfer(operator, from, to, ids);

    _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
  }

  /**
   * @dev Sets a new URI for all token types, by relying on the token type ID
   * substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * By this mechanism, any occurrence of the `\{id\}` substring in either the
   * URI or any of the amounts in the JSON file at said URI will be replaced by
   * clients with the token type ID.
   *
   * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
   * interpreted by clients as
   * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
   * for token type ID 0x4cce0.
   *
   * See {uri}.
   *
   * Because these URIs cannot be meaningfully represented by the {URI} event,
   * this function emits no events.
   */
  function _setURI(string memory newuri) internal virtual {
    _uri = newuri;
  }

  function _mint(address to, uint256 amount) internal virtual {
    _mint(to, amount, "");
  }

  /**
   * @dev Creates `amount` tokens, and assigns them to `to`.
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `amount` cannot be zero.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _mint(
    address to,
    uint256 amount,
    bytes memory data
  ) internal virtual {
    (uint256[] memory ids, uint256[] memory amounts) = _mintWithoutCheck(
      to,
      amount
    );

    uint256 end = _currentIndex;
    _doSafeBatchTransferAcceptanceCheck(
      _msgSender(),
      address(0),
      to,
      ids,
      amounts,
      data
    );
    if (_currentIndex != end) revert();
  }

  function _mintWithoutCheck(
    address to,
    uint256 amount
  ) internal virtual returns (uint256[] memory ids, uint256[] memory amounts) {
    if (to == address(0)) {
      revert MintToZeroAddress();
    }
    if (amount == 0) {
      revert MintZeroQuantity();
    }

    address operator = _msgSender();

    ids = new uint256[](amount);
    amounts = new uint256[](amount);
    uint256 startTokenId = _nextTokenId();

    unchecked {
      require(type(uint256).max - amount >= startTokenId);
      for (uint256 i = 0; i < amount; i++) {
        ids[i] = startTokenId + i;
        amounts[i] = 1;
      }
    }

    _beforeTokenTransfer(operator, address(0), to, ids);

    _owned[to].setBatch(startTokenId, amount);
    _currentIndex += amount;

    emit TransferBatch(operator, address(0), to, ids, amounts);

    _afterTokenTransfer(operator, address(0), to, ids);
  }

  /**
   * @dev Destroys token of token type `id` from `from`
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `from` must have the token of token type `id`.
   */
  function _burn(address from, uint256 id) internal virtual {
    if (from == address(0)) {
      revert BurnFromZeroAddress();
    }

    address operator = _msgSender();
    uint256[] memory ids = _asSingletonArray(id);

    _beforeTokenTransfer(operator, from, address(0), ids);

    if (!_owned[from].get(id)) {
      revert BurnFromNonOnwerAddress();
    }

    _owned[from].unset(id);

    emit TransferSingle(operator, from, address(0), id, 1);

    _afterTokenTransfer(operator, from, address(0), ids);
  }

  /**
   * @dev Destroys tokens of token types in `ids` from `from`
   *
   * Emits a {TransferBatch} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `from` must have the token of token types in `ids`.
   */
  function _burnBatch(address from, uint256[] memory ids) internal virtual {
    if (from == address(0)) {
      revert BurnFromZeroAddress();
    }

    address operator = _msgSender();

    uint256[] memory amounts = new uint256[](ids.length);

    _beforeTokenTransfer(operator, from, address(0), ids);

    unchecked {
      for (uint256 i = 0; i < ids.length; i++) {
        amounts[i] = 1;
        uint256 id = ids[i];
        if (!_owned[from].get(id)) {
          revert BurnFromNonOnwerAddress();
        }
        _owned[from].unset(id);
      }
    }

    emit TransferBatch(operator, from, address(0), ids, amounts);

    _afterTokenTransfer(operator, from, address(0), ids);
  }

  function _burnBatch(address from, uint256 amount) internal virtual {
    if (from == address(0)) {
      revert BurnFromZeroAddress();
    }

    address operator = _msgSender();

    uint256 searchFrom = _nextTokenId();

    uint256[] memory amounts = new uint256[](amount);
    uint256[] memory ids = new uint256[](amount);

    unchecked {
      for (uint256 i = 0; i < amount; i++) {
        amounts[i] = 1;
        uint256 id = _owned[from].findLastSet(searchFrom);
        ids[i] = id;
        _owned[from].unset(id);
        searchFrom = id;
      }
    }

    _beforeTokenTransfer(operator, from, address(0), ids);

    if (amount == 1) emit TransferSingle(operator, from, address(0), ids[0], 1);
    else emit TransferBatch(operator, from, address(0), ids, amounts);

    _afterTokenTransfer(operator, from, address(0), ids);
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits an {ApprovalForAll} event.
   */
  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    require(owner != operator, "ERC1155: setting approval status for self");
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning, as well as batched variants.
   *
   * The same hook is called on both single and batched variants. For single
   * transfers, the length of the `ids` and `amounts` arrays will be 1.
   *
   * Calling conditions (for each `id` and `amount` pair):
   *
   * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * of token type `id` will be  transferred to `to`.
   * - When `from` is zero, `amount` tokens of token type `id` will be minted
   * for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
   * will be burned.
   * - `from` and `to` are never both zero.
   * - `ids` and `amounts` have the same, non-zero length.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids
  ) internal virtual {}

  /**
   * @dev Hook that is called after any token transfer. This includes minting
   * and burning, as well as batched variants.
   *
   * The same hook is called on both single and batched variants. For single
   * transfers, the length of the `id` and `amount` arrays will be 1.
   *
   * Calling conditions (for each `id` and `amount` pair):
   *
   * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * of token type `id` will be  transferred to `to`.
   * - When `from` is zero, `amount` tokens of token type `id` will be minted
   * for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
   * will be burned.
   * - `from` and `to` are never both zero.
   * - `ids` and `amounts` have the same, non-zero length.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _afterTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids
  ) internal virtual {}

  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) private {
    if (to.isContract()) {
      try
        IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data)
      returns (bytes4 response) {
        if (response != IERC1155Receiver.onERC1155Received.selector) {
          revert TransferToNonERC1155ReceiverImplementer();
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert TransferToNonERC1155ReceiverImplementer();
      }
    }
  }

  function _doSafeBatchTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) private {
    if (to.isContract()) {
      try
        IERC1155Receiver(to).onERC1155BatchReceived(
          operator,
          from,
          ids,
          amounts,
          data
        )
      returns (bytes4 response) {
        if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
          revert TransferToNonERC1155ReceiverImplementer();
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert TransferToNonERC1155ReceiverImplementer();
      }
    }
  }

  function _asSingletonArray(
    uint256 element
  ) private pure returns (uint256[] memory array) {
    array = new uint256[](1);
    array[0] = element;
  }

  /**
   * @dev Returns the number of ERC20 tokens owned by `owner`.
   */
  function balanceOf(address owner) public view virtual returns (uint256) {
    return _balances[owner];
  }

  /**
   * @dev Returns the number of tokens owned by `owner`.
   */
  function totalNFTsOwned(address owner) public view virtual returns (uint256) {
    return balanceOf(owner, _startTokenId(), _nextTokenId());
  }

  /**
   * @dev Returns the number of tokens owned by `owner`,
   * in the range [`start`, `stop`)
   * (i.e. `start <= tokenId < stop`).
   *
   * Requirements:
   *
   * - `start < stop`
   */
  function balanceOf(
    address owner,
    uint256 start,
    uint256 stop
  ) public view virtual override returns (uint256) {
    return _owned[owner].popCount(start, stop - start);
  }

  /**
   * @dev Returns an array of token IDs owned by `owner`,
   * in the range [`start`, `stop`)
   * (i.e. `start <= tokenId < stop`).
   *
   * This function allows for tokens to be queried if the collection
   * grows too big for a single call of {ERC1155DelataQueryable-tokensOfOwner}.
   *
   * Requirements:
   *
   * - `start < stop`
   */
  function tokensOfOwnerIn(
    address owner,
    uint256 start,
    uint256 stop
  ) public view virtual override returns (uint256[] memory) {
    unchecked {
      if (start >= stop) revert InvalidQueryRange();

      // Set `start = max(start, _startTokenId())`.
      if (start < _startTokenId()) {
        start = _startTokenId();
      }

      // Set `stop = min(stop, stopLimit)`.
      uint256 stopLimit = _nextTokenId();
      if (stop > stopLimit) {
        stop = stopLimit;
      }

      uint256 tokenIdsLength;
      if (start < stop) {
        tokenIdsLength = balanceOf(owner, start, stop);
      } else {
        tokenIdsLength = 0;
      }

      uint256[] memory tokenIds = new uint256[](tokenIdsLength);

      LibBitmap.Bitmap storage bmap = _owned[owner];

      for (
        (uint256 i, uint256 tokenIdsIdx) = (start, 0);
        tokenIdsIdx != tokenIdsLength;
        ++i
      ) {
        if (bmap.get(i)) {
          tokenIds[tokenIdsIdx++] = i;
        }
      }
      return tokenIds;
    }
  }

  /**
   * @dev Returns an array of token IDs owned by `owner`.
   *
   * This function scans the ownership mapping and is O(`totalSupply`) in complexity.
   * It is meant to be called off-chain.
   *
   * See {ERC425Queryable-tokensOfOwnerIn} for splitting the scan into
   * multiple smaller scans if the collection is large enough to cause
   * an out-of-gas error (10K collections should be fine).
   */
  function tokensOfOwner(
    address owner
  ) public view virtual override returns (uint256[] memory) {
    if (_totalMinted() == 0) {
      return new uint256[](0);
    }
    return tokensOfOwnerIn(owner, _startTokenId(), _nextTokenId());
  }
}
