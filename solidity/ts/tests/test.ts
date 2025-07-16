import { describe, beforeEach, test } from 'node:test'
import { getMockedEthSimulateWindowEthereum, MockWindowEthereum } from '../testsuite/simulator/MockWindowEthereum.js'
import { createWriteClient } from '../testsuite/simulator/utils/viem.js'
import { TEST_ADDRESSES } from '../testsuite/simulator/utils/constants.js'
import { ensureSisypheanExchangeDeployed, isSisypheanExchangeDeployed, setupTestAccounts } from '../testsuite/simulator/utils/utilities.js'
import assert from 'node:assert'

describe('Contract Test Suite', () => {

	let mockWindow: MockWindowEthereum

	beforeEach(async () => {
		mockWindow = getMockedEthSimulateWindowEthereum()
		await setupTestAccounts(mockWindow)
	})

	test('canDeployContract', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		const isDeployed = await isSisypheanExchangeDeployed(client)
		assert.ok(isDeployed, `Not Deployed!`)
	})

	// Can create a market

	// Can buy complete sets

	// Can cash out complete sets
		// Time based fee testing

	// Market can resolve and distribute Cash
		// Time based fee testing

	// Market can be disputed and resolve

	// Market can be disputed and fork
		// Cash token forks
		// All markets fork
		// Forking market is finalized
		// Other markets return to pre-reporting state
		// REP migration
		// Cash migration
			// Cash migrated proportionally to REP migration
			// Remaining Cash distributed to REP holders
		// Cash for REP Auction
		    // (A) All succeed
			// (B) One fails
			// (C) Two fail
			// (D) All fail
})
