# LocalService Network - Community Service Verification Platform

LocalService Network is a blockchain-based reputation system for local service providers. Communities verify trades and services, rate work quality, and collectively build transparent provider profiles on-chain without intermediaries.

## Features

- **Provider Registration**: Register local service business with specialty area
- **Service Registration**: Document completed service work with cryptographic proof
- **Community Verification**: Peer verification of service delivery
- **Service Endorsements**: Community endorsement with multi-level support
- **Quality Ratings**: 1-5 star rating system for service quality
- **Token Incentives**: LSN tokens earned for verification and quality work
- **Trusted Status**: Verified providers earn trusted certification
- **Transparent History**: Immutable on-chain service history

## Smart Contract Functions

### Public Functions
- `register-provider`: Create service provider profile
- `update-provider`: Modify business information
- `register-service`: Document completed service work
- `verify-service`: Verify service delivery authenticity
- `endorse-service`: Show support for service quality
- `rate-service-quality`: Provide quality assessment

### Read-Only Functions
- `get-provider-info`: View provider profile and statistics
- `get-service`: Retrieve service records
- `get-service-verification`: Check verification status
- `get-service-endorsement`: View endorsement records
- `get-quality-rating`: Retrieve rating data
- `get-total-services`: Count registered services

## Rewards Structure

- Service Verification: 5 LSN tokens
- Service Endorsement: 8 LSN × endorsement level
- Quality Excellence: 20 LSN tokens
- Trusted Status: 40 LSN tokens