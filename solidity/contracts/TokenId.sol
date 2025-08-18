pragma solidity 0.8.30;

library TokenId {

	function getTokenId(uint256 _universeId, uint256 _marketId, uint256 _outcome) internal pure returns (uint256 _tokenId) {
		bytes memory _tokenIdBytes = abi.encodePacked(uint128(_universeId), uint120(_marketId), uint8(_outcome));
		assembly {
			_tokenId := mload(add(_tokenIdBytes, add(0x20, 0)))
		}
	}

	function getTokenIds(uint256 _universeId, uint256 _market, uint256[] memory _outcomes) internal pure returns (uint256[] memory _tokenIds) {
		_tokenIds = new uint256[](_outcomes.length);
		for (uint256 _i = 0; _i < _outcomes.length; _i++) {
			_tokenIds[_i] = getTokenId(_universeId, _market, _outcomes[_i]);
		}
	}

	function unpackTokenId(uint256 _tokenId) internal pure returns (uint256 _universe, uint256 _market, uint256 _outcome) {
		assembly {
			_universe := shr(128, and(_tokenId, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000))
			_market := shr(8,  and(_tokenId, 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00))
			_outcome := and(_tokenId, 0x00000000000000000000000000000000000000000000000000000000000000FF)
		}
	}
}
