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

    /// The denominator for calculating distribution.
    uint16 private constant TEN_THOUSAND = 10_000;

    /// The permissioned role to call `incrementUsage()`.
    uint256 private constant BULLETIN_ROLE = 1 << 0;

    /* -------------------------------------------------------------------------- */
    /*                                  Storage.                                  */
    /* -------------------------------------------------------------------------- */

    uint40 public askId;
    uint40 public resourceId;

    // Mappings by `askId`.
    mapping(uint256 => Ask) public asks;
    mapping(uint256 => uint256) public tradeIds;
    mapping(uint256 => mapping(uint256 => Trade)) public trades; // Reciprocal events.

    // Mappings by `resourceId`.
    mapping(uint256 => Resource) public resources;
    mapping(uint256 => uint256) public usageIds;
    mapping(uint256 => mapping(uint256 => Usage)) public usages; // Reciprocal events.

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
        (address _bulletin, uint256 _resourceId) = decodeAsset(t.resource);
        Resource memory resource = IBulletin(_bulletin).getResource(
            _resourceId
        );
        if (resource.owner != msg.sender) revert InvalidOwner();

        // TODO: would below throw bc msg.sender is not owner ?
        // Grant this Bulletin a `BULLETIN_ROLE` in contributing bulletin.
        // This allows accepted trades to record usages in contributing bulletin.
        Bulletin(payable(_bulletin)).grantRoles(address(this), BULLETIN_ROLE);

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
    ) external checkSum(percentages) {
        _settleAsk(_askId, msg.sender, percentages);
    }

    // Only other Bulletins can access
    function incrementUsage(
        uint256 role,
        uint256 _resourceId,
        bytes32 ask
    ) public onlyRoles(role) {
        unchecked {
            usages[_resourceId][++usageIds[_resourceId]] = Usage({
                ask: ask,
                timestamp: uint40(block.timestamp),
                feedback: "",
                data: abi.encode(0)
            });
        }
    }

    // Users benefited from Resource can comment.
    function comment(
        uint256 _resourceId,
        uint256 _usageId,
        string calldata feedback,
        bytes calldata data
    ) public {
        // Check if user is owner of `Ask`.
        (address _bulletin, uint256 _askId) = decodeAsset(
            usages[_resourceId][_usageId].ask
        );
        Ask memory ask = IBulletin(_bulletin).getAsk(_askId);
        if (ask.owner != msg.sender) revert CannotComment();

        usages[_resourceId][_usageId].feedback = feedback;
        usages[_resourceId][_usageId].data = data;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _addAsk(bool isOwner, Ask calldata a) internal {
        // Increment ask id.
        unchecked {
            ++askId;
        }

        // Transfer currency drop to address(this).
        route(a.currency, msg.sender, address(this), a.drop);

        // Store ask.
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

    function _acceptTrade(
        uint256 _askId,
        uint256 tradeId,
        address owner
    ) internal {
        // Check resource ownership.
        if (asks[_askId].owner != owner) revert InvalidOwner();

        // Check if `Ask` is fulfilled.
        if (asks[_askId].fulfilled) revert InvalidTrade();

        // Accept trade.
        trades[_askId][tradeId].accepted = true;
        trades[_askId][tradeId].timestamp = uint40(block.timestamp);

        // Record resource usage.
        Trade memory _trade = trades[_askId][tradeId];
        (address _bulletin, uint256 _resourceId) = decodeAsset(_trade.resource);

        emit TradeAccepted(_askId);
    }

    function _settleAsk(
        uint256 _askId,
        address owner,
        uint16[] calldata percentages
    ) internal {
        // Throw when owners mismatch.
        Ask memory a = asks[_askId];
        if (a.owner != owner) revert InvalidOwner();

        // Tally and retrieve accepted trades.
        Trade[] memory _trades = filterTrades(_askId, bytes32("accepted"), 0);
        uint256 length = _trades.length;

        // Throw when number of percentages does not match number of accepted trades.
        if (length != percentages.length) revert TradeSettlementMismatch();

        address _bulletin;
        uint256 _resourceId;
        for (uint256 i; i < length; ++i) {
            // Pay resource owner.
            route(
                a.currency,
                address(this),
                getResourceOwner(_trades[i].resource),
                (a.drop * percentages[i]) / TEN_THOUSAND
            );

            // Reciprocity.
            (_bulletin, _resourceId) = decodeAsset(_trades[i].resource);
            if (
                Bulletin(payable(_bulletin)).hasAnyRole(
                    address(this),
                    BULLETIN_ROLE
                )
            ) {
                IBulletin(payable(_bulletin)).incrementUsage(
                    BULLETIN_ROLE,
                    _resourceId,
                    encodeAsset(address(this), _askId)
                );
            }
        }

        // Mark ask as fulfilled.
        asks[_askId].fulfilled = true;

        emit AskSettled(_askId, length);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    function filterTrades(
        uint256 id,
        bytes32 key,
        uint40 time
    ) public view returns (Trade[] memory _trades) {
        // Declare for use.
        Trade memory t;

        // Filter keys.
        bytes32 accepted = "accepted";
        bytes32 timestamp = "timestamp";

        // Retrieve trade id, or number of trades.
        uint256 tId = tradeIds[id];

        // If trades exist, filter and return trades based on provided `key`.
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

    // Encode bulletin address and ask/resource id as asset.
    function encodeAsset(
        address bulletin,
        uint256 id
    ) public pure returns (bytes32 asset) {
        asset = bytes32(abi.encodePacked(bulletin, id));
    }

    // Decode asset as bulletin address and ask/resource id.
    function decodeAsset(
        bytes32 asset
    ) public pure returns (address bulletin, uint256 id) {
        assembly {
            id := asset
            bulletin := shr(128, asset)
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Helpers.                             */
    /* -------------------------------------------------------------------------- */

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

    /* -------------------------------------------------------------------------- */
    /*                                 Public Get.                                */
    /* -------------------------------------------------------------------------- */

    function getAsk(uint256 id) external view returns (Ask memory a) {
        return asks[id];
    }

    function getResource(uint256 id) external view returns (Resource memory r) {
        return resources[id];
    }

    function getResource(
        bytes32 resource
    ) public view returns (Resource memory r) {
        (address _bulletin, uint256 _resourceId) = decodeAsset(resource);
        r = IBulletin(_bulletin).getResource(_resourceId);
    }

    function getResourceOwner(
        bytes32 resource
    ) public view returns (address owner) {
        (address _bulletin, uint256 _resourceId) = decodeAsset(resource);
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
