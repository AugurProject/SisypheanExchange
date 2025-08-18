import { describe, beforeEach, test } from 'node:test'
import { getMockedEthSimulateWindowEthereum, MockWindowEthereum } from '../testsuite/simulator/MockWindowEthereum.js'
import { createWriteClient } from '../testsuite/simulator/utils/viem.js'
import { DAY, GENESIS_REPUTATION_TOKEN, NUM_TICKS, REP_BOND, TEST_ADDRESSES } from '../testsuite/simulator/utils/constants.js'
import { approveToken, buyCompleteSets, claimTradingProceeds, createMarket, dispute, ensureShareTokenDeployed, ensureSisypheanExchangeDeployed, getERC20Balance, getETHBalance, getMarketData, getMarketShareTokenBalance, getSisypheanExchangeAddress, getUniverseData, initialTokenBalance, isFinalized, isSisypheanExchangeDeployed, reportOutcome, returnRepBond, sellCompleteSets, setupTestAccounts } from '../testsuite/simulator/utils/utilities.js'
import assert from 'node:assert'
import { addressString } from '../testsuite/simulator/utils/bigint.js'

describe('Contract Test Suite', () => {

	let mockWindow: MockWindowEthereum
	let curentTimestamp: bigint

	beforeEach(async () => {
		mockWindow = getMockedEthSimulateWindowEthereum()
		await setupTestAccounts(mockWindow)
		curentTimestamp = BigInt(Math.floor((await mockWindow.getTime()).getTime() / 1000))
	})

	test('canDeployContract', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		const isDeployed = await isSisypheanExchangeDeployed(client)
		assert.ok(isDeployed, `Not Deployed!`)

		const genesisUniverseData = await getUniverseData(client, 0n)
		assert.strictEqual(genesisUniverseData[0].toLowerCase(), addressString(GENESIS_REPUTATION_TOKEN), 'Genesis universe not recognized or not initialized properly')
	})

	test('canCreateMarket', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		const sisEx = getSisypheanExchangeAddress()
		const genesisUniverse = 0n

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), sisEx)

		const repBalance = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		assert.strictEqual(repBalance, initialTokenBalance, "REP not initially minted")

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n
		const marketData = await getMarketData(client, marketId)

		assert.strictEqual(marketData[0], endTime, 'Market endTime not as expected')
		assert.strictEqual(marketData[1].toLowerCase(), client.account.address, 'Market designated reporter not as expected')
		assert.strictEqual(marketData[2], "test", 'Market extraInfo not as expected')
		assert.strictEqual(marketData[3], genesisUniverse, 'Market origin universe not as expected')
	})

	test('canBuyAndSellCompleteSets', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		await ensureShareTokenDeployed(client)
		const sisEx = getSisypheanExchangeAddress()
		const genesisUniverse = 0n

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), sisEx)

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n

		const shareTokenBalancesBeforeBuy = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)
		assert.strictEqual(shareTokenBalancesBeforeBuy[0], 0n, "Initial share balance not 0")
		assert.strictEqual(shareTokenBalancesBeforeBuy[1], 0n, "Initial share balance not 0")
		assert.strictEqual(shareTokenBalancesBeforeBuy[2], 0n, "Initial share balance not 0")

		const amountToBuy = 1000n
		const costToBuy = amountToBuy * NUM_TICKS

		await buyCompleteSets(client, genesisUniverse, marketId, client.account.address, amountToBuy)

		const universeEthBalanceAfterBuy = await getETHBalance(client, sisEx)
		assert.strictEqual(universeEthBalanceAfterBuy, costToBuy, "ETH not paid correctly for buying complete sets")

		const shareTokenBalancesAfterBuy = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)
		assert.strictEqual(shareTokenBalancesAfterBuy[0], amountToBuy, "Shares not credited correctly")
		assert.strictEqual(shareTokenBalancesAfterBuy[1], amountToBuy, "Shares not credited correctly")
		assert.strictEqual(shareTokenBalancesAfterBuy[2], amountToBuy, "Shares not credited correctly")

		await sellCompleteSets(client, genesisUniverse, marketId, client.account.address, client.account.address, amountToBuy)

		const universeEthBalanceAfterSell = await getETHBalance(client, sisEx)
		assert.strictEqual(universeEthBalanceAfterSell, 0n, "ETH not returned correctly for selling complete sets")

		const shareTokenBalancesAfterSell = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)
		assert.strictEqual(shareTokenBalancesAfterSell[0], 0n, "Shares not burned correctly")
		assert.strictEqual(shareTokenBalancesAfterSell[1], 0n, "Shares not burned correctly")
		assert.strictEqual(shareTokenBalancesAfterSell[2], 0n, "Shares not burned correctly")
	})

	test('canResolveMarket', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		await ensureSisypheanExchangeDeployed(client)
		await ensureShareTokenDeployed(client)
		const sisEx = getSisypheanExchangeAddress()
		const genesisUniverse = 0n

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), sisEx)

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n
		const amountToBuy = 10n**18n
		await buyCompleteSets(client, genesisUniverse, marketId, client.account.address, amountToBuy)

		const winningOutcome = 1n

		// We can't report until the market has reached its end time
		await assert.rejects(reportOutcome(client, genesisUniverse, marketId, winningOutcome))

		await mockWindow.advanceTime(DAY)

		await reportOutcome(client, genesisUniverse, marketId, winningOutcome)

		const isFInalized = await isFinalized(client, genesisUniverse, marketId)
		assert.ok(!isFInalized, "Market incorrectly recognized as finalized")
		await assert.rejects(returnRepBond(client, genesisUniverse, marketId))
		await assert.rejects(claimTradingProceeds(client, genesisUniverse, marketId, client.account.address, client.account.address))

		await mockWindow.advanceTime(DAY + 1n)

		const isFInalizedNow = await isFinalized(client, genesisUniverse, marketId)
		assert.ok(isFInalizedNow, "Market not recognized as finalized")

		const repBalanceBeforeReturn = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		await returnRepBond(client, genesisUniverse, marketId)
		const repBalanceAfterReturn = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		assert.strictEqual(repBalanceAfterReturn, repBalanceBeforeReturn + REP_BOND, "REP bond not returned")

		const otherAccount = addressString(TEST_ADDRESSES[1])
		const universeEthBalanceBeforeClaim = await getETHBalance(client, sisEx)
		const winnerEthBalanceBeforeClaim = await getETHBalance(client, otherAccount)

		await claimTradingProceeds(client, genesisUniverse, marketId, client.account.address, otherAccount)
		const universeEthBalanceAfterClaim = await getETHBalance(client, sisEx)
		const winnerEthBalanceAfterClaim = await getETHBalance(client, otherAccount)

		assert.strictEqual(universeEthBalanceAfterClaim, universeEthBalanceBeforeClaim - (amountToBuy * NUM_TICKS), "ETH not taken from universe properly from claim trading proceeds call")
		assert.strictEqual(winnerEthBalanceAfterClaim, winnerEthBalanceBeforeClaim + (amountToBuy * NUM_TICKS), "ETH not claimed properly from claim trading proceeds call")
	})

	test('canInitialReport', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		const otherClient = createWriteClient(mockWindow, TEST_ADDRESSES[1], 0)
		await ensureSisypheanExchangeDeployed(client)
		await ensureShareTokenDeployed(client)
		const sisEx = getSisypheanExchangeAddress()
		const genesisUniverse = 0n

		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), sisEx)

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		const marketId = 1n
		const winningOutcome = 1n

		await mockWindow.advanceTime(DAY)

		// We can't report as a non designated reporter until their designated reporting period is over
		await assert.rejects(reportOutcome(otherClient, genesisUniverse, marketId, winningOutcome))

		await mockWindow.advanceTime(DAY + 1n)

		await reportOutcome(otherClient, genesisUniverse, marketId, winningOutcome)

		// We still need to wait for the market to go without a dispute for the dispute period before it is finalized
		const isFInalized = await isFinalized(client, genesisUniverse, marketId)
		assert.ok(!isFInalized, "Market incorrectly recognized as finalized")
		await assert.rejects(returnRepBond(client, genesisUniverse, marketId))

		await mockWindow.advanceTime(DAY + 1n)

		const isFInalizedNow = await isFinalized(client, genesisUniverse, marketId)
		assert.ok(isFInalizedNow, "Market not recognized as finalized")

		// The REP bond can now be returned to the initial reporter
		const repBalanceBeforeReturn = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), otherClient.account.address)
		await returnRepBond(client, genesisUniverse, marketId)
		const repBalanceAfterReturn = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), otherClient.account.address)
		assert.strictEqual(repBalanceAfterReturn, repBalanceBeforeReturn + REP_BOND, "REP bond not returned")
	})

	test('canForkMarket', async () => {
		const client = createWriteClient(mockWindow, TEST_ADDRESSES[0], 0)
		const client2 = createWriteClient(mockWindow, TEST_ADDRESSES[1], 0)
		await ensureSisypheanExchangeDeployed(client)
		await ensureShareTokenDeployed(client)
		const sisEx = getSisypheanExchangeAddress()
		const genesisUniverse = 0n

		await approveToken(client2, addressString(GENESIS_REPUTATION_TOKEN), sisEx)
		await approveToken(client, addressString(GENESIS_REPUTATION_TOKEN), sisEx)

		const endTime = curentTimestamp + DAY
		await createMarket(client, genesisUniverse, endTime, "test")

		// create second market and buy complete sets with both users

		const marketId = 1n
		const amountToBuy = 10n**18n
		await buyCompleteSets(client, genesisUniverse, marketId, client.account.address, amountToBuy)

		await mockWindow.advanceTime(DAY)

		const initialOutcome = 1n
		await reportOutcome(client, genesisUniverse, marketId, initialOutcome)

		const disputeOutcome = 2n
		await dispute(client2, genesisUniverse, marketId, disputeOutcome)

		// Three child universe now exist
		const invalidUniverseData = await getUniverseData(client, 1n)
		const yesUniverseData = await getUniverseData(client, 2n)
		const noUniverseData = await getUniverseData(client, 3n)

		assert.notEqual(invalidUniverseData[0], addressString(0n), 'invalid universe not recognized or not initialized properly')
		assert.notEqual(yesUniverseData[0], addressString(0n), 'yes universe not recognized or not initialized properly')
		assert.notEqual(noUniverseData[0], addressString(0n), 'no universe not recognized or not initialized properly')

		// Cash / share Migration

		// The cash balances for each universe reflect the parent universe balances

		// The market exists in all children universes as well

		// Share Token balances are available in the forked universes

		// Rep migration to universes

		// End rep migration period

		// Observe that the underlying ETH balances have moved in proportionto REP migration

		// Unmigrated REP may burn their REP for the remaining ETH in the genesis universe

		// Dutch auction in each universe begins to raise ETH for minted REP
		/*
		On each universe, a dutch auction is held where people are bidding ETH in exchange for REP.
		The system starts by offering rep_supply/1,000,000 REP for the needed amount of CASH and the amount of REP offered increases every second until it reaches rep_supply*1,000,000 REP offered.
		The auction ends when either (A) one or more parties combined are willing to buy the CASH deficit worth of ETH for the current REP price or (B) it reaches the end without enough ETH willing to buy even at the final price.
		The REP that auction participants receive will be minted and distributed when the auction finalizes. The ETH proceeds of the auction will be added to the CASH contract on the auction's universe.
		If the auction fails to raise the necessary ETH (B), then the CASH contract's redemption price will be adjusted accordingly. If the auction succeeds at raising enough ETH (A) then the CASH contract's redemption price will remain at its pre-fork value.
		*/
	})
})
