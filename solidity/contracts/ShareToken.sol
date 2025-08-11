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

	// CONSIDER: Specify sisEX address on deploy so it doesnt have to be passed everywhere

	function buyCompleteSets(ISisypheanExchange _sisypheanExchange, uint256 _marketId, address _account, uint256 _amount) external payable {
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);
		uint256 _cost = _amount * Constants.NUM_TICKS;
		require(_cost == msg.value, "Sent Ether is not equal to complete set purchase cost");
		_sisypheanExchange.deposit{value: msg.value}(_universeId, address(this));

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint256 _i = 0; _i < Constants.NUM_OUTCOMES; _i++) {
			_tokenIds[_i] = TokenId.getTokenId(_marketId, _i);
			_values[_i] = _amount;
		}

		_mintBatch(_account, _tokenIds, _values);
	}

	function sellCompleteSets(ISisypheanExchange _sisypheanExchange, uint256 _marketId, address _owner, address _recipient, uint256 _amount) external {
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval to sell complete sets");
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint256 i = 0; i < Constants.NUM_OUTCOMES; i++) {
			_tokenIds[i] = TokenId.getTokenId(_marketId, i);
			_values[i] = _amount;
		}

		_burnBatch(_owner, _tokenIds, _values);
		_sisypheanExchange.withdraw(_universeId, address(this), _recipient, _amount * Constants.NUM_TICKS);
	}

	function claimTradingProceeds(ISisypheanExchange _sisypheanExchange, uint256 _marketId, address _owner, address _recipient) external {
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval to claim proceeds");
		(uint256 _universeId, uint256 _market) = unpackMarketId(_marketId);

		uint256 _outcome = _sisypheanExchange.getWinningOutcome(_marketId);
		uint256 _tokenId = getTokenId(_marketId, _outcome);

		uint256 _balance = balanceOf(_owner, _tokenId);
		_burn(_owner, _tokenId, _balance);

		_sisypheanExchange.withdraw(_universeId, address(this), _recipient, _balance * Constants.NUM_TICKS);
	}

	function getMarket(uint256 _tokenId) external pure returns(uint256) {
		(uint256 _market, uint256 _outcome) = TokenId.unpackTokenId(_tokenId);
		return _market;
	}

	function getOutcome(uint256 _tokenId) external pure returns(uint256) {
		(uint256 _market, uint256 _outcome) = TokenId.unpackTokenId(_tokenId);
		return _outcome;
	}

	function totalSupplyForMarketOutcome(uint256 _market, uint256 _outcome) public view returns (uint256) {
		uint256 _tokenId = getTokenId(_market, _outcome);
		return totalSupply(_tokenId);
	}

	function balanceOfMarketOutcome(uint256 _market, uint256 _outcome, address _account) public view returns (uint256) {
		uint256 _tokenId = getTokenId(_market, _outcome);
		return balanceOf(_account, _tokenId);
	}

	function balanceOfMarketShares(uint256 _market, address _account) public view returns (uint256[3] memory balances) {
		balances[0] = balanceOf(_account, getTokenId(_market, 0));
		balances[1] = balanceOf(_account, getTokenId(_market, 1));
		balances[2] = balanceOf(_account, getTokenId(_market, 2));
	}

	function getTokenId(uint256 _market, uint256 _outcome) public pure returns (uint256 _tokenId) {
		return TokenId.getTokenId(_market, _outcome);
	}

	function getTokenIds(uint256 _market, uint256[] memory _outcomes) public pure returns (uint256[] memory _tokenIds) {
		return TokenId.getTokenIds(_market, _outcomes);
	}

	function unpackTokenId(uint256 _tokenId) public pure returns (uint256 _market, uint256 _outcome) {
		return TokenId.unpackTokenId(_tokenId);
	}

	function unpackMarketId(uint256 _marketId) internal pure returns (uint256 _universe, uint256 _market) {
		assembly {
			_universe := shr(128, and(_marketId, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000))
			_market := and(_marketId, 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
		}
	}
}
