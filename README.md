# AgentGuard

AgentGuard is an AI-driven on-chain wallet risk monitoring and alert system built on the Arc blockchain. It functions as a smart contract-based security guard that continuously evaluates wallet risk levels and triggers real-time alerts when suspicious activity is detected.

Core Features:

Multi-factor Risk Assessment — Evaluates wallets on a 0-100 risk score scale across 7 different alert categories (abnormal large transfers, new contract interactions, high-frequency activity, blacklist contacts, suspicious patterns, balance drains, and unverified contract calls), assigning risk levels from Safe to Critical.

Customizable Alert Rules — Configurable thresholds, cooldown periods, and enable/disable toggles for each alert type, allowing the risk engine to fine-tune detection sensitivity.

Real-time Alert Lifecycle — Alerts are triggered automatically when risk scores cross thresholds, then can be acknowledged by affected wallet owners and resolved by the risk engine, providing a complete incident management workflow.

Address Management — Manual flagging of risky addresses (blacklist) and verification of safe addresses (whitelist), with automatic risk score adjustments upon flagging/trusting.

Wallet Monitoring — Active monitoring subscriptions that track wallets continuously, with batch assessment capabilities for the AI risk engine to evaluate multiple wallets simultaneously.

On-chain Transparency — All risk assessments, alerts, and address status changes are recorded as on-chain events, making the entire risk monitoring history publicly auditable.

In essence, AgentGuard brings AI-powered security intelligence directly to the blockchain — no off-chain servers needed for verification, all risk data lives on Arc and is verifiable by anyone.

> AI-driven wallet risk monitoring system.

## Category

**AI Agents**

## Live on Arc Testnet

- **Network**: Arc Testnet (Chain ID: 5042002)
- **Explorer**: https://testnet.arcscan.app
- **Contract Address**: See deployment.json after deploy

## Quick Start

```bash
npm install
export PRIVATE_KEY=your_key
npm run deploy
```
## License

MIT
