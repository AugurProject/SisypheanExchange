import { describe, beforeEach, test } from 'node:test'
import { getMockedEthSimulateWindowEthereum, MockWindowEthereum } from '../testsuite/simulator/MockWindowEthereum.js'
import { createWriteClient } from '../testsuite/simulator/utils/viem.js'
import { BURN_ADDRESS, DAY, GENESIS_REPUTATION_TOKEN, NUM_TICKS, REP_BOND, TEST_ADDRESSES } from '../testsuite/simulator/utils/constants.js'
import { approveToken, buyCompleteSets, buyFromAuction, cashInREP, claimTradingProceeds, createMarket, dispute, ensureShareTokenDeployed, ensureSisypheanExchangeDeployed, getERC20Balance, getERC20Supply, getETHBalance, getMarketData, getMarketShareTokenBalance, getShareTokenCashBalance, getSisypheanExchangeAddress, getTokenId, getUniverseData, initialTokenBalance, isFinalized, isSisypheanExchangeDeployed, migrateCash, migrateREP, migrateShareToken, reportOutcome, returnRepBond, sellCompleteSets, setupTestAccounts } from '../testsuite/simulator/utils/utilities.js'
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
		assert.strictEqual(marketData[1], genesisUniverse, 'Market origin universe not as expected')
		assert.strictEqual(marketData[2].toLowerCase(), client.account.address, 'Market designated reporter not as expected')
		assert.strictEqual(marketData[3], "test", 'Market extraInfo not as expected')
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

		const marketId = 1n
		const amountToBuy = 10n**18n
		await buyCompleteSets(client, genesisUniverse, marketId, client.account.address, amountToBuy)
		const client1ForkedMarkethareTokenBalances = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)

		// We'll create a second market and buy complete sets with both users as well
		const endTime2 = curentTimestamp + (DAY * 30n)
		await createMarket(client, genesisUniverse, endTime2, "test 2")

		const marketId2 = 2n
		await buyCompleteSets(client, genesisUniverse, marketId2, client.account.address, amountToBuy)
		await buyCompleteSets(client2, genesisUniverse, marketId2, client2.account.address, amountToBuy)
		const client1NormalMarkethareTokenBalances = await getMarketShareTokenBalance(client, genesisUniverse, marketId2, client.account.address)
		const client2NormalMarkethareTokenBalances = await getMarketShareTokenBalance(client2, genesisUniverse, marketId2, client.account.address)

		await mockWindow.advanceTime(DAY)

		const initialOutcome = 1n
		await reportOutcome(client, genesisUniverse, marketId, initialOutcome)

		const disputeOutcome = 2n
		await dispute(client2, genesisUniverse, marketId, disputeOutcome)

		// Three child universe now exist
		const invalidUniverseId = 1n
		const yesUniverseId = 2n
		const noUniverseId = 3n
		const invalidUniverseData = await getUniverseData(client, invalidUniverseId)
		const yesUniverseData = await getUniverseData(client, yesUniverseId)
		const noUniverseData = await getUniverseData(client, noUniverseId)

		assert.notEqual(invalidUniverseData[0], addressString(0n), 'invalid universe not recognized or not initialized properly')
		assert.notEqual(yesUniverseData[0], addressString(0n), 'yes universe not recognized or not initialized properly')
		assert.notEqual(noUniverseData[0], addressString(0n), 'no universe not recognized or not initialized properly')

		// Initially Cash and share balances in the child universes are 0 and the fored universe still holds the same balance
		const shareTokenCashInGenesis = await getShareTokenCashBalance(client, genesisUniverse)
		const shareTokenCashInInvalid = await getShareTokenCashBalance(client, invalidUniverseId)
		const shareTokenCashInYes = await getShareTokenCashBalance(client, yesUniverseId)
		const shareTokenCashInNo = await getShareTokenCashBalance(client, noUniverseId)

		const totalSetCosts = amountToBuy * 3n * NUM_TICKS
		assert.strictEqual(shareTokenCashInGenesis, totalSetCosts, "Cash balance of Genesis Universe not as expected")
		assert.strictEqual(shareTokenCashInInvalid, 0n, "Invalid universe cash not as expected")
		assert.strictEqual(shareTokenCashInYes, 0n, "Yes universe cash not as expected")
		assert.strictEqual(shareTokenCashInNo, 0n, "No universe cash not as expected")

		// We can trigger a migration of the Share Token contracts cash to handle that balance
		await migrateCash(client, genesisUniverse)

		const shareTokenCashInGenesisAfterMigrateCash = await getShareTokenCashBalance(client, genesisUniverse)
		const shareTokenCashInInvalidAfterMigrateCash = await getShareTokenCashBalance(client, invalidUniverseId)
		const shareTokenCashInYesAfterMigrateCash = await getShareTokenCashBalance(client, yesUniverseId)
		const shareTokenCashInNoAfterMigrateCash = await getShareTokenCashBalance(client, noUniverseId)

		assert.strictEqual(shareTokenCashInGenesisAfterMigrateCash, 0n, "Cash balance of Genesis Universe not as expected")
		assert.strictEqual(shareTokenCashInInvalidAfterMigrateCash, totalSetCosts, "Invalid universe cash not as expected")
		assert.strictEqual(shareTokenCashInYesAfterMigrateCash, totalSetCosts, "Yes universe cash not as expected")
		assert.strictEqual(shareTokenCashInNoAfterMigrateCash, totalSetCosts, "No universe cash not as expected")

		// The Share Token balances have the same process requiring migration, but will be needed for each user, and for each outcome they wish to migrate
		const client1ForkedMarkethareTokenBalancesAfterFork = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)
		const client1NormalMarkethareTokenBalancesAfterFork = await getMarketShareTokenBalance(client, genesisUniverse, marketId2, client.account.address)
		const client2NormalMarkethareTokenBalancesAfterFork = await getMarketShareTokenBalance(client2, genesisUniverse, marketId2, client.account.address)

		assert.deepEqual(client1ForkedMarkethareTokenBalancesAfterFork, client1ForkedMarkethareTokenBalances, "Forked market shares not as expected right after fork")
		assert.deepEqual(client1NormalMarkethareTokenBalancesAfterFork, client1NormalMarkethareTokenBalances, "Client 1 normal market shares not as expected right after fork")
		assert.deepEqual(client2NormalMarkethareTokenBalancesAfterFork, client2NormalMarkethareTokenBalances, "Client 2 normal market shares not as expected right after fork")

		const forkedMarketInvalidId = await getTokenId(client, genesisUniverse, marketId, 0n)
		await migrateShareToken(client, forkedMarketInvalidId)

		const client1ForkedMarketShareTokenBalancesAfterInvalidMigration = await getMarketShareTokenBalance(client, genesisUniverse, marketId, client.account.address)
		assert.strictEqual(client1ForkedMarketShareTokenBalancesAfterInvalidMigration[0], 0n, "Invalid Shares not 0 in genesis universe after migration")

		const client1ForkedMarketShareTokenBalancesInInvalidUniverseAfterInvalidMigration = await getMarketShareTokenBalance(client, invalidUniverseId, marketId, client.account.address)
		const client1ForkedMarketShareTokenBalancesInYesUniverseAfterInvalidMigration = await getMarketShareTokenBalance(client, yesUniverseId, marketId, client.account.address)
		const client1ForkedMarketShareTokenBalancesInNoUniverseAfterInvalidMigration = await getMarketShareTokenBalance(client, noUniverseId, marketId, client.account.address)

		assert.strictEqual(client1ForkedMarketShareTokenBalancesInInvalidUniverseAfterInvalidMigration[0], amountToBuy, "Invalid Shares not migrated to invalid universe after migration")
		assert.strictEqual(client1ForkedMarketShareTokenBalancesInYesUniverseAfterInvalidMigration[0], amountToBuy, "Invalid Shares not migrated to yes universe after migration")
		assert.strictEqual(client1ForkedMarketShareTokenBalancesInNoUniverseAfterInvalidMigration[0], amountToBuy, "Invalid Shares not migrated to no universe after migration")

		// get REP total supply - REP balance of NULL address
		const repSupply = await getERC20Supply(client, addressString(GENESIS_REPUTATION_TOKEN))
		const repBurned = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), addressString(1n))
		const totalREP = repSupply - repBurned;

		// get ETH balance of genesis and NO child universe
		const genesisETHBalance = (await getUniverseData(client, genesisUniverse))[2]
		const noUniverseETHBalance = (await getUniverseData(client, noUniverseId))[2]
		assert.strictEqual(noUniverseETHBalance, 0n, "NO universe ETH balance not initially 0")

		// migrate REP from client 1 to NO universe
		const client1REPBalance = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		const repMigrationAmount = client1REPBalance / 2n;
		await migrateREP(client, genesisUniverse, repMigrationAmount, 2n)

		const repBurnedAfterMigration = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), addressString(BURN_ADDRESS))
		assert.strictEqual(repBurnedAfterMigration, repBurned + repMigrationAmount, "REP not sent to burn address during migration")

		// check eth balance of genesis and NO child universe
		const genesisETHBalanceAfterMigration = (await getUniverseData(client, genesisUniverse))[2]
		const noUniverseETHBalanceAfterMigration = (await getUniverseData(client, noUniverseId))[2]

		const correspondingETH = repMigrationAmount * genesisETHBalance / totalREP;
		const expectedGenesisETHBalance = genesisETHBalance - correspondingETH
		assert.strictEqual(genesisETHBalanceAfterMigration, expectedGenesisETHBalance, "Genesis ETH balance not as expected after REP migration")
		assert.strictEqual(noUniverseETHBalanceAfterMigration, correspondingETH, "N) universe ETH balance not as expected after REP migration")

		// We cannot participate in the REP auction yet
		const ethBalanceDelta = (await getUniverseData(client, noUniverseId))[4]

		await assert.rejects(buyFromAuction(client, genesisUniverse, 2n, ethBalanceDelta))

		// End rep migration period
		await mockWindow.advanceTime(7n * DAY + 1n)

		// Client 1 burns remaining REP for corresponding ETH
		const repBalanceAfterMigration = await getERC20Balance(client, addressString(GENESIS_REPUTATION_TOKEN), client.account.address)
		const repSupplyAfterMigration = totalREP - repBurnedAfterMigration
		const expectedETHPayout = repBalanceAfterMigration * genesisETHBalanceAfterMigration / repSupplyAfterMigration

		await cashInREP(client, genesisUniverse)

		const genesisETHBalanceAfterREPCashIn = (await getUniverseData(client, genesisUniverse))[2]
		const expectedGenesisETHBalanceAfterREPCashIn = genesisETHBalanceAfterMigration - expectedETHPayout
		assert.strictEqual(genesisETHBalanceAfterREPCashIn, expectedGenesisETHBalanceAfterREPCashIn, "Genesis ETH balance not as expected after REP cash in")

		// Wait a day for auction to increase REP payout
		await mockWindow.advanceTime(DAY)

		//const genesisUniverseData = await getUniverseData(client, genesisUniverse)
		const noUniverseDataAfterMigration = await getUniverseData(client, noUniverseId)

		const repBalanceBeforeAuction = await getERC20Balance(client, noUniverseDataAfterMigration[0], client.account.address)
		const repAuctionScale = repMigrationAmount * 1_000_000n - repMigrationAmount / 1_000_000n
		const expectedREPPayout = DAY * repAuctionScale
		await buyFromAuction(client, genesisUniverse, 2n, ethBalanceDelta)

		const repBalanceAfterAuction = await getERC20Balance(client, noUniverseDataAfterMigration[0], client.account.address)
		const actualREPPayout = repBalanceAfterAuction - repBalanceBeforeAuction
		const fudgeForTime = 100n * repAuctionScale
		const payoutDelta = actualREPPayout - expectedREPPayout
		assert.ok(payoutDelta > 0 && payoutDelta < fudgeForTime, "User did not recieve expected REP from auction")
	})
})
