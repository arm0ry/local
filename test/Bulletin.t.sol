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

    function approve(
        address approver,
        address spender,
        uint256 amount
    ) public payable {
        vm.prank(approver);
        mock.approve(address(bulletin), 100 ether);
    }

    /// -----------------------------------------------------------------------
    /// Owner Functions.
    /// ----------------------------------------------------------------------

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(role > 0);
        vm.prank(owner);
        bulletin.grantRoles(user, role);

        emit log_uint(bulletin.rolesOf(user));
        assertEq(bulletin.hasAnyRole(user, role), true);
    }

    function test_GrantRoles_NotOwner(
        address user,
        uint256 role
    ) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.grantRoles(user, role);
    }

    function test_addAskByOwner(
        bool fulfilled,
        address user,
        uint40 role
    ) public payable {
        uint256 askId = askAndDropByOwner();

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, 1 ether);
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
        bulletin.addAskByOwner(ask);
        id = bulletin.askId();
    }

    function askAndDropByOwner() public payable returns (uint256 id) {
        IBulletin.Ask memory ask = IBulletin.Ask({
            fulfilled: true,
            owner: alice,
            role: 0,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: 1 ether
        });
        approve(owner, address(bulletin), 1 ether);

        vm.prank(owner);
        bulletin.addAskByOwner(ask);
        id = bulletin.askId();
    }

    function grantRoleByOwner(address user, uint256 role) public payable {
        vm.prank(owner);
        bulletin.grantRoles(user, role);
    }

    function test_addResourceByOwner(
        bool active,
        uint40 role,
        address user
    ) public payable {
        IBulletin.Resource memory resource = IBulletin.Resource({
            active: active,
            role: role,
            owner: user,
            title: TEST,
            detail: TEST
        });

        vm.prank(owner);
        bulletin.addResourceByOwner(resource);
        uint256 resourceId = bulletin.resourceId();

        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);
        assertEq(_resource.active, active);
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_acceptTradeByOwner() public payable {
        // setup ask
        uint256 askId = askAndDropByOwner();

        // grant PERMISSIONED role
        grantRoleByOwner(alice, PERMISSIONED_USER);

        // setup resource
        IBulletin.Resource memory resource = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: alice,
            title: TEST,
            detail: TEST
        });
        vm.prank(alice);
        bulletin.addResource(resource);
        uint256 resourceId = bulletin.resourceId();

        // grant BULLETIN role
        grantRoleByOwner(address(bulletin), BULLETIN_ROLE);

        // setup trade
        bytes memory data;
        IBulletin.Trade memory trade = IBulletin.Trade({
            accepted: true,
            timestamp: 0,
            resource: bulletin.encodeAsset(
                address(bulletin),
                uint96(resourceId)
            ),
            feedback: TEST,
            data: data
        });
        vm.prank(alice);
        bulletin.addTrade(askId, trade);
        uint256 tradeId = bulletin.tradeIds(askId);

        vm.prank(owner);
        bulletin.acceptTradeByOwner(askId, tradeId);
    }

    function test_acceptTradeByOwner_InvalidOwner(
        uint256 _askId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.InvalidOwner.selector);
        bulletin.acceptTradeByOwner(_askId, _tradeId);
    }

    function test_acceptTradeByOwner_NothingToTrade(
        uint256 _tradeId
    ) public payable {
        test_addAskByOwner(true, address(0), 0);
        uint256 askId = bulletin.askId();

        vm.prank(owner);
        vm.expectRevert(IBulletin.NothingToTrade.selector);
        bulletin.acceptTradeByOwner(askId, _tradeId);
    }

    function test_settleAskByOwner() public payable {}

    /// -----------------------------------------------------------------------
    /// Permissioned Functions.
    /// ----------------------------------------------------------------------

    function test_addAsk() public payable {}

    function test_addResource() public payable {}

    function test_addTrade() public payable {}

    function test_acceptTrade() public payable {}

    function test_settleAsk() public payable {}

    function test_incrementUsage() public payable {}

    function test_comment() public payable {}
}
