// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC6909} from "lib/solady/src/tokens/ERC6909.sol";
import {TokenUriBuilder} from "src/tokens/TokenUriBuilder.sol";
import {IBulletin, List} from "src/interface/IBulletin.sol";
import {ILog} from "src/interface/ILog.sol";
import {ITokenMinter, TokenMetadata, TokenSource, TokenBuilder, TokenMarket} from "src/interface/ITokenMinter.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

/// @title
/// @notice SVG NFTs displaying impact results and metrics.
contract TokenMinter is ERC6909 {
    error InvalidConfig();
    error AlreadyConfigured();
    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public tokenId;
    mapping(uint256 => TokenMetadata) public titles;
    mapping(uint256 => TokenBuilder) public builders;
    mapping(uint256 => TokenSource) public sources;
    mapping(uint256 => TokenMarket) public markets;
    mapping(uint256 => address) public owners;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyLogger(uint256 id) {
        (, , , address logger) = getTokenSource(id);
        if (logger == address(0) || msg.sender != logger) revert Unauthorized();
        _;
    }

    modifier onlyMarket(uint256 id) {
        (address market, ) = getTokenMarket(id);
        if (market == address(0) || msg.sender != market) revert Unauthorized();
        _;
    }

    modifier onlyTokenOwner(uint256 id) {
        address owner = owners[id];
        if (owner == address(0) || msg.sender != owner) revert Unauthorized();
        _;
    }

    function name(uint256 id) public view override returns (string memory n) {
        (n, , ) = getTokenMetadata(id);
    }

    function symbol(uint256 id) public view override returns (string memory s) {
        (, s, ) = getTokenMetadata(id);
    }

    function desc(uint256 id) public view returns (string memory d) {
        (, , d) = getTokenMetadata(id);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        (address builder, uint256 builderId) = getTokenBuilder(id);
        return
            TokenUriBuilder(builder).build(builderId, titles[id], sources[id]);
    }

    function svg(uint256 id) public view returns (string memory) {
        (address builder, uint256 builderId) = getTokenBuilder(id);
        (
            address user,
            address bulletin,
            uint256 listId,
            address logger
        ) = getTokenSource(id);
        return
            TokenUriBuilder(builder).generateSvg(
                builderId,
                user,
                bulletin,
                listId,
                logger
            );
    }

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    /// @notice Minter registration for list owners.
    function registerMinter(
        TokenMetadata calldata title,
        TokenSource calldata source,
        TokenBuilder calldata builder,
        TokenMarket calldata market
    ) external payable {
        if (builder.builder == address(0)) revert InvalidConfig();
        List memory list = IBulletin(source.bulletin).getList(source.listId);
        if (msg.sender != list.owner) revert Unauthorized();

        unchecked {
            ++tokenId;
        }

        titles[tokenId] = title;
        builders[tokenId] = builder;
        markets[tokenId] = market;
        sources[tokenId] = source;
        owners[tokenId] = msg.sender;
    }

    function updateMinter(
        uint256 id,
        TokenSource calldata source,
        TokenBuilder calldata builder
    ) external payable onlyTokenOwner(id) {
        sources[id] = source;
        builders[id] = builder;
    }

    /// -----------------------------------------------------------------------
    /// Burn by anyone
    /// -----------------------------------------------------------------------

    /// @notice Burn function limited to owner of token.
    function burn(uint256 id) external payable {
        _burn(msg.sender, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn by logger
    /// -----------------------------------------------------------------------

    /// @notice Mint function limited to logger.
    function mintByLogger(
        address to,
        uint256 id
    ) external payable onlyLogger(id) {
        _mint(to, id, 1);
    }

    /// @notice Burn function limited to logger.
    function burnByLogger(
        address from,
        uint256 id
    ) external payable onlyLogger(id) {
        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn by market
    /// -----------------------------------------------------------------------

    /// @notice Mint function limited to market registered by token owner.
    function mintByMarket(
        address to,
        uint256 id
    ) external payable onlyMarket(id) {
        _mint(to, id, 1);
    }

    /// @notice Burn function limited to market registered by token owner.
    function burnByMarket(
        address from,
        uint256 id
    ) external payable onlyMarket(id) {
        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Public getter
    /// -----------------------------------------------------------------------

    function ownerOf(uint256 id) public view returns (address) {
        return owners[id];
    }

    function getTokenMetadata(
        uint256 id
    ) public view returns (string memory, string memory, string memory) {
        TokenMetadata memory title = titles[id];
        return (title.name, title.symbol, title.desc);
    }

    function getTokenBuilder(
        uint256 id
    ) public view returns (address, uint256) {
        TokenBuilder memory builder = builders[id];
        return (builder.builder, builder.builderId);
    }

    function getTokenSource(
        uint256 id
    ) public view returns (address, address, uint256, address) {
        TokenSource memory source = sources[id];
        return (source.user, source.bulletin, source.listId, source.logger);
    }

    function getTokenMarket(uint256 id) public view returns (address, uint256) {
        TokenMarket memory market = markets[id];
        return (market.market, market.limit);
    }
}
