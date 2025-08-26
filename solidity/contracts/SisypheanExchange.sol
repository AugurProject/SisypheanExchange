pragma solidity 0.8.30;

import './Reporting.sol';
import './ForkedERC1155.sol';
import './Constants.sol';
import './ISisypheanExchange.sol';
import './ReputationToken.sol';
import './IERC20.sol';

// NOTE: Currently a resolved market could be traded on and resolved again in a child universe. We can add things to prevent this if needed.
// NOTE: We need a mechanism for having certain Cash be 1:1 while other existing cash is potentially a different ratio. Consider someone putting 1 eth into a complete set in a market and it migrating while unresolved in a fork. Post auction lets say it hit 90% fulfilment. The original complete set should provide .9 ETH in return but a new purchaser should be able to buy a complete set worth 1 ETH.

contract SisypheanExchange is ForkedERC1155 {

	struct Universe {
		IERC20 reputationToken;
		uint256 forkingMarket;
		uint256 ethBalance;
		uint256 forkTime;
		uint256 ethBalanceDelta;
	}

	mapping(uint256 => Universe) public universes;

	struct MarketData {
		uint256 endTime;
		address designatedReporter;
		string extraInfo;
		uint256 originUniverse;
	}

	struct MarketResolutionData {
		address initialReporter;
		uint256 outcome;
		uint256 reportTime;
	}

	mapping(uint256 => MarketData) public markets;

	// UniverseId => MarketId => Data
	mapping(uint256 => mapping(uint256 => MarketResolutionData)) marketResolutions;

	uint256 marketIdCounter = 0;

	// TODO: Revist what behavior the bond should be
	uint256 constant public REP_BOND = 1 ether;

	uint256 constant public DESIGNATED_REPORTING_TIME = 1 days;
	uint256 constant public DISPUTE_PERIOD = 1 days;
	uint256 constant public REP_MIGRATION_WINDOW = 7 days;
	uint256 constant public AUCTION_DURATION = 7 days;

	uint256 constant public AUCTION_INITIAL_DIVISOR = 1_000_000;
	uint256 constant public AUCTION_FINAL_MULTIPLIER = 1_000_000;

	constructor() {
		universes[0] = Universe(
			IERC20(Constants.GENESIS_REPUTATION_TOKEN),
			0,
			0,
			0,
			0
		);
	}

	function forked(uint256 universeId) external view returns (bool) {
		return universeHasForked(universeId);
	}

	function universeHasForked(uint256 universeId) internal override view returns (bool) {
		return universes[universeId].forkingMarket != 0;
	}

	function getUniverseId(uint256 id) internal override pure returns (uint256) {
		return id;
	}

	function getChildId(uint256, uint256 newUniverse) internal override pure returns (uint256) {
		return newUniverse;
	}

	// TODO: function to check market legitimacy in a universe. Should be required for initial reporting at minimum

	function deposit(uint256 _universeId, address _recipient) public payable {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		// TODO: Post Auction this isn't correct. 1:1 Cath to ETH cannot be assumed as auctions do not ensure equal balances of Cash and ETH
		_mint(_recipient, _universeId, msg.value);
		universe.ethBalance += msg.value;
		universes[_universeId] = universe;
	}

	// TODO: withdraw should be allowed in forked universe for resolved markets. Market resolution should burn the CASH and issue the holder a different balance in some "resolved cash" token
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
		uint256 _marketId = ++marketIdCounter;
		markets[_marketId] = MarketData(
			_endTime,
			_designatedReporterAddress,
			_extraInfo,
			_universeId
		);
		return _newMarket;
	}

	function reportOutcome(uint256 _universeId, uint256 _marketId, uint256 _outcome) external {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		MarketData memory marketData = markets[_marketId];
		MarketResolutionData memory marketResolutionData = marketResolutions[_universeId][_marketId];
		require(marketResolutionData.reportTime == 0, "Market already has a report");
		require(_outcome < 3, "Invalid outcome");
		require(block.timestamp > marketData.endTime, "Market has not ended");
		require(msg.sender == marketData.designatedReporter || block.timestamp > marketData.endTime + DESIGNATED_REPORTING_TIME, "Reporter must be designated reporter");

		marketResolutions[_universeId][_marketId].initialReporter = msg.sender;
		marketResolutions[_universeId][_marketId].outcome = _outcome;
		marketResolutions[_universeId][_marketId].reportTime = block.timestamp;
	}

	// TODO: Handle REP staked in escalation game after fork
	function returnRepBond(uint256 _universeId, uint256 _marketId) external {
		Universe memory universe = universes[_universeId];
		MarketResolutionData memory marketResolutionData = marketResolutions[_universeId][_marketId];
		require(marketResolutionDataIsFinalized(marketResolutionData), "Cannot withdraw REP bond before finalized");

		universe.reputationToken.transfer(marketResolutionData.initialReporter, REP_BOND);
	}

	function isFinalized(uint256 _universeId, uint256 _marketId) external view returns (bool) {
		MarketResolutionData memory marketResolutionData = marketResolutions[_universeId][_marketId];
		return marketResolutionDataIsFinalized(marketResolutionData);
	}

	function marketResolutionDataIsFinalized(MarketResolutionData memory marketResolutionData) internal view returns (bool) {
		return marketResolutionData.reportTime != 0 && block.timestamp > marketResolutionData.reportTime + DISPUTE_PERIOD;
	}

	function getWinningOutcome(uint256 _universeId, uint256 _marketId) public view returns (uint256) {
		MarketResolutionData memory marketResolutionData = marketResolutions[_universeId][_marketId];
		require(marketResolutionDataIsFinalized(marketResolutionData), "Market is not finalized");

		return marketResolutionData.outcome;
	}

	// TODO: Currently escalation game is a single dispute. Likely will be more complex.
	function dispute(uint256 _universeId, uint256 _marketId, uint256 _outcome) external {
		Universe memory universe = universes[_universeId];
		require(universe.forkingMarket == 0, "Universe is forked");
		MarketResolutionData memory marketResolutionData = marketResolutions[_universeId][_marketId];
		require(block.timestamp < marketResolutionData.reportTime + DISPUTE_PERIOD, "Market not in dispute window");
		require(_outcome < 3, "Invalid outcome");

		universe.reputationToken.transferFrom(msg.sender, address(this), REP_BOND * 2);

		for (uint256 i = 1; i < 4; i++) {
			uint256 childUniverseId = (_universeId << 4) + i;
			universes[childUniverseId] = Universe(
				new ReputationToken(),
				0,
				0,
				0,
				universe.ethBalance
			);
		}

		// TODO resolve each in respective universe

		universe.forkingMarket = _marketId;
		universe.forkTime = block.timestamp;
		universes[_universeId] = universe;
	}

	function migrateREP(uint256 universeId, uint256 amount, uint256 outcome) external {
		require(outcome < 3, "Invalid outcome");
		Universe memory universe = universes[universeId];
		require(block.timestamp < universe.forkTime + REP_MIGRATION_WINDOW, "Universe not in REP migration window");

		uint256 softBurnedREP = universe.reputationToken.balanceOf(Constants.BURN_ADDRESS);
		uint256 correspondingETH = amount * universe.ethBalance / (universe.reputationToken.totalSupply() - softBurnedREP);

		// Genesis is using REPv2 which we cannot actually burn
		if (universeId == 0) {
			universe.reputationToken.transferFrom(msg.sender, Constants.BURN_ADDRESS, amount);
		} else {
			ReputationToken(address(universe.reputationToken)).burn(msg.sender, amount);
		}

		uint256 childUniverseId = (universeId << 4) + outcome + 1;
		Universe memory childUniverse = universes[childUniverseId];
		ReputationToken(address(childUniverse.reputationToken)).mint(msg.sender, amount);

		universe.ethBalance -= correspondingETH;
		childUniverse.ethBalance += correspondingETH;
		childUniverse.ethBalanceDelta -= correspondingETH;
		universes[universeId] = universe;
		universes[childUniverseId] = childUniverse;
	}

	function cashInREP(uint256 universeId) external {
		Universe memory universe = universes[universeId];
		require(universe.forkTime !=0 && block.timestamp > universe.forkTime + REP_MIGRATION_WINDOW, "Universe has not completed REP migration");

		uint256 amount = universe.reputationToken.balanceOf(msg.sender);

		uint256 softBurnedREP = universe.reputationToken.balanceOf(Constants.BURN_ADDRESS);
		uint256 correspondingETH = amount * universe.ethBalance / (universe.reputationToken.totalSupply() - softBurnedREP);

		// Genesis is using REPv2 which we cannot actually burn
		if (universeId == 0) {
			universe.reputationToken.transferFrom(msg.sender, Constants.BURN_ADDRESS, amount);
		} else {
			ReputationToken(address(universe.reputationToken)).burn(msg.sender, amount);
		}

		(bool success, bytes memory data) = msg.sender.call{value: correspondingETH}("");
		require(success, "Failed to send Ether");
		universe.ethBalance -= correspondingETH;
		universes[universeId] = universe;
	}

	function buyFromAuction(uint256 forkingUniverseId, uint256 outcome) external payable {
		Universe memory forkingUniverse = universes[forkingUniverseId];
		uint256 migrationEndTime = forkingUniverse.forkTime + REP_MIGRATION_WINDOW;
		uint256 auctionEndTime = migrationEndTime + AUCTION_DURATION;
		require(block.timestamp > migrationEndTime, "Universe still in REP migration window");
		require(block.timestamp < auctionEndTime, "Universe not in Auction window");

		uint256 childUniverseId = (forkingUniverseId << 4) + outcome + 1;
		Universe memory childUniverse = universes[childUniverseId];

		require(childUniverse.ethBalance > 0, "Auction complete");
		require(msg.value == childUniverse.ethBalanceDelta, "ETH not sufficient to buy auction REP");

		uint256 auctionTimePassed = block.timestamp - migrationEndTime;
		uint256 childREPSupply = childUniverse.reputationToken.totalSupply();
		uint256 repAmount = auctionTimePassed * (childREPSupply * AUCTION_FINAL_MULTIPLIER - childREPSupply / AUCTION_INITIAL_DIVISOR);

		ReputationToken(address(childUniverse.reputationToken)).mint(msg.sender, repAmount);

		childUniverse.ethBalance += msg.value;
		childUniverse.ethBalanceDelta = 0;
		universes[childUniverseId] = childUniverse;
	}
}
