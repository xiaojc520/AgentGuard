// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AgentGuard
 * @notice AI-driven on-chain wallet risk monitoring and alert system on Arc.
 *         Detects abnormal transaction patterns, flags risky addresses, and triggers alerts.
 */

contract AgentGuard {

    // ─── Constants ──────────────────────────────────────────────────────────

    uint256 public constant RISK_SCORE_MAX = 100;
    uint256 public constant ALERT_THRESHOLD = 70; // Risk score >= 70 triggers alert

    // ─── Enums ──────────────────────────────────────────────────────────────

    enum RiskLevel { Safe, Low, Medium, High, Critical }
    enum AlertType {
        AbnormalLargeTransfer,
        NewContractInteraction,
        HighFrequencyActivity,
        BlacklistContact,
        SuspiciousPattern,
        BalanceDrain,
        UnverifiedContractCall
    }

    // ─── Structs ────────────────────────────────────────────────────────────

    struct RiskAssessment {
        uint256 riskScore;           // 0-100
        RiskLevel level;
        uint256 lastAssessed;
        uint256 assessmentCount;
        bool isMonitored;            // Active monitoring flag
    }

    struct RiskFactor {
        AlertType alertType;
        uint256 weight;              // Contribution to risk score
        uint256 occurrences;
        uint256 lastOccurrence;
        bool active;
    }

    struct Alert {
        uint256 id;
        address wallet;
        AlertType alertType;
        uint256 severity;            // 1-100
        string description;
        uint256 timestamp;
        bool acknowledged;
        bool resolved;
    }

    struct AlertRule {
        AlertType alertType;
        uint256 threshold;           // Trigger threshold value
        uint256 cooldownSeconds;     // Min time between same-type alerts
        bool enabled;
    }

    struct MonitorConfig {
        uint256 monitoringFee;       // USDC fee for premium monitoring (6 decimals)
        bool active;
        uint256 checkInterval;       // Seconds between assessments
    }

    // ─── State Variables ────────────────────────────────────────────────────

    address public owner;
    address public riskEngine;       // AI backend address

    mapping(address => RiskAssessment) private assessments;
    mapping(address => RiskFactor[]) private riskFactors;
    mapping(address => Alert[]) private walletAlerts;
    Alert[] private allAlerts;

    mapping(AlertType => AlertRule) public alertRules;
    address[] private monitoredWallets;
    mapping(address => bool) public flaggedAddresses;     // Manually flagged risky addresses
    mapping(address => bool) public trustedAddresses;     // Verified safe addresses

    uint256 public nextAlertId;
    uint256 public totalAlertsTriggered;
    uint256 public totalAlertsResolved;

    // ─── Events ─────────────────────────────────────────────────────────────

    event RiskAssessed(address indexed wallet, uint256 riskScore, RiskLevel level);
    event RiskFactorAdded(address indexed wallet, AlertType alertType, uint256 weight);
    event RiskFactorRemoved(address indexed wallet, AlertType alertType);
    event AlertTriggered(uint256 alertId, address indexed wallet, AlertType alertType, uint256 severity);
    event AlertAcknowledged(uint256 alertId, address indexed wallet);
    event AlertResolved(uint256 alertId, address indexed wallet);
    event WalletFlagged(address indexed wallet, string reason);
    event WalletUnflagged(address indexed wallet);
    event WalletTrusted(address indexed wallet);
    event WalletUntrusted(address indexed wallet);
    event AlertRuleUpdated(AlertType alertType, uint256 threshold, uint256 cooldown);
    event MonitoringStarted(address indexed wallet);
    event MonitoringStopped(address indexed wallet);
    event RiskEngineUpdated(address indexed oldEngine, address indexed newEngine);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ─── Modifiers ──────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "AgentGuard: not owner");
        _;
    }

    modifier onlyRiskEngine() {
        require(msg.sender == riskEngine || msg.sender == owner, "AgentGuard: not risk engine");
        _;
    }

    // ─── Constructor ────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
        riskEngine = msg.sender;

        // Initialize default alert rules
        alertRules[AlertType.AbnormalLargeTransfer] = AlertRule(AlertType.AbnormalLargeTransfer, 1e6, 3600, true); // >1 USDC, 1hr cooldown
        alertRules[AlertType.NewContractInteraction] = AlertRule(AlertType.NewContractInteraction, 1, 7200, true);   // Any new contract, 2hr cooldown
        alertRules[AlertType.HighFrequencyActivity] = AlertRule(AlertType.HighFrequencyActivity, 10, 1800, true);    // >10 tx in period, 30min cooldown
        alertRules[AlertType.BlacklistContact] = AlertRule(AlertType.BlacklistContact, 1, 86400, true);             // Any contact, 24hr cooldown
        alertRules[AlertType.SuspiciousPattern] = AlertRule(AlertType.SuspiciousPattern, 5, 3600, true);           // Pattern threshold, 1hr cooldown
        alertRules[AlertType.BalanceDrain] = AlertRule(AlertType.BalanceDrain, 80, 1800, true);                   // >80% drained, 30min cooldown
        alertRules[AlertType.UnverifiedContractCall] = AlertRule(AlertType.UnverifiedContractCall, 1, 7200, true); // Any unverified, 2hr cooldown
    }

    // ─── Write Functions: Risk Assessment ───────────────────────────────────

    /**
     * @notice Assess risk for a wallet (AI backend calls this)
     */
    function assessRisk(
        address wallet,
        uint256 riskScore,
        RiskLevel level
    ) external onlyRiskEngine {
        require(wallet != address(0), "AgentGuard: zero address");
        require(riskScore <= RISK_SCORE_MAX, "AgentGuard: score out of range");

        uint256 oldScore = assessments[wallet].riskScore;

        assessments[wallet].riskScore = riskScore;
        assessments[wallet].level = level;
        assessments[wallet].lastAssessed = block.timestamp;
        assessments[wallet].assessmentCount++;

        if (assessments[wallet].isMonitored && !assessments[wallet].isMonitored) {
            assessments[wallet].isMonitored = true;
            monitoredWallets.push(wallet);
        }

        // Auto-trigger alert if risk crosses threshold
        if (riskScore >= ALERT_THRESHOLD && oldScore < ALERT_THRESHOLD) {
            _triggerAlert(wallet, AlertType.SuspiciousPattern, riskScore, "Risk score crossed threshold");
        }

        emit RiskAssessed(wallet, riskScore, level);
    }

    /**
     * @notice Add a risk factor to a wallet
     */
    function addRiskFactor(
        address wallet,
        AlertType alertType,
        uint256 weight,
        uint256 occurrences
    ) external onlyRiskEngine {
        riskFactors[wallet].push(RiskFactor({
            alertType: alertType,
            weight: weight,
            occurrences: occurrences,
            lastOccurrence: block.timestamp,
            active: true
        }));
        emit RiskFactorAdded(wallet, alertType, weight);
    }

    /**
     * @notice Remove a risk factor by index
     */
    function removeRiskFactor(address wallet, uint256 index) external onlyRiskEngine {
        require(index < riskFactors[wallet].length, "AgentGuard: index out of bounds");
        AlertType removedType = riskFactors[wallet][index].alertType;
        riskFactors[wallet][index] = riskFactors[wallet][riskFactors[wallet].length - 1];
        riskFactors[wallet].pop();
        emit RiskFactorRemoved(wallet, removedType);
    }

    /**
     * @notice Batch assess multiple wallets
     */
    function batchAssessRisk(
        address[] calldata wallets,
        uint256[] calldata riskScores,
        RiskLevel[] calldata levels
    ) external onlyRiskEngine {
        require(wallets.length == riskScores.length, "AgentGuard: length mismatch");
        require(wallets.length == levels.length, "AgentGuard: levels mismatch");

        for (uint256 i = 0; i < wallets.length; i++) {
            if (wallets[i] == address(0) || riskScores[i] > RISK_SCORE_MAX) continue;

            assessments[wallets[i]].riskScore = riskScores[i];
            assessments[wallets[i]].level = levels[i];
            assessments[wallets[i]].lastAssessed = block.timestamp;
            assessments[wallets[i]].assessmentCount++;

            emit RiskAssessed(wallets[i], riskScores[i], levels[i]);
        }
    }

    // ─── Write Functions: Alerts ────────────────────────────────────────────

    /**
     * @notice Manually trigger an alert for a wallet (by risk engine or owner)
     */
    function triggerAlert(
        address wallet,
        AlertType alertType,
        uint256 severity,
        string calldata description
    ) external onlyRiskEngine {
        _triggerAlert(wallet, alertType, severity, description);
    }

    function acknowledgeAlert(uint256 alertId) external {
        require(alertId < allAlerts.length, "AgentGuard: invalid alert id");
        Alert storage alert = allAlerts[alertId];
        require(alert.wallet == msg.sender, "AgentGuard: not your alert");
        require(!alert.acknowledged, "AgentGuard: already acknowledged");

        alert.acknowledged = true;
        emit AlertAcknowledged(alertId, msg.sender);
    }

    function resolveAlert(uint256 alertId) external onlyRiskEngine {
        require(alertId < allAlerts.length, "AgentGuard: invalid alert id");
        Alert storage alert = allAlerts[alertId];
        require(!alert.resolved, "AgentGuard: already resolved");

        alert.resolved = true;
        totalAlertsResolved++;
        emit AlertResolved(alertId, alert.wallet);
    }

    // ─── Write Functions: Address Management ────────────────────────────────

    function flagAddress(address wallet, string calldata reason) external onlyOwner {
        flaggedAddresses[wallet] = true;
        assessments[wallet].level = RiskLevel.Critical;
        assessments[wallet].riskScore = RISK_SCORE_MAX;
        emit WalletFlagged(wallet, reason);
    }

    function unflagAddress(address wallet) external onlyOwner {
        flaggedAddresses[wallet] = false;
        emit WalletUnflagged(wallet);
    }

    function trustAddress(address wallet) external onlyOwner {
        trustedAddresses[wallet] = true;
        assessments[wallet].level = RiskLevel.Safe;
        assessments[wallet].riskScore = 0;
        emit WalletTrusted(wallet);
    }

    function untrustAddress(address wallet) external onlyOwner {
        trustedAddresses[wallet] = false;
        emit WalletUntrusted(wallet);
    }

    // ─── Write Functions: Alert Rules & Monitoring ──────────────────────────

    function updateAlertRule(AlertType alertType, uint256 threshold, uint256 cooldownSeconds, bool enabled) external onlyOwner {
        alertRules[alertType] = AlertRule(alertType, threshold, cooldownSeconds, enabled);
        emit AlertRuleUpdated(alertType, threshold, cooldownSeconds);
    }

    function startMonitoring(address wallet) external onlyOwner {
        require(wallet != address(0), "AgentGuard: zero address");
        if (!assessments[wallet].isMonitored) {
            assessments[wallet].isMonitored = true;
            monitoredWallets.push(wallet);
        }
        emit MonitoringStarted(wallet);
    }

    function stopMonitoring(address wallet) external onlyOwner {
        assessments[wallet].isMonitored = false;
        emit MonitoringStopped(wallet);
    }

    // ─── Admin Functions ────────────────────────────────────────────────────

    function setRiskEngine(address newEngine) external onlyOwner {
        require(newEngine != address(0), "AgentGuard: zero address");
        emit RiskEngineUpdated(riskEngine, newEngine);
        riskEngine = newEngine;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AgentGuard: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ─── Read Functions ─────────────────────────────────────────────────────

    function getAssessment(address wallet) external view returns (RiskAssessment memory) {
        return assessments[wallet];
    }

    function getRiskFactors(address wallet) external view returns (RiskFactor[] memory) {
        return riskFactors[wallet];
    }

    function getWalletAlerts(address wallet) external view returns (Alert[] memory) {
        return walletAlerts[wallet];
    }

    function getAllAlerts(uint256 offset, uint256 limit) external view returns (Alert[] memory) {
        uint256 total = allAlerts.length;
        if (offset >= total) return new Alert[](0);
        uint256 end = offset + limit > total ? total : offset + limit;
        Alert[] memory result = new Alert[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = allAlerts[i];
        }
        return result;
    }

    function isFlagged(address wallet) external view returns (bool) {
        return flaggedAddresses[wallet];
    }

    function isTrusted(address wallet) external view returns (bool) {
        return trustedAddresses[wallet];
    }

    function getMonitoredWallets(uint256 offset, uint256 limit) external view returns (address[] memory) {
        uint256 total = monitoredWallets.length;
        if (offset >= total) return new address[](0);
        uint256 end = offset + limit > total ? total : offset + limit;
        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = monitoredWallets[i];
        }
        return result;
    }

    function totalMonitored() external view returns (uint256) {
        return monitoredWallets.length;
    }

    // ─── Internal Helpers ───────────────────────────────────────────────────

    function _triggerAlert(
        address wallet,
        AlertType alertType,
        uint256 severity,
        string memory description
    ) internal {
        uint256 alertId = nextAlertId++;

        Alert memory alert = Alert({
            id: alertId,
            wallet: wallet,
            alertType: alertType,
            severity: severity,
            description: description,
            timestamp: block.timestamp,
            acknowledged: false,
            resolved: false
        });

        walletAlerts[wallet].push(alert);
        allAlerts.push(alert);
        totalAlertsTriggered++;

        emit AlertTriggered(alertId, wallet, alertType, severity);
    }
}
