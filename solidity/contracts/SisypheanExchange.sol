pragma solidity 0.8.30;

import './Reporting.sol';
import './ForkedERC1155.sol';
import './Constants.sol';
import './ISisypheanExchange.sol';
import './ReputationToken.sol';

contract SisypheanExchange is ForkedERC1155 {

	struct Universe {
		ERC20 reputationToken;
		uint256 forkingMarket;
		uint256 ethBalance;
	}

	mapping(uint256 => Universe) public universes;

	// TODO Market metadata (non reporting data) should be mapped from base market id seperately with origin universe stored as well
	struct MarketData {
		uint256 endTime;
		address designatedReporter;
		string extraInfo;
		address initialReporter;
		uint256 outcome;
		uint256 reportTime;
	}

	mapping(uint256 => MarketData) public markets;
	uint256 marketIdCounter = 0;

	// TODO: Revist what behavior the bond should be
	uint256 constant public REP_BOND = 1 ether;

	uint256 constant public DESIGNATED_REPORTING_TIME = 1 days;
	uint256 constant public DISPUTE_PERIOD = 1 days;

	constructor() {
		universes[0] = Universe(
			ERC20(Constants.GENESIS_REPUTATION_TOKEN),
			0,
			0
		);
	}

	function deposit(uint256 _universeId, address _recipient) public payable {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		// TODO: Post Auction this isn't correct. 1:1 Cath to ETH cannot be assumed as auctions do not ensure equal balances of Cash and ETH
		_mint(_recipient, _universeId, msg.value);
		universe.ethBalance += msg.value;
		universes[_universeId] = universe;
	}

	function withdraw(uint256 _universeId, address _owner, address _recipient, uint256 _amount) public {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval for 3rd party withdraw");
		// TODO: Post Auction this isn't correct. 1:1 Cath to ETH cannot be assumed as auctions do not ensure equal balances of Cash and ETH
		_burn(_owner, _universeId, _amount);
		(bool success, bytes memory data) = _recipient.call{value: _amount}("");
		require(success, "Failed to send Ether");
		universe.ethBalance -= _amount;
		universes[_universeId] = universe;
	}

	function createMarket(uint256 _universeId, uint256 _endTime, address _designatedReporterAddress, string memory _extraInfo) public returns (uint256 _newMarket) {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		universe.reputationToken.transferFrom(msg.sender, address(this), REP_BOND);
		uint256 _marketId = uint256(bytes32(abi.encodePacked(uint128(_universeId), uint128(++marketIdCounter))));
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
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		MarketData memory marketData = markets[_marketId];
		require(marketData.reportTime == 0, "Market already has a report");
		require(_outcome < 3, "Invalid outcome");
		require(block.timestamp > marketData.endTime, "Market has not ended");
		require(msg.sender == marketData.designatedReporter || block.timestamp > marketData.endTime + DESIGNATED_REPORTING_TIME, "Reporter must be designated reporter");

		markets[_marketId].initialReporter = msg.sender;
		markets[_marketId].outcome = _outcome;
		markets[_marketId].reportTime = block.timestamp;
	}

	// TODO: Handle REP staked in escalation game after fork
	function returnRepBond(uint256 _marketId) external {
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);
		Universe memory universe = universes[_universeId];
		MarketData memory marketData = markets[_marketId];
		require(isFinalized(_marketId), "Cannot withdraw REP bond before finalized");

		universe.reputationToken.transfer(marketData.initialReporter, REP_BOND);
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

	// TODO: Currently escalation game is a single dispute. Likely will be more complex.
	function dispute(uint256 _marketId, uint256 _outcome) external {
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		MarketData memory marketData = markets[_marketId];
		require(block.timestamp < marketData.reportTime + DISPUTE_PERIOD, "Market not in dispute window");
		require(_outcome < 3, "Invalid outcome");

		universe.reputationToken.transferFrom(msg.sender, address(this), REP_BOND * 2);

		for (uint256 i = 1; i < 4; i++) {
			uint256 childUniverseId = (_universeId << 4) + i;
			universes[childUniverseId] = Universe(
				new ReputationToken(),
				0,
				0
			);
		}

		universe.forkingMarket = _marketId;
		universes[_universeId] = universe;
	}
}
