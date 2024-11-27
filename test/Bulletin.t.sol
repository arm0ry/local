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
    string TEST2 = "TEST2";
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));
    uint256 defaultBulletinBalance = 10 ether;

    uint256[] itemIds;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);

        mock = new MockERC20(TEST, TEST, 18);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(bulletin).call{value: 5 ether}("");
        assert(sent);
    }

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

    function grantRole(address user, uint256 role) public payable {
        vm.prank(owner);
        bulletin.grantRoles(user, role);
    }

    /// -----------------------------------------------------------------------
    /// Helpers.
    /// -----------------------------------------------------------------------

    /// @notice Ask

    function ask(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.ask(a);
        id = bulletin.askId();
    }

    function askAndDepositEther(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: amount
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.ask(a);
        id = bulletin.askId();
    }

    function askAndDepositCurrency(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: amount
        });

        mockApprove((isOwner) ? owner : user, address(bulletin), amount);

        vm.prank((isOwner) ? owner : user);
        bulletin.ask(a);
        id = bulletin.askId();
    }

    function updateAsk(
        address op,
        uint256 askId,
        IBulletin.Ask memory a
    ) public payable {
        vm.prank(op);
        bulletin.updateAsk(askId, a);
    }

    function withdrawAsk(address op, uint256 askId) public payable {
        vm.prank(op);
        bulletin.withdrawAsk(askId);
    }

    /// @notice Resource

    function resource(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Resource memory r = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: user,
            title: TEST,
            detail: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.resource(r);
        id = bulletin.resourceId();
    }

    function updateResource(
        address op,
        uint256 resourceId,
        IBulletin.Resource memory r
    ) public payable {
        vm.prank(op);
        bulletin.updateResource(resourceId, r);
    }

    function approveTrade(
        address op,
        uint256 askId,
        uint256 tradeId
    ) public payable {
        vm.prank(op);
        bulletin.approveTrade(askId, tradeId);
    }

    function rejectTrade(
        address op,
        uint256 askId,
        uint256 tradeId
    ) public payable {
        vm.prank(op);
        bulletin.rejectTrade(askId, tradeId);
    }

    function settleAsk(
        address op,
        uint256 askId,
        uint16[] memory percentages
    ) public payable {
        vm.prank(op);
        bulletin.settleAsk(askId, percentages);
    }

    function setupTrade(
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

    /// -----------------------------------------------------------------------
    /// Tests.
    /// ----------------------------------------------------------------------

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(role > 0);
        grantRole(user, role);
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
        uint256 askId = ask(true, owner);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_askAndDepositCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 askId = askAndDepositCurrency(true, owner, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), max - amount);
    }

    function test_askAndDepositEther(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(owner, max);
        uint256 askId = askAndDepositCurrency(true, owner, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(owner).balance, max - amount);
    }

    function test_askByUser(address user) public payable {
        grantRole(user, PERMISSIONED_USER);

        uint256 askId = ask(false, user);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, user);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_askAndDepositCurrencyByUser(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(user, max);
        grantRole(user, PERMISSIONED_USER);

        uint256 askId = askAndDepositCurrency(false, user, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, user);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(alice), max - amount);
    }

    function test_askAndDepositEtherByUser(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(alice, max);
        uint256 askId = askAndDepositCurrency(true, owner, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(alice).balance, max - amount);
    }

    // todo:
    function test_updateAskAndCurrency() public payable {}

    function test_updateAskAndEther() public payable {}

    function test_updateAskWithDifferentCoin() public payable {}

    function test_updateAsk_InvalidOwner() public payable {}

    function test_updateAsk_InvalidUpdate() public payable {}

    function test_withdraw() public payable {
        uint256 askId = ask(true, owner);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_withdrawAndReturnCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), max);
    }

    function test_withdrawAndReturnEther(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(owner, max);
        uint256 askId = askAndDepositEther(true, owner, amount);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(owner).balance, max);
    }

    function test_withdrawByUser(address user) public payable {
        uint256 askId = ask(false, user);

        withdrawAsk(user, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, user);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_withdrawAndReturnCurrencyByUser(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(user, max);
        vm.assume(max > amount);

        uint256 askId = askAndDepositCurrency(false, user, amount);

        withdrawAsk(user, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, user);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), max);
    }

    function test_withdrawAndReturnEtherByUser(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        vm.deal(user, max);
        vm.assume(max > amount);
        uint256 askId = askAndDepositEther(false, user, amount);

        withdrawAsk(user, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, user);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(owner).balance, max);
    }

    // todo: asserts
    function test_withdraw_InvalidOwner() public payable {}

    // todo: asserts
    function test_withdraw_InvalidWithdrawal() public payable {}

    function test_resource() public payable {
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, true);
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_updateResource() public payable {
        uint256 resourceId = resource(true, owner);

        IBulletin.Resource memory r = IBulletin.Resource({
            active: false,
            role: 0,
            owner: alice,
            title: TEST2,
            detail: TEST2
        });

        updateResource(owner, resourceId, r);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        // todo: asserts
        assertEq(_resource.active, false);
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST2);
        assertEq(_resource.detail, TEST2);
    }

    function test_resourceByUser(address user) public payable {
        grantRole(user, PERMISSIONED_USER);
        uint256 resourceId = resource(false, user);

        IBulletin.Resource memory r = IBulletin.Resource({
            active: false,
            role: PERMISSIONED_USER,
            owner: user,
            title: TEST2,
            detail: TEST2
        });

        updateResource(user, resourceId, r);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        // todo: asserts
        assertEq(_resource.active, false);
        assertEq(_resource.role, PERMISSIONED_USER);
        assertEq(_resource.owner, alice);
        assertEq(_resource.title, TEST2);
        assertEq(_resource.detail, TEST2);
    }

    function test_approveTrade(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(user, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, user);

        // grant BULLETIN role
        // grantRole(address(bulletin), BULLETIN_ROLE);

        // setup trade
        uint256 tradeId = setupTrade(
            user,
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

    function test_rejectTrade(
        address user,
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(user, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, user);

        // setup trade
        uint256 tradeId = setupTrade(
            user,
            askId,
            address(bulletin),
            resourceId
        );

        // approve trade
        approveTrade(owner, askId, tradeId);

        IBulletin.Trade memory trade = bulletin.getTrade(askId, tradeId);
        bool approved = trade.approved;

        // reject trade
        rejectTrade(owner, askId, tradeId);
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

    function test_settleAsk(
        address user,
        address user2,
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);
        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(user, PERMISSIONED_USER);
        grantRole(user2, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), BULLETIN_ROLE);

        // setup first resource
        uint256 resourceId = resource(false, user);

        // setup first trade
        uint256 tradeId = setupTrade(
            user,
            askId,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // setup second resource
        resourceId = resource(false, user2);

        // setup second trade
        tradeId = setupTrade(user2, askId, address(bulletin), resourceId);

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

    function test_addTradeByUser() public payable {
        uint256 askId = ask(true, owner);

        grantRole(alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        setupTrade(alice, askId, address(bulletin), resourceId);

        // todo: asserts
    }

    function test_incrementUsage() public payable {}

    function test_comment() public payable {}

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */
}
