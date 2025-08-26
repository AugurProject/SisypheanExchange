pragma solidity 0.8.30;

import './ERC20.sol';
import './SisypheanExchange.sol';

contract ReputationToken is ERC20 {

	ISisypheanExchange public sisypheanExchange;

	constructor() ERC20('Reputation', 'REP') {
		sisypheanExchange = ISisypheanExchange(msg.sender);
	}

	function mint(address account, uint256 value) external {
		require(msg.sender == address(sisypheanExchange), "Not sisEx");
		_mint(account, value);
	}

	function burn(address account, uint256 value) external {
		require(msg.sender == address(sisypheanExchange), "Not sisEx");
		_burn(account, value);
	}
}
