pragma solidity 0.8.30;

//TODO: This probably isn't right. Test explicitly
library TokenId {

	function getTokenId(uint256 _market, uint256 _outcome) internal pure returns (uint256 _tokenId) {
		bytes memory _tokenIdBytes = abi.encodePacked(_market, uint8(_outcome));
		assembly {
			_tokenId := mload(add(_tokenIdBytes, add(0x20, 0)))
		}
	}

	function getTokenIds(uint256 _market, uint256[] memory _outcomes) internal pure returns (uint256[] memory _tokenIds) {
		_tokenIds = new uint256[](_outcomes.length);
		for (uint256 _i = 0; _i < _outcomes.length; _i++) {
			_tokenIds[_i] = getTokenId(_market, _outcomes[_i]);
		}
	}

	function unpackTokenId(uint256 _tokenId) internal pure returns (uint256 _market, uint256 _outcome) {
		assembly {
			_market := shr(96,  and(_tokenId, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00))
			_outcome := shr(88, and(_tokenId, 0x00000000000000000000000000000000000000000000000000000000000000FF))
		}
	}
}
