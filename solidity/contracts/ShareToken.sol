pragma solidity 0.8.30;

import './IUniverse.sol';
import './Constants.sol';
import './ERC1155.sol';
import './TokenId.sol';


/**
* @title Share Token
* @notice ERC1155 contract to hold all share token balances
*/
contract ShareToken is ERC1155 {

	string constant public name = "Shares";
	string constant public symbol = "SHARE";

	function buyCompleteSets(IUniverse _universe, uint256 _market, address _account, uint256 _amount) external payable {
		uint256 _cost = _amount * Constants.NUM_TICKS;
		require(_cost == msg.value, "Sent Ether is not equal to complete set purchase cost");
		_universe.deposit{value: msg.value}(address(this));

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint256 _i = 0; _i < Constants.NUM_OUTCOMES; _i++) {
			_tokenIds[_i] = TokenId.getTokenId(_market, _i);
			_values[_i] = _amount;
		}

		_mintBatch(_account, _tokenIds, _values);
	}

	function sellCompleteSets(IUniverse _universe, uint256 _market, address _owner, address _recipient, uint256 _amount) external {
		require(_owner == msg.sender || isApprovedForAll(_owner, msg.sender) == true, "ERC1155: need operator approval to sell complete sets");

		uint256[] memory _tokenIds = new uint256[](Constants.NUM_OUTCOMES);
		uint256[] memory _values = new uint256[](Constants.NUM_OUTCOMES);

		for (uint256 i = 0; i < Constants.NUM_OUTCOMES; i++) {
			_tokenIds[i] = TokenId.getTokenId(_market, i);
			_values[i] = _amount;
		}

		_burnBatch(_owner, _tokenIds, _values);
		_universe.withdraw(_owner, _recipient, _amount);
	}

	function claimTradingProceeds(IUniverse _universe, uint256 _market, address _owner, address _recipient) external {
		// TODO require market finalized
		// TODO burn _owners winning share token balance
		// TODO send proceeds to recipient
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
}
