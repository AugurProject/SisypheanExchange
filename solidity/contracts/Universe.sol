pragma solidity 0.8.30;


import './Reporting.sol';
import './ERC20.sol';
import './Constants.sol';
import './ISisypheanExchange.sol';
import './ReputationToken.sol';

/**
* @title Universe
* @notice A Universe encapsulates a whole instance of the Sisyphean Exchange. In the event of a fork in a Universe it will split into child Universes which each represent a different version of the truth with respect to how the forking market should resolve.
*/
contract Universe is ERC20("Cash", "CASH") {

	struct MarketData {
		uint256 endTime;
		address designatedReporter;
		string extraInfo;
		address initialReporter;
		uint256 outcome;
		uint256 reportTime;
	}

	ISisypheanExchange public sisypheanExchange;
	Universe public parentUniverse;
	uint256 public parentOutcome;
	uint256 public universeId;
	ERC20 public reputationToken;
	mapping(uint256 => MarketData) public markets;
	mapping(uint256 => Universe) public children;
	uint256 marketIdCounter = 0;
	bool forked = false;

	// TODO: Revist what behavior the bond should be
	uint256 constant public REP_BOND = 1 ether;

	uint256 constant public DESIGNATED_REPORTING_TIME = 1 days;
	uint256 constant public DISPUTE_PERIOD = 1 days;

	constructor(Universe _parentUniverse, uint256 _parentOutcome) {
		sisypheanExchange = ISisypheanExchange(msg.sender);
		parentUniverse = _parentUniverse;
		parentOutcome = _parentOutcome;
		bool isGenesis = _parentUniverse == Universe(address(0));
		universeId = isGenesis ? 0 : _parentUniverse.universeId() << 4 + _parentOutcome;
		reputationToken = isGenesis ? ERC20(Constants.GENESIS_REPUTATION_TOKEN) : new ReputationToken();
	}

	function deposit(address _recipient) public payable {
		require(!forked, "Universe is forked");
		_mint(_recipient, msg.value);
	}

	function withdraw(address _owner, address _recipient, uint256 _amount) public {
		require(!forked, "Universe is forked");
		if (_owner != msg.sender) _spendAllowance(_owner, msg.sender, _amount);
		_burn(_owner, _amount);
		(bool success, bytes memory data) = _recipient.call{value: _amount}("");
		require(success, "Failed to send Ether");
	}

	function createMarket(uint256 _endTime, address _designatedReporterAddress, string memory _extraInfo) public returns (uint256 _newMarket) {
		require(!forked, "Universe is forked");
		reputationToken.transferFrom(msg.sender, address(this), REP_BOND);
		uint256 _marketId = uint256(bytes32(abi.encodePacked(uint128(universeId), uint128(++marketIdCounter))));
		markets[_marketId] = MarketData(
			_endTime,
			_designatedReporterAddress,
			_extraInfo,
			address(0),
			0,
			0
		);
		return _newMarket;
	}

	function unpackMarketId(uint256 _marketId) internal pure returns (uint256 _universe, uint256 _market) {
		assembly {
			_universe := shr(128, and(_marketId, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000))
			_market := and(_marketId, 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
		}
	}

	function reportOutcome(uint256 _marketId, uint256 _outcome) external {
		require(!forked, "Universe is forked");
		MarketData memory marketData = markets[_marketId];
		require(marketData.reportTime == 0, "Market already has a report");
		require(children[0] == Universe(address(0)), "Universe has forked");
		require(_outcome < 3, "Invalid outcome");
		require(block.timestamp > marketData.endTime, "Market has not ended");
		require(msg.sender == marketData.designatedReporter || block.timestamp > marketData.endTime + DESIGNATED_REPORTING_TIME, "Reporter must be designated reporter");

		markets[_marketId].initialReporter = msg.sender;
		markets[_marketId].outcome = _outcome;
		markets[_marketId].reportTime = block.timestamp;
	}

	// TODO: Handle REP staked in escalation game after fork
	function returnRepBond(uint256 _marketId) external {
		MarketData memory marketData = markets[_marketId];
		require(isFinalized(_marketId), "Cannot withdraw REP bond before finalized");

		reputationToken.transfer(marketData.initialReporter, REP_BOND);
	}

	function isFinalized(uint256 _marketId) public view returns (bool) {
		MarketData memory marketData = markets[_marketId];
		return marketData.reportTime != 0 && block.timestamp > marketData.reportTime + DISPUTE_PERIOD;
	}

	function getWinningOutcome(uint256 _marketId) public view returns (uint256) {
		MarketData memory marketData = markets[_marketId];
		require(isFinalized(_marketId), "Market is not finalized");

		return marketData.outcome;
	}

	function dispute(uint256 _marketId, uint256 _outcome) external {
		require(!forked, "Universe is forked");
		MarketData memory marketData = markets[_marketId];
		require(block.timestamp < marketData.reportTime + DISPUTE_PERIOD, "Market not in dispute window");
		require(children[0] == Universe(address(0)), "Universe has forked");
		require(_outcome < 3, "Invalid outcome");

		reputationToken.transferFrom(msg.sender, address(this), REP_BOND * 2);

		sisypheanExchange.createChildUniverse(0);
		sisypheanExchange.createChildUniverse(1);
		sisypheanExchange.createChildUniverse(0);

		forked = true;
	}
}
