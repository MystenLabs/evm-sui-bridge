# 🏄‍♂️ Quick Start

This project uses [Foundry](https://github.com/foundry-rs/foundry) for the development framework and [Hardhat](https://github.com/NomicFoundation/hardhat) for the deployment framework.

#### Dependencies

1. Install **node** dependencies

```bash
yarn install
```

2. Next, duplicate the `.env.example` file and rename it to `.env`. Register for an **Infura** account and add your api key to the `.env` file along with the other example values:

```bash
INFURA_API_KEY=<YOUR_API_KEY>
ETHERSCAN_API_KEY=<YOUR_API_KEY>
```

#### Compilation

To compile your contracts, run:

```bash
yarn compile
```

#### Testing

```bash
yarn test
```

#### Coverage

```bash
yarn coverage
```

#### Deployment

```bash
yarn deploy --network <network>
```

> **Note**
> Make sure the deployment config file for the target network is created in the `deploy_configs` folder.
> The file should be named `<network>.json` and should export a `deployConfig` object with the same fields as the `example.json`.

#### Contract Verification

> **Note**
> This does not work with `hardhat` network.

```bash
yarn verify --network <network> <contract_address> <constructor_arguments (if any)>
```
