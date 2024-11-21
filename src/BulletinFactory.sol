// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {Bulletin} from "./Bulletin.sol";
import {LibClone} from "./utils/LibClone.sol";

/// @notice Keep Factory.
contract BulletinFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(address indexed bulletin, address indexed owner);

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    address internal immutable bulletinTemplate;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _bulletinTemplate) payable {
        bulletinTemplate = _bulletinTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineBulletin(
        bytes32 name
    ) public view virtual returns (address) {
        return
            bulletinTemplate.predictDeterministicAddress(
                abi.encode(name),
                name,
                address(this)
            );
    }

    function deployBulletin(
        bytes32 name // create2 salt as used in `determineBulletin()`.
    ) public payable virtual {
        address payable bulletin = payable(
            bulletinTemplate.cloneDeterministic(abi.encode(name), name)
        );

        Bulletin(bulletin).init(msg.sender);

        emit Deployed(bulletin, msg.sender);
    }
}
