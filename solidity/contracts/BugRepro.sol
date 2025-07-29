pragma solidity 0.8.30;

contract BugRepro {

    mapping (uint256 => mapping(address => uint256)) public _balances;

	bool public set = false;

	function one() external payable {
		_balances[0][msg.sender] = 1;
		_balances[1][msg.sender] = 1;
		_balances[2][msg.sender] = 1;
		_balances[3][msg.sender] = 1;
	}

	function two() external {
		_balances[0][msg.sender] = 0;
		_balances[1][msg.sender] = 0;
		_balances[2][msg.sender] = 0;
		_balances[3][msg.sender] = 0;
		set = true;

		// NOTE: Uncommenting these will make future transactions fail due to lack of ETH to pay gas somehow despite overriding state to give them enormous amounts of eth
		// _balances[4][msg.sender] = 1;
		// _balances[5][msg.sender] = 1;
		// _balances[6][msg.sender] = 1;

		(bool success, bytes memory data) = msg.sender.call{value: address(this).balance}("");
		// NOTE: commenting out the following line will fix the bug somehow despite this require not seeming to actually raise an error
		require(success, "Failed to send Ether");
	}

	function three(address addr) external view returns (uint256) {
		return _balances[0][addr];
	}
}
