pragma solidity 0.8.30;

import './ERC20.sol';

contract ReputationToken is ERC20 {

	constructor() ERC20('Reputation', 'REP') {
	}

}
