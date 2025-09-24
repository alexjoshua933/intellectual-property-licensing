# Intellectual Property Licensing System

A comprehensive blockchain-based platform for licensing intellectual property with automated royalty distributions and usage tracking built on the Stacks blockchain using Clarity smart contracts.

## Overview

The Intellectual Property Licensing System provides a decentralized solution for managing IP licenses, tracking usage, and automatically distributing royalties to rights holders. This system eliminates intermediaries and ensures transparent, tamper-proof records of IP usage and payments.

## Features

### Core Functionality
- **IP Registration**: Register intellectual property assets on-chain
- **License Management**: Create and manage different types of IP licenses
- **Usage Tracking**: Monitor and record IP usage in real-time
- **Automated Royalty Distribution**: Automatic payment distribution to rights holders
- **Multi-stakeholder Support**: Handle multiple rights holders per IP asset
- **License Compliance**: Enforce license terms and conditions

### Smart Contract Architecture
- **ip-licensing-system**: Core contract managing IP licenses, usage tracking, and royalty distributions

## Technology Stack

- **Blockchain**: Stacks (Bitcoin L2)
- **Smart Contracts**: Clarity
- **Development**: Clarinet
- **Testing**: Clarinet Test Framework

## Contract Features

### IP Asset Management
- Register new IP assets with metadata
- Define ownership and rights holder information
- Set licensing terms and conditions
- Update asset information (by authorized parties)

### License Creation & Management
- Create various license types (exclusive, non-exclusive, time-limited)
- Set royalty rates and payment terms
- Define usage restrictions and allowances
- Transfer license ownership

### Usage Tracking
- Record IP usage events
- Track usage metrics (downloads, views, implementations)
- Generate usage reports for rights holders
- Monitor compliance with license terms

### Royalty Distribution
- Automatic calculation of royalty payments
- Multi-party distribution support
- Escrow functionality for disputed payments
- Payment history and audit trails

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm/yarn
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/alexjoshua933/intellectual-property-licensing.git

# Navigate to project directory
cd intellectual-property-licensing

# Install dependencies
npm install

# Check contracts
clarinet check
```

### Running Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/ip-licensing-system_test.ts
```

## Usage Examples

### Registering IP Asset
```clarity
;; Register a new intellectual property asset
(contract-call? .ip-licensing-system register-ip-asset 
  "Patent-12345" 
  "Revolutionary AI Algorithm" 
  "Detailed description of the AI algorithm"
  u1000) ;; base royalty rate in basis points (10%)
```

### Creating License
```clarity
;; Create a new license for the IP asset
(contract-call? .ip-licensing-system create-license
  "Patent-12345"
  'SP2ABC123...XYZ ;; licensee address
  u365 ;; license duration in days
  u500) ;; royalty rate in basis points (5%)
```

### Recording Usage
```clarity
;; Record usage of licensed IP
(contract-call? .ip-licensing-system record-usage
  "Patent-12345"
  "License-001"
  u100) ;; usage quantity
```

## Contract Architecture

### Data Structures

#### IP Asset
```clarity
{
  id: (string-ascii 50),
  owner: principal,
  title: (string-utf8 100),
  description: (string-utf8 500),
  royalty-rate: uint,
  created-at: uint,
  active: bool
}
```

#### License
```clarity
{
  id: (string-ascii 50),
  ip-asset-id: (string-ascii 50),
  licensee: principal,
  licensor: principal,
  royalty-rate: uint,
  start-time: uint,
  end-time: uint,
  usage-limit: (optional uint),
  active: bool
}
```

#### Usage Record
```clarity
{
  license-id: (string-ascii 50),
  timestamp: uint,
  quantity: uint,
  reported-by: principal
}
```

## Security Considerations

- **Access Control**: Only authorized parties can modify IP assets and licenses
- **Input Validation**: All inputs are validated to prevent malicious data
- **Overflow Protection**: Safe arithmetic operations prevent overflow attacks
- **Reentrancy Protection**: State changes before external calls
- **Emergency Controls**: Administrative functions for emergency situations

## Roadmap

- [ ] Integration with IPFS for metadata storage
- [ ] Advanced license types (subscription-based, usage-tiered)
- [ ] Cross-chain compatibility
- [ ] Mobile applications for license management
- [ ] Analytics dashboard for usage insights
- [ ] Integration with traditional payment systems

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions and support, please create an issue in this repository or contact the development team.

---

*This project demonstrates the power of blockchain technology in revolutionizing intellectual property management and creating fair, transparent systems for creators and users alike.*