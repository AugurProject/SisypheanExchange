import { describe, beforeEach, test } from 'node:test'
import { getMockedEthSimulateWindowEthereum, MockWindowEthereum } from '../testsuite/simulator/MockWindowEthereum.js'
import { createWriteClient } from '../testsuite/simulator/utils/viem.js'
import { DAY, GENESIS_REPUTATION_TOKEN, NUM_TICKS, TEST_ADDRESSES } from '../testsuite/simulator/utils/constants.js'
import { approveToken, buyCompleteSets, createGenesisUniverse, createMarket, ensureShareTokenDeployed, ensureSisypheanExchangeDeployed, getERC20Balance, getETHBalance, getGenesisUniverse, getMarketData, getMarketShareTokenBalance, getUniverseLegit, initialTokenBalance, isSisypheanExchangeDeployed, setupTestAccounts } from '../testsuite/simulator/utils/utilities.js'
import assert from 'node:assert'
import { addressString } from '../testsuite/simulator/utils/bigint.js'

const curentTimestamp = BigInt(Math.round(Date.now() / 1000))

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

	test('canCreateGenesisUniverse', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)

		await createGenesisUniverse(client)

		const genesisUniverse = await getGenesisUniverse(client)

		const isLegitUniverse = await getUniverseLegit(client, genesisUniverse)
		assert.ok(isLegitUniverse, 'Genesis universe not recognized')
	})

	test('canCreateMarket', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		await createGenesisUniverse(client)
		const genesisUniverse = await getGenesisUniverse(client)

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), genesisUniverse)

		const repBalance = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		assert.strictEqual(repBalance, initialTokenBalance, "REP not initially minted")

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n
		const marketData = await getMarketData(client, genesisUniverse, marketId)

		assert.strictEqual(marketData[0], endTime, 'Market endTime not as expected')
		assert.strictEqual(marketData[1].toLowerCase(), client.account.address, 'Market designated reporter not as expected')
		assert.strictEqual(marketData[2], "test", 'Market extraInfo not as expected')
	})

	test('canBuyCompleteSets', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		await ensureShareTokenDeployed(client)
		await createGenesisUniverse(client)
		const genesisUniverse = await getGenesisUniverse(client)

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), genesisUniverse)

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n

		const shareTokenBalancesBeforeBuy = await getMarketShareTokenBalance(client, marketId, client.account.address)
		assert.strictEqual(shareTokenBalancesBeforeBuy[0], 0n, "Initial share balance not 0")
		assert.strictEqual(shareTokenBalancesBeforeBuy[1], 0n, "Initial share balance not 0")
		assert.strictEqual(shareTokenBalancesBeforeBuy[2], 0n, "Initial share balance not 0")

		const amountToBuy = 1000n
		const costToBuy = amountToBuy * NUM_TICKS

		await buyCompleteSets(client, genesisUniverse, marketId, client.account.address, amountToBuy)

		const universeEthBalanceAfterBuy = await getETHBalance(client, genesisUniverse)
		assert.strictEqual(universeEthBalanceAfterBuy, costToBuy, "ETH not paid correctly for buying complete sets")

		const shareTokenBalancesAfterBuy = await getMarketShareTokenBalance(client, marketId, client.account.address)
		assert.strictEqual(shareTokenBalancesAfterBuy[0], amountToBuy, "Shares not credited correctly")
		assert.strictEqual(shareTokenBalancesAfterBuy[1], amountToBuy, "Shares not credited correctly")
		assert.strictEqual(shareTokenBalancesAfterBuy[2], amountToBuy, "Shares not credited correctly")
	})

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
