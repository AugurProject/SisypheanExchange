pragma solidity 0.8.30;

import './ERC1155.sol';

abstract contract ForkedERC1155 is ERC1155 {

	constructor() {}

	mapping(uint256 => mapping(address => bool)) migrated;

	// TODO handle supply copy over on construction
	// TODO all methods should be diabled until a fork has actually occurred that "creates" that id

	modifier migrateIfNeeded(address account, uint256 id) {
		if (isMigrated(account, id)) return;
		migrate(account, id);
		_;
	}

	modifier migrateMultipleIfNeeded(address[] memory accounts, uint256[] memory ids) {
		for (uint256 i = 0; i < accounts.length; ++i) {
			if (!isMigrated(accounts[i], ids[i])) migrate(accounts[i], ids[i]);
		}
		_;
	}

	modifier migrateUserToMultipleIfNeeded(address account, uint256[] memory ids) {
		for (uint256 i = 0; i < ids.length; ++i) {
			if (!isMigrated(account, ids[i])) migrate(account, ids[i]);
		}
		_;
	}

	function isMigrated(address account, uint256 id) public view returns (bool) {
		if (id == 0) return true;
		return migrated[id][account];
	}

	function getParentValue(address account, uint256 id) internal view returns (uint256) {
		uint256 value = 0;
		uint256 parentId = id;
		do {
			parentId = parentId >> 4;
			if (isMigrated(account, parentId)) {
				value = _balances[id][account];
			}
		} while (parentId > 0);

		return value;
	}

	// Note: In the event there is a chain of forks 32+ deep where no balance has carried further down this will reset the balance to 0.
	// This would take several years and likely a malicious actor very openly burning a large amount of money to do this so the risk is considered low enough for this to be acceptable
	function migrate(address account, uint256 id) internal {
		_balances[id][account] = getParentValue(account, id);
		migrated[id][account] = true;
	}

	function balanceOf(address account, uint256 id) public view override returns (uint256) {
		require(account != address(0), "ERC1155: balance query for the zero address");

		if (id == 0 || migrated[id][account]) return _balances[id][account];

		return getParentValue(account, id);
	}

	function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view override returns (uint256[] memory) {
		require(accounts.length == ids.length, "ERC1155: accounts and IDs must have same lengths");

		uint256[] memory batchBalances = new uint256[](accounts.length);

		for (uint256 i = 0; i < accounts.length; ++i) {
			batchBalances[i] = balanceOf(accounts[i], ids[i]);
		}

		return batchBalances;
	}

	function _internalTransferFrom(address from, address to, uint256 id, uint256 value) internal override migrateIfNeeded(from, id) migrateIfNeeded(to, id) {
		return super._internalTransferFrom(from, to, id, value);
	}

	function _internalBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory values) internal override migrateUserToMultipleIfNeeded(from, ids) migrateUserToMultipleIfNeeded(to, ids) {
		return super._internalBatchTransferFrom(from, to, ids, values);
	}

	function _mint(address to, uint256 id, uint256 value) internal override migrateIfNeeded(to, id) {
		return super._mint(to, id, value);
	}

	function _mintBatch(address to, uint256[] memory ids, uint256[] memory values) internal override migrateUserToMultipleIfNeeded(to, ids) {
		return super._mintBatch(to, ids, values);
	}

	function _burn(address account, uint256 id, uint256 value) internal override migrateIfNeeded(account, id) {
		return super._burn(account, id, value);
	}

	function _burnBatch(address account, uint256[] memory ids, uint256[] memory values) internal override migrateUserToMultipleIfNeeded(account, ids) {
		return super._burnBatch(account, ids, values);
	}
}
