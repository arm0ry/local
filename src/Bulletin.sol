// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title List
/// @notice A database management system to store lists of items.
/// @author audsssy.eth
contract Bulletin is OwnableRoles, IBulletin {
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
        // Add up all percentages.
        uint256 totalPercentage;
        for (uint256 i; i < p.length; ++i) {
            totalPercentage += p[i];
        }

        // Throw when total percentage does not equal to TEN_THOUSAND.
        if (totalPercentage != TEN_THOUSAND) revert InvalidTotalPercentage();

        // Otherwise, continue.
        _;
    }
    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address owner) public {
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

        // Check if owner of `t.resource` is from `msg.sender`.
        if (getResourceOwner(t.resource) != msg.sender) revert InvalidOwner();

        uint256 _tradeId;
        unchecked {
            _tradeId = ++tradeIds[id];
        }

        trades[id][_tradeId] = Trade({
            accepted: false,
            timestamp: uint40(block.timestamp),
            resource: t.resource,
            feedback: t.feedback,
            data: t.data
        });

        emit TradeAdded(id, t.resource);
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

        emit AskAdded(askId);
    }

    function _addResource(bool isOwner, Resource calldata r) internal {
        unchecked {
            ++resourceId;
        }

        resources[resourceId] = Resource({
            role: isOwner ? uint40(uint256(_OWNER_SLOT)) : r.role,
            expiry: r.expiry,
            owner: isOwner ? owner() : r.owner,
            title: r.title,
            detail: r.detail
        });

        emit ResourceAdded(resourceId);
    }

    function _acceptTrade(uint256 id, uint256 tradeId, address owner) internal {
        // Check resource ownership.
        if (asks[id].owner != owner) revert InvalidOwner();

        // Check if `Ask` is fulfilled.
        if (asks[id].fulfilled) revert InvalidTrade();

        // Accept trade.
        trades[id][tradeId].accepted = true;
        trades[id][tradeId].timestamp = uint40(block.timestamp);

        emit TradeAccepted(id);
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
        Trade[] memory _trades = filterTrades(id, bytes32("accepted"), 0);
        uint256 length = _trades.length;

        // Throw when number of percentages does not match number of accepted trades.
        if (length != percentages.length) revert TradeSettlementMismatch();

        // Commence distribution.
        Resource memory r;
        for (uint256 i; i < length; ++i) {
            // Pay resource owner.
            route(
                a.currency,
                address(this),
                getResourceOwner(_trades[i].resource),
                (a.drop * percentages[i]) / TEN_THOUSAND
            );
        }

        // Mark ask as fulfilled.
        asks[id].fulfilled = true;

        emit AskSettled(id, length);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helper.                                  */
    /* -------------------------------------------------------------------------- */

    function filterTrades(
        uint256 id,
        bytes32 key,
        uint40 time
    ) public view returns (Trade[] memory _trades) {
        // Declare for use.
        Trade memory t;
        bytes32 accepted = "accepted";
        bytes32 timestamp = "timestamp";

        // Retrieve trade id.
        uint256 tId = tradeIds[id];

        // If trade exists, filter and return trades based on provided `key`.
        if (tId > 0) {
            for (uint256 i = 1; i <= tId; ++i) {
                // Retrieve trade.
                t = trades[id][i];

                if (key == accepted) {
                    (t.accepted) ? _trades[i - 1] = t : t;
                } else if (key == timestamp) {
                    (time > t.timestamp) ? _trades[i - 1] = t : t;
                } else {
                    t;
                }
            }
        }
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

    // Encode.
    function encodeResource(
        address _bulletin,
        uint256 _resourceId
    ) public pure returns (bytes32 resource) {
        resource = bytes32(abi.encodePacked(_bulletin, _resourceId));
    }

    function decodeResource(
        bytes32 resource
    ) public pure returns (address _bulletin, uint256 _resourceId) {
        assembly {
            _resourceId := resource
            _bulletin := shr(128, resource)
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Public Get.                                */
    /* -------------------------------------------------------------------------- */

    function getAsk(uint256 id) external view returns (Ask memory a) {
        return asks[id];
    }

    function getResource(uint256 id) external view returns (Resource memory r) {
        return resources[id];
    }

    function getResourceOwner(
        bytes32 resource
    ) public view returns (address owner) {
        (address _bulletin, uint256 _resourceId) = decodeResource(resource);
        Resource memory r = IBulletin(_bulletin).getResource(_resourceId);
        owner = r.owner;
    }

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory t) {
        return trades[id][tradeId];
    }

    receive() external payable virtual {}
}
