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
        bool approved;
        uint40 timestamp; // accepted ? trade accepted : trade created
        bytes32 resource; // assembly(bulletin, askId/resourceId)
        string feedback; // commentary
        bytes data; // used for responses, externalities, etc.
    }

    /**
     * @dev A struct containing all the data required for creating a Resource.
     */
    struct Resource {
        bool active;
        uint40 role;
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
    event TradeApproved(uint256 indexed askId);
    event AskSettled(uint256 indexed askId, uint256 indexed numOfTrades);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error InvalidOwner();
    error InvalidUpdate();
    error InvalidTrade();
    error InvalidWithdrawal();
    error TradeSettlementMismatch();
    error InvalidTotalPercentage();
    error CannotComment();
    error ResourceNotActive();
    error ResourceNotValid();
    error NothingToTrade();

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    // Assets.
    function ask(Ask calldata a) external payable;
    function resource(Resource calldata r) external;
    function trade(uint256 askId, Trade calldata t) external;

    function updateAsk(uint256 askId, Ask calldata a) external;
    function withdrawAsk(uint256 askId) external;
    function settleAsk(uint256 _askId, uint16[] calldata percentages) external;
    function updateResource(uint256 _resourceId, Resource calldata r) external;
    function approveTrade(uint256 _askId, uint256 tradeId) external;
    function rejectTrade(uint256 _askId, uint256 tradeId) external;
    function incrementUsage(
        uint256 role,
        uint256 resourceId,
        bytes32 bulletinAsk // encodeAsset(address(bulletin), uint96(askId))
    ) external;
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
    ) external returns (Trade[] memory _trades);

    /* -------------------------------------------------------------------------- */
    /*                      Public / External Pure Functions.                     */
    /* -------------------------------------------------------------------------- */

    function encodeAsset(
        address bulletin,
        uint96 id
    ) external pure returns (bytes32 asset);

    function decodeAsset(
        bytes32 asset
    ) external pure returns (address bulletin, uint96 id);
}
