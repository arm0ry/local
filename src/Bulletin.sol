// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title List
/// @notice A database management system to store lists of items.
/// @author audsssy.eth
contract Bulletin is OwnableRoles, IBulletin {
    error InvalidOwner();
    error InvalidTrade();
    error InvalidSettlement();
    error InvalidTotalPercentage();

    /* -------------------------------------------------------------------------- */
    /*                                 Constants.                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev This is the denominator for calculating distribution.
     */
    uint16 private constant TEN_THOUSAND = 10_000;

    /* -------------------------------------------------------------------------- */
    /*                                  Storage.                                  */
    /* -------------------------------------------------------------------------- */

    uint40 askId;
    uint40 resourceId;
    mapping(uint256 => Ask) public asks;
    mapping(uint256 => Resource) public resources;

    mapping(uint256 => uint256) public tradeIds;
    mapping(uint256 => mapping(uint256 => Trade)) public trades;

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    modifier checkSum(uint16[] calldata p) {
        // Throw when total percentage does not equal to TEN_THOUSAND.
        uint256 totalPercentage;
        for (uint256 i; i < p.length; ++i) {
            totalPercentage += p[i];
            if (totalPercentage != TEN_THOUSAND)
                revert InvalidTotalPercentage();
        }
        _;
    }
    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    constructor(address owner) {
        _initializeOwner(owner);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Owner.                                   */
    /* -------------------------------------------------------------------------- */

    function addAskByOwner(Ask calldata a) external onlyOwner {
        _addAsk(true, a);
    }

    function addResourceByOwner(Resource calldata r) external onlyOwner {
        _addResource(true, r);
    }

    function acceptTradeByOwner(
        uint256 _askId,
        uint256 tradeId
    ) external onlyOwner {
        _acceptTrade(_askId, tradeId, owner());
    }

    function settleAskByOwner(
        uint256 _askId,
        uint16[] calldata percentages
    ) public onlyOwner checkSum(percentages) {
        _settleAsk(_askId, owner(), percentages);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Perimissioned Use.                             */
    /* -------------------------------------------------------------------------- */

    function addAsk(Ask calldata a) external onlyRoles(a.role) {
        _addAsk(false, a);
    }

    function addResource(Resource calldata r) external onlyRoles(r.role) {
        _addResource(false, r);
    }

    /// target `askId`
    /// proposed `Trade`
    function addTrade(uint256 id, Trade calldata t) external {
        // Check if `Ask` is fulfilled.
        if (asks[id].fulfilled) revert InvalidTrade();

        // Check if owner of `t.subject` is from `msg.sender`.
        (address sBulletin, uint256 sResourceId) = decodeSubject(t.subject);
        Resource memory r = IBulletin(sBulletin).getResource(sResourceId);
        if (r.owner != msg.sender) revert InvalidOwner();

        uint256 _tradeId;
        unchecked {
            _tradeId = ++tradeIds[id];
        }

        trades[id][_tradeId] = Trade({
            accepted: false,
            timestamp: uint40(block.timestamp),
            subject: t.subject,
            feedback: t.feedback,
            data: t.data
        });
    }

    function acceptTrade(uint256 _askId, uint256 tradeId) external {
        _acceptTrade(_askId, tradeId, msg.sender);
    }

    function settleAsk(
        uint256 _askId,
        uint16[] calldata percentages
    ) public checkSum(percentages) {
        _settleAsk(_askId, msg.sender, percentages);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _addAsk(bool isOwner, Ask calldata a) internal {
        unchecked {
            ++askId;
        }

        asks[askId] = Ask({
            fulfilled: false,
            role: isOwner ? uint40(uint256(_OWNER_SLOT)) : a.role,
            owner: isOwner ? owner() : a.owner,
            title: a.title,
            detail: a.detail,
            currency: a.currency,
            drop: a.drop
        });
    }

    function _addResource(bool isOwner, Resource calldata r) internal {
        unchecked {
            ++resourceId;
        }

        resources[askId] = Resource({
            role: isOwner ? uint40(uint256(_OWNER_SLOT)) : r.role,
            expiry: r.expiry,
            owner: isOwner ? owner() : r.owner,
            title: r.title,
            detail: r.detail
        });
    }

    function _acceptTrade(uint256 id, uint256 tradeId, address owner) internal {
        // Check resource ownership.
        if (asks[id].owner != owner) revert InvalidOwner();

        // Check if `Ask` is fulfilled.
        if (asks[id].fulfilled) revert InvalidTrade();

        // Accept trade.
        trades[id][tradeId].accepted = true;
        trades[id][tradeId].timestamp = uint40(block.timestamp);
    }

    function _settleAsk(
        uint256 id,
        address owner,
        uint16[] calldata percentages
    ) internal {
        // Throw when owners mismatch.
        Ask memory a = asks[id];
        if (a.owner != owner) revert InvalidOwner();

        // Tally and retrieve accepted trades.
        (uint256 accepted, Trade[] memory t) = tallyAcceptedTrades(id);

        // Throw when percentages provide do not match number of accepted trades.
        if (accepted != percentages.length) revert InvalidSettlement();

        // Commence distribution.
        Resource memory r;
        for (uint256 i; i < accepted; ++i) {
            (address sBulletin, uint256 sResourceId) = decodeSubject(
                t[i].subject
            );
            r = IBulletin(sBulletin).getResource(sResourceId);

            route(
                a.currency,
                address(this),
                r.owner,
                (a.drop * percentages[i]) / TEN_THOUSAND
            );
        }

        // Record settlement.
        asks[id].fulfilled = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helper.                                  */
    /* -------------------------------------------------------------------------- */

    function tallyAcceptedTrades(
        uint256 id
    ) public view returns (uint256 accepted, Trade[] memory t) {}

    function decodeSubject(
        bytes32 subject
    ) public pure returns (address bulletin, uint256 id) {
        assembly {
            id := subject
            bulletin := shr(128, subject)
        }
    }

    function getAsk(uint256 id) external view returns (Ask memory a) {
        return asks[id];
    }

    function getResource(uint256 id) external view returns (Resource memory r) {
        return resources[id];
    }

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory t) {
        return trades[id][tradeId];
    }

    /// @dev Helper function to route Ether and ERC20 tokens.
    function route(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (currency == address(0)) {
            SafeTransferLib.safeTransferETH(to, amount);
        } else {
            SafeTransferLib.safeTransferFrom(currency, from, to, amount);
        }
    }

    receive() external payable virtual {}
}
