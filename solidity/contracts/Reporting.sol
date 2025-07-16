pragma solidity 0.8.30;


library Reporting {
	uint256 private constant DESIGNATED_REPORTING_DURATION_SECONDS = 1 days;
	uint256 private constant DISPUTE_ROUND_DURATION_SECONDS = 7 days;
	uint256 private constant INITIAL_DISPUTE_ROUND_DURATION_SECONDS = 1 days;
	uint256 private constant FORK_DURATION_SECONDS = 60 days;

	uint256 private constant BASE_MARKET_DURATION_MAXIMUM = 30 days; // A market of 30 day length can always be created
	uint256 private constant UPGRADE_CADENCE = 365 days;
	uint256 private constant INITIAL_UPGRADE_TIMESTAMP = 1784137255000; // Forever in the future

	uint256 private constant INITIAL_REP_SUPPLY = 11 * 10 ** 6 * 10 ** 18; // 11 Million REP

	uint256 private constant DEFAULT_REPORTING_FEE_DIVISOR = 10000; // .01% fees
	uint256 private constant MAXIMUM_REPORTING_FEE_DIVISOR = 10000; // Minimum .01% fees
	uint256 private constant MINIMUM_REPORTING_FEE_DIVISOR = 3; // Maximum 33.3~% fees. Note than anything less than a value of 2 here will likely result in bugs such as divide by 0 cases.

	uint256 private constant TARGET_REP_MARKET_CAP_MULTIPLIER = 5; // We multiply and divide by constants since we may want to multiply by a fractional amount


	function getDesignatedReportingDurationSeconds() internal pure returns (uint256) { return DESIGNATED_REPORTING_DURATION_SECONDS; }
	function getInitialDisputeRoundDurationSeconds() internal pure returns (uint256) { return INITIAL_DISPUTE_ROUND_DURATION_SECONDS; }
	function getDisputeRoundDurationSeconds() internal pure returns (uint256) { return DISPUTE_ROUND_DURATION_SECONDS; }
	function getForkDurationSeconds() internal pure returns (uint256) { return FORK_DURATION_SECONDS; }
	function getBaseMarketDurationMaximum() internal pure returns (uint256) { return BASE_MARKET_DURATION_MAXIMUM; }
	function getUpgradeCadence() internal pure returns (uint256) { return UPGRADE_CADENCE; }
	function getInitialUpgradeTimestamp() internal pure returns (uint256) { return INITIAL_UPGRADE_TIMESTAMP; }
	function getTargetRepMarketCapMultiplier() internal pure returns (uint256) { return TARGET_REP_MARKET_CAP_MULTIPLIER; }
	function getMaximumReportingFeeDivisor() internal pure returns (uint256) { return MAXIMUM_REPORTING_FEE_DIVISOR; }
	function getMinimumReportingFeeDivisor() internal pure returns (uint256) { return MINIMUM_REPORTING_FEE_DIVISOR; }
	function getDefaultReportingFeeDivisor() internal pure returns (uint256) { return DEFAULT_REPORTING_FEE_DIVISOR; }
	function getInitialREPSupply() internal pure returns (uint256) { return INITIAL_REP_SUPPLY; }
}
