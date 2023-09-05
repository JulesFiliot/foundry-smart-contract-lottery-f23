# Random Raffle Smart Contract

This project implements a blockchain-based raffle smart contract using Solidity and the Foundry development toolkit. 

The smart contract is deployed and usable on the Sepolia testnet at this address [0xa6afD43A1356aBE04acce36AD20853e99bf7453a](https://sepolia.etherscan.io/address/0xa6afD43A1356aBE04acce36AD20853e99bf7453a#code).

## Overview

This smart contract allows users to enter a raffle by sending ETH. At the end of the raffle period, a random winner is selected using Chainlink VRF to generate a random number. The winner receives the entire pot of ETH collected from raffle entries.

## Key Features

- Written in **Solidity** - The leading language for Ethereum smart contract development

- Developed using **Foundry** - A leading toolkit for Ethereum application development and testing

- Uses **Chainlink VRF** - To generate provably fair and tamper-proof random numbers 

- Includes **automated testing** - Tests for the smart contract using Foundry's testing framework


## Getting Started

0. Get help - `make help`
1. Install dependencies - `make install`
2. Run tests - `make test`
3. Deploy contract - `make deploy`

## Resources

- [Foundry](https://github.com/foundry-rs/foundry)
- [Chainlink](https://docs.chain.link/)
- [Solidity](https://docs.soliditylang.org/)