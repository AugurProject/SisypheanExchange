pragma solidity 0.8.30;


interface ISisypheanExchange {
	function deposit(uint192 _universeId, address _recipient) external payable returns (uint256);
	function withdraw(uint192 _universeId, address _owner, address _recipient, uint256 _amount) external;
	function isFinalized(uint192 _universeId, uint56 _marketId) external view returns (bool);
	function getWinningOutcome(uint192 _universeId, uint56 _marketId) external view returns (uint8);
	function forked(uint192 _universeId) external view returns (bool);
	function migrate(uint256 fromId) external;
	function balanceOf(address account, uint256 id) external view returns (uint256);
	function finalizeMarket(uint192 _universeId, uint56 _marketId) external returns (uint8);
}
