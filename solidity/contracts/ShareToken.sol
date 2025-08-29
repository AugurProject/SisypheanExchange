pragma solidity 0.8.30;

import './Constants.sol';
import './ForkedERC1155.sol';
import './TokenId.sol';
import './ISisypheanExchange.sol';

/**
* @title Share Token
* @notice ERC1155 contract to hold all share token balances
*/
contract ShareToken is ForkedERC1155 {

	string constant public name = "Shares";
	string constant public symbol = "SHARE";
	ISisypheanExchange public sisypheanExchange;

	constructor(ISisypheanExchange _sisypheanExchange) {
		sisypheanExchange = _sisypheanExchange;
	}

	function universeHasForked(uint192 universeId) internal override view returns (bool) {
		return sisypheanExchange.forked(universeId);
	}

	function getUniverseId(uint256 id) internal override pure returns (uint192 universeId) {
		assembly {
			universeId := shr(64, and(id, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000))
		}
	}

	function getChildId(uint256 originalId, uint192 newUniverse) internal override pure returns (uint256 newId) {
		assembly {
			newId := or(shr(192, shl(192, originalId)), shl(64, newUniverse))
		}
	}

	function migrateCash(uint192 fromUniverseId) external {
		sisypheanExchange.migrate(fromUniverseId);
	}

	function buyCompleteSets(uint192 _universeId, uint56 _marketId, address _account, uint256 _amount) external payable {
		uint256 _cost = _amount * Constants.NUM_TICKS;
		require(_cost == msg.value, "Sent Ether is not equal to complete set purchase cost");
		uint256 correspondingCash = sisypheanExchange.deposit{value: msg.value}(_universeId, address(this));

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint8 _i = 0; _i < Constants.NUM_OUTCOMES; _i++) {
			_tokenIds[_i] = TokenId.getTokenId(_universeId, _marketId, _i);
			_values[_i] = correspondingCash / Constants.NUM_TICKS;
		}

		_mintBatch(_account, _tokenIds, _values);
	}

	function sellCompleteSets(uint192 _universeId, uint56 _marketId, address _owner, address _recipient, uint256 _amount) external {
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval to sell complete sets");

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint8 i = 0; i < Constants.NUM_OUTCOMES; i++) {
			_tokenIds[i] = TokenId.getTokenId(_universeId, _marketId, i);
			_values[i] = _amount;
		}

		_burnBatch(_owner, _tokenIds, _values);
		sisypheanExchange.withdraw(_universeId, address(this), _recipient, _amount * Constants.NUM_TICKS);
	}

	function claimTradingProceeds(uint192 _universeId, uint56 _marketId, address _owner, address _recipient) external {
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval to claim proceeds");

		uint8 _outcome = sisypheanExchange.getWinningOutcome(_universeId, _marketId);
		uint256 _tokenId = getTokenId(_universeId, _marketId, _outcome);

		uint256 _balance = balanceOf(_owner, _tokenId);
		_burn(_owner, _tokenId, _balance);

		sisypheanExchange.withdraw(_universeId, address(this), _recipient, _balance * Constants.NUM_TICKS);
	}

	function getUniverse(uint256 _tokenId) external pure returns(uint256) {
		(uint192 _universe, uint56 _market, uint8 _outcome) = TokenId.unpackTokenId(_tokenId);
		return _universe;
	}

	function getMarket(uint256 _tokenId) external pure returns(uint256) {
		(uint192 _universe, uint56 _market, uint8 _outcome) = TokenId.unpackTokenId(_tokenId);
		return _market;
	}

	function getOutcome(uint256 _tokenId) external pure returns(uint256) {
		(uint192 _universe, uint56 _market, uint8 _outcome) = TokenId.unpackTokenId(_tokenId);
		return _outcome;
	}

	function totalSupplyForMarketOutcome(uint192 _universeId, uint56 _market, uint8 _outcome) public view returns (uint256) {
		uint256 _tokenId = getTokenId(_universeId, _market, _outcome);
		return totalSupply(_tokenId);
	}

	function balanceOfMarketOutcome(uint192 _universeId, uint56 _market, uint8 _outcome, address _account) public view returns (uint256) {
		uint256 _tokenId = getTokenId(_universeId, _market, _outcome);
		return balanceOf(_account, _tokenId);
	}

	function balanceOfMarketShares(uint192 _universeId, uint56 _market, address _account) public view returns (uint256[3] memory balances) {
		balances[0] = balanceOf(_account, getTokenId(_universeId, _market, 0));
		balances[1] = balanceOf(_account, getTokenId(_universeId, _market, 1));
		balances[2] = balanceOf(_account, getTokenId(_universeId, _market, 2));
	}

	function getTokenId(uint192 _universeId, uint56 _market, uint8 _outcome) public pure returns (uint256 _tokenId) {
		return TokenId.getTokenId(_universeId, _market, _outcome);
	}

	function getTokenIds(uint192 _universeId, uint56 _market, uint8[] memory _outcomes) public pure returns (uint256[] memory _tokenIds) {
		return TokenId.getTokenIds(_universeId, _market, _outcomes);
	}

	function unpackTokenId(uint256 _tokenId) public pure returns (uint256 _universe, uint256 _market, uint256 _outcome) {
		return TokenId.unpackTokenId(_tokenId);
	}
}
