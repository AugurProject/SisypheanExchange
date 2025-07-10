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
})
