pragma solidity 0.8.30;


interface IUniverse {
	function deposit(address _recipient) external payable;
	function withdraw(address _owner, address _recipient, uint256 _amount) external;
}
