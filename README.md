# Tokenized Community Sidewalk Repair Coordination System

A decentralized system for coordinating sidewalk maintenance through community participation and municipal cooperation, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system enables communities to report, assess, and coordinate sidewalk repairs through a tokenized incentive structure. Citizens earn tokens for participating in damage assessment, safety management, and compliance verification.

## System Architecture

### Core Contracts

1. **Damage Assessment Contract** (`damage-assessment.clar`)
    - Evaluates crack severity and trip hazard risks
    - Rewards assessors with tokens for accurate reporting
    - Maintains damage severity classifications

2. **Municipal Notification Contract** (`municipal-notification.clar`)
    - Reports sidewalk issues to city maintenance departments
    - Tracks notification status and municipal responses
    - Incentivizes timely reporting

3. **Temporary Safety Contract** (`temporary-safety.clar`)
    - Manages hazard marking and pedestrian protection
    - Coordinates temporary safety measures
    - Rewards safety volunteers

4. **Repair Scheduling Contract** (`repair-scheduling.clar`)
    - Coordinates concrete replacement and resurfacing
    - Manages contractor assignments and scheduling
    - Tracks repair progress and completion

5. **Accessibility Compliance Contract** (`accessibility-compliance.clar`)
    - Ensures sidewalk meets disability access standards
    - Validates ADA compliance post-repair
    - Rewards compliance verification

## Token Economics

- **Assessment Tokens**: Earned for damage reporting and verification
- **Safety Tokens**: Earned for temporary safety management
- **Compliance Tokens**: Earned for accessibility verification
- **Municipal Tokens**: Earned for successful municipal coordination

## Key Features

- **Community-Driven**: Citizens participate in all aspects of sidewalk maintenance
- **Transparent**: All activities recorded on blockchain
- **Incentivized**: Token rewards for participation
- **Compliant**: Ensures ADA accessibility standards
- **Coordinated**: Seamless municipal integration

## Getting Started

### Prerequisites
- Stacks wallet
- Clarity development environment
- Node.js for testing

### Installation

1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`
4. Deploy contracts to Stacks testnet

### Usage

Each contract operates independently:
- Report damage through the damage assessment contract
- Notify municipalities via the notification contract
- Manage safety through the temporary safety contract
- Schedule repairs via the scheduling contract
- Verify compliance through the accessibility contract

## Testing

Tests are written using Vitest and cover all contract functions:
- Unit tests for each contract function
- Integration tests for complete workflows
- Edge case testing for error conditions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## License

MIT License - see LICENSE file for details
