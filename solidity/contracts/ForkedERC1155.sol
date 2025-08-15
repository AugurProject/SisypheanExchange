pragma solidity 0.8.30;

import './ERC1155.sol';

abstract contract ForkedERC1155 is ERC1155 {

	constructor() {}

	function universeHasForked(uint256 universeId) internal virtual view returns (bool);

	function getUniverseId(uint256 id) internal virtual pure returns (uint256);

	function getChildId(uint256 originalId, uint256 newUniverse) internal virtual pure returns (uint256);

	// Note: In the event there is a chain of forks 32+ deep where no balance has carried further down this will make the original value innaccesible
	// This would take several years and likely a malicious actor very openly burning a large amount of money to do this and a user that has ignored every previous fork so the risk is considered low enough for this to be acceptable
	function migrate(address account, uint256 fromId) internal {
		uint256 universeId = getUniverseId(fromId);
		require(universeHasForked(universeId), "Universe has not forked");

		uint256 fromIdBalance = _balances[fromId][account];
		_balances[fromId][account] = 0;
		_supplys[fromId] -= fromIdBalance;

		// For each outcome universe
		for (uint256 i = 1; i < 4; i++) {
			uint256 childUniverseId = (universeId << 4) + i;
			uint256 toId = getChildId(fromId, childUniverseId);
			_balances[toId][account] += fromIdBalance;
			_supplys[toId] += fromIdBalance;
		}
	}
}
