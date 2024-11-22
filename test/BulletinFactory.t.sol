// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinFactory} from "src/BulletinFactory.sol";
import {Bulletin} from "src/Bulletin.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinFactoryTest is Test {
    address payable addr;
    BulletinFactory factory;
    Bulletin bulletin;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");

    /// @dev Mock Data.
    bytes32 TEST = "TEST";

    function setUp() public payable {
        bulletin = new Bulletin();
        factory = new BulletinFactory(address(bulletin));
    }

    function testDeploy() public payable {
        uint256 id = factory.bulletinId();
        vm.prank(alice);
        address deployed = factory.deployBulletin(TEST);
        uint256 id_ = factory.bulletinId();
        address deployed_ = factory.bulletins(id_);
        bulletin = Bulletin(payable(deployed_));
        assertEq(id + 1, id_);
        assertEq(deployed_, deployed);
        assertEq(bulletin.owner(), alice);
    }

    function testDetermination() public payable {
        addr = payable(factory.determineBulletin(TEST));
        bulletin = Bulletin(addr);

        vm.prank(alice);
        factory.deployBulletin(TEST);
        assertEq(address(bulletin), addr);
        assertEq(bulletin.owner(), alice);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(factory).call{value: 5 ether}("");
        assert(!sent);
    }
}
