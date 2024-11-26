// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solbase/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest is Test {
    Bulletin bulletin;
    MockERC20 mock;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Roles.
    bytes32 internal constant _OWNER_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;
    uint40 public constant BULLETIN_ROLE = 1 << 1;
    uint40 public constant PERMISSIONED_USER = 2 << 1;

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    bytes constant BYTES = bytes(string("BYTES"));
    uint256 defaultBulletinBalance = 10 ether;

    uint256[] itemIds;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);

        mock = new MockERC20(TEST, TEST, 18);
        mock.mint(owner, 100 ether);
        mock.mint(alice, 100 ether);
        mock.mint(bob, 100 ether);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(bulletin).call{value: 5 ether}("");
        assert(sent);
    }

    /// -----------------------------------------------------------------------
    /// Helpers
    /// -----------------------------------------------------------------------

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin();
        bulletin.init(user);
        assertEq(bulletin.owner(), user);
    }

    function mockApprove(
        address approver,
        address spender,
        uint256 amount
    ) public payable {
        vm.prank(approver);
        mock.approve(spender, amount);
    }

    function grantRoleByOwner(address user, uint256 role) public payable {
        vm.prank(owner);
        bulletin.grantRoles(user, role);
    }

    function askByOwner() public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: alice,
            role: 0,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank(owner);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function askAndDropEtherByOwner() public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: alice,
            role: 0,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 1 ether
        });

        vm.prank(owner);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function askAndDropCurrencyByOwner() public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: alice,
            role: 0,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: 1 ether
        });
        mockApprove(owner, address(bulletin), 1 ether);

        vm.prank(owner);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function resourceByOwner() public payable returns (uint256 id) {
        IBulletin.Resource memory resource = IBulletin.Resource({
            active: true,
            role: 0,
            owner: alice,
            title: TEST,
            detail: TEST
        });

        vm.prank(owner);
        bulletin.resource(resource);
        id = bulletin.resourceId();
    }

    function approveTrade(
        address user,
        uint256 askId,
        uint256 tradeId
    ) public payable {
        vm.prank(user);
        bulletin.approveTrade(askId, tradeId);
    }

    function settleAsk(
        address op,
        uint256 askId,
        uint16[] memory percentages
    ) public payable {
        vm.prank(op);
        bulletin.settleAsk(askId, percentages);
    }

    function askByUser(address user) public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank(user);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function askAndDropEtherByUser(
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 1 ether
        });

        vm.prank(user);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function askAndDropCurrencyByUser(
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: 1 ether
        });
        mockApprove(user, address(bulletin), 1 ether);

        vm.prank(user);
        bulletin.ask(ask);
        id = bulletin.askId();
    }

    function resourceByUser(address user) public payable returns (uint256 id) {
        IBulletin.Resource memory resource = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: user,
            title: TEST,
            detail: TEST
        });

        vm.prank(user);
        bulletin.resource(resource);
        id = bulletin.resourceId();
    }

    function setupTradeByUser(
        address user,
        uint256 askId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            timestamp: 0,
            resource: bulletin.encodeAsset(
                address(userBulletin),
                uint96(userResourceId)
            ),
            feedback: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(askId, trade);
        id = bulletin.tradeIds(askId);
    }

    function acceptTradeByUser(uint256 askId, uint256 tradeId) public payable {}

    function settleAskByUser() public payable {}

    /// -----------------------------------------------------------------------
    /// Owner Functions.
    /// ----------------------------------------------------------------------

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(role > 0);
        grantRoleByOwner(user, role);
        assertEq(bulletin.hasAnyRole(user, role), true);
    }

    function test_GrantRoles_NotOwner(
        address user,
        uint256 role
    ) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.grantRoles(user, role);
    }

    function test_ask() public payable {
        uint256 askId = askAndDropCurrencyByOwner();
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, 1 ether);
    }

    function test_resource() public payable {
        uint256 resourceId = resourceByOwner();
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, true);
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_approveTrade() public payable {
        // setup ask
        uint256 askId = askAndDropCurrencyByOwner();

        // grant PERMISSIONED role
        grantRoleByOwner(alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resourceByUser(alice);

        // grant BULLETIN role
        grantRoleByOwner(address(bulletin), BULLETIN_ROLE);

        // setup trade
        uint256 tradeId = setupTradeByUser(
            alice,
            askId,
            address(bulletin),
            resourceId
        );
        IBulletin.Trade memory trade = bulletin.getTrade(askId, tradeId);
        bool approved = trade.approved;

        // approve trade
        approveTrade(owner, askId, tradeId);
        trade = bulletin.getTrade(askId, tradeId);

        assertEq(trade.approved, !approved);
        assertEq(trade.timestamp, block.timestamp);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(trade.feedback, TEST);
        assertEq(trade.data, BYTES);
    }

    function test_approveTrade_InvalidOwner(
        uint256 _askId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.InvalidOwner.selector);
        bulletin.approveTrade(_askId, _tradeId);
    }

    function test_approveTrade_NothingToTrade(uint256 _tradeId) public payable {
        test_ask();
        uint256 askId = bulletin.askId();

        vm.prank(owner);
        vm.expectRevert(IBulletin.NothingToTrade.selector);
        bulletin.approveTrade(askId, _tradeId);
    }

    function test_settleAsk() public payable {
        // setup ask
        uint256 askId = askAndDropCurrencyByOwner();

        // grant PERMISSIONED role
        grantRoleByOwner(alice, PERMISSIONED_USER);
        grantRoleByOwner(bob, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRoleByOwner(address(bulletin), BULLETIN_ROLE);

        // setup first resource
        uint256 resourceId = resourceByUser(alice);

        // setup first trade
        uint256 tradeId = setupTradeByUser(
            alice,
            askId,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // setup second resource
        resourceId = resourceByUser(bob);

        // setup second trade
        tradeId = setupTradeByUser(bob, askId, address(bulletin), resourceId);

        // approve second trade
        approveTrade(owner, askId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleAsk(owner, askId, perc);

        // TODO: asserts
    }

    /// -----------------------------------------------------------------------
    /// Permissioned Functions.
    /// ----------------------------------------------------------------------

    function test_askByUser() public payable {
        grantRoleByOwner(alice, PERMISSIONED_USER);

        uint256 askId = askAndDropCurrencyByUser(alice);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, 1 ether);
    }

    function test_resourceByUser() public payable {
        grantRoleByOwner(alice, PERMISSIONED_USER);

        uint256 resourceId = resourceByUser(alice);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, true);
        assertEq(_resource.role, PERMISSIONED_USER);
        assertEq(_resource.owner, alice);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_addTradeByUser() public payable {
        uint256 askId = askByOwner();

        grantRoleByOwner(alice, PERMISSIONED_USER);
        uint256 resourceId = resourceByUser(alice);

        setupTradeByUser(alice, askId, address(bulletin), resourceId);
    }

    function test_incrementUsage() public payable {}

    function test_comment() public payable {}

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */
}
