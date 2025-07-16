pragma solidity 0.8.30;


import './Reporting.sol';
import './ERC20.sol';
import './Constants.sol';

/**
* @title Universe
* @notice A Universe encapsulates a whole instance of the Sisyphean Exchange. In the event of a fork in a Universe it will split into child Universes which each represent a different version of the truth with respect to how the forking market should resolve.
*/
contract Universe is ERC20("Cash", "CASH") {

	struct MarketData {
		uint256 endTime;
		address designatedReporter;
		string extraInfo;
	}

	Universe public parentUniverse;
	uint256 public parentOutcome;
	ERC20 public reputationToken;
	mapping(uint256 => MarketData) public markets;
	mapping(uint256 => Universe) public children;
	uint256 marketIdCounter = 0;

	// TODO: Should likely fluctuate. Revist what behavior this should be
	uint256 constant public REP_BOND = 1 ether;

	constructor(Universe _parentUniverse, uint256 _parentOutcome) {
		parentUniverse = _parentUniverse;
		parentOutcome = _parentOutcome;
		// TODO: For children this should generate a new REP token
		reputationToken = ERC20(Constants.GENESIS_REPUTATION_TOKEN);
	}

	// TODO: These assume constant 1:1 currently but will not once reporting fee is implemented
	function deposit(address _recipient) public payable {
		_mint(_recipient, msg.value);
	}

	function withdraw(address _owner, address _recipient, uint256 _amount) public {
		if (_owner != msg.sender) _spendAllowance(_owner, msg.sender, _amount);
		_burn(_owner, _amount);
		(bool success, bytes memory data) = _recipient.call{value: _amount}("");
		require(success, "Failed to send Ether");
	}

	function createChildUniverse(uint256 _outcome) public returns (Universe) {
		// TODO keep ref to sysEx contract from creation and send call to create child
	}

	function createYesNoMarket(uint256 _endTime, address _designatedReporterAddress, string memory _extraInfo) public returns (uint256 _newMarket) {
		reputationToken.transferFrom(msg.sender, address(this), REP_BOND);
		// TODO: Add Universe chain to first half of ID
		uint256 _marketId = marketIdCounter++;
		markets[_marketId] = MarketData(
			_endTime,
			_designatedReporterAddress,
			_extraInfo
		);
		return _newMarket;
	}

	// TODO: Dispute / Fork logic
}
