// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                  Structs.                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev A struct containing all the data required for creating a Trade.
     */
    struct Trade {
        bool accepted;
        uint40 timestamp; // accepted ? trade accepted : trade created
        bytes32 resource; // assembly(bulletin, askId/resourceId)
        string feedback;
        bytes data; // used for responses, recorded externalities, etc.
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

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getAsk(uint256 id) external view returns (Ask memory a);

    function getResource(uint256 id) external view returns (Resource memory r);

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory t);
}
