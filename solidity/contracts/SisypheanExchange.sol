pragma solidity 0.8.30;

import './Universe.sol';

contract SisypheanExchange {

	mapping(Universe => bool) public universes;
	Universe public genesisUniverse;

	function createGenesisUniverse() external {
		require(address(genesisUniverse) == address(0), "Can only create one genesis universe");
		genesisUniverse = new Universe(Universe(address(0)), 0);
		universes[genesisUniverse] = true;
	}

	function createChildUniverse(uint256 _outcome) external {
		require(universes[Universe(msg.sender)], "Only known universes may create children");
		Universe child = new Universe(Universe(msg.sender), _outcome);
		universes[child] = true;
	}
}
