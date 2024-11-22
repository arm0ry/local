// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                  Structs.                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev A struct containing all the data required for creating an Ask.
     */
    struct Ask {
        bool fulfilled;
        address owner;
        uint256 role;
        string title;
        string detail;
        address currency;
        uint256 drop;
    }

    /**
     * @dev A struct containing all the data required for creating a Trade per Ask.
     */
    struct Trade {
        bool accepted;
        uint40 timestamp; // accepted ? trade accepted : trade created
        bytes32 resource; // assembly(bulletin, askId/resourceId)
        string feedback; // commentary
        bytes data; // used for responses, externalities, etc.
    }

    /**
     * @dev A struct containing all the data required for creating a Resource.
     */
    struct Resource {
        uint40 role;
        uint40 expiry;
        address owner;
        string title;
        string detail;
    }

    /**
     * @dev A struct containing all the data required for creating Usage per Resource.
     */
    struct Usage {
        bytes32 ask;
        uint40 timestamp;
        string feedback; // commentary
        bytes data; // used for responses, externalities, etc.
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events.                                  */
    /* -------------------------------------------------------------------------- */

    event AskAdded(uint256 indexed askId);
    event ResourceAdded(uint256 indexed resourceId);
    event TradeAdded(uint256 indexed askId, bytes32 resource);
    event TradeAccepted(uint256 indexed askId);
    event AskSettled(uint256 indexed askId, uint256 indexed numOfTrades);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error InvalidOwner();
    error InvalidTrade();
    error TradeSettlementMismatch();
    error InvalidTotalPercentage();
    error CannotComment();

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    // Owner.
    function addAskByOwner(Ask calldata a) external;
    function addResourceByOwner(Resource calldata r) external;
    function acceptTradeByOwner(uint256 _askId, uint256 tradeId) external;
    function settleAskByOwner(
        uint256 _askId,
        uint16[] calldata percentages
    ) external;

    // Permissioned users.
    function addAsk(Ask calldata a) external;
    function addResource(Resource calldata r) external;
    function addTrade(uint256 id, Trade calldata t) external;
    function acceptTrade(uint256 _askId, uint256 tradeId) external;
    function settleAsk(uint256 _askId, uint16[] calldata percentages) external;

    // Permissioned bulletins.
    function incrementUsage(
        uint256 role,
        uint256 resourceId,
        bytes32 ask
    ) external;

    // Permissioned `Resource` user.
    function comment(
        uint256 _resourceId,
        uint256 _usageId,
        string calldata feedback,
        bytes calldata data
    ) external;

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getAsk(uint256 id) external view returns (Ask memory a);

    function getResource(uint256 id) external view returns (Resource memory r);

    function getResourceOwner(
        bytes32 resource
    ) external view returns (address owner);

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory t);

    function filterTrades(
        uint256 id,
        bytes32 key,
        uint40 time
    ) external view returns (Trade[] memory _trades);

    /* -------------------------------------------------------------------------- */
    /*                      Public / External Pure Functions.                     */
    /* -------------------------------------------------------------------------- */

    function encodeAsset(
        address bulletin,
        uint256 id
    ) external pure returns (bytes32 asset);

    function decodeAsset(
        bytes32 asset
    ) external pure returns (address bulletin, uint256 id);
}
