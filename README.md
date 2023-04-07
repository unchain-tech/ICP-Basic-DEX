# About The Project

The project is a decentralized exchange in the form of an order book.

<img width="1724" alt="3_2_2" src="https://user-images.githubusercontent.com/60546319/201580863-eb5e745a-6b89-45cc-99a4-549af9ac717b.png">

<img width="1720" alt="0_1_2" src="https://user-images.githubusercontent.com/60546319/201580932-1bb338ee-9044-4218-87ec-e7109efdef15.png">

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# --recursive: To clone submodules together.
git clone --recursive git@github.com:unchain-dev/icp_basic_dex.git

# Install packages.
npm install

# Deploys your canisters to the replica and generates your candid interface.
bash ./scripts/deploy_local.sh
```

Once the job completes, your application will be available at `http://127.0.0.1:4943?canisterId={asset_canister_id}`.

Additionally, if you are making frontend changes, you can start a development server with

```bash
npm start
```

Which will start a server at `http://localhost:8080`, proxying API requests to the replica at port 8000.

## Test

Two terminals are used.

[Terminal A]

```bash
dfx start --clean
```

[Termilan B]

```bash
bash ./script/test.sh
```

# Description

## Chain deployed to

`ICP`

## Canister

---

### Stack description

- Motoko

### Directory structure

There are three types of canisters.

```bash
icp_basic_dex/
└── src/
    ├── DIP20/
    ├── faucet/
    └── icp_basic_dex_backend/
```

#### `DIP20`

Token Canister.Used to issue your own tokens.

The standard is [DIP20](https://github.com/Psychedelic/DIP20). DIP20 is used as a sub-module.

#### `faucet`

It is a canister that pools tokens.
Users receive tokens from this canister.

```bash
./
├── main.mo
└── types.mo
```

#### `icp_basic_dex_backend`

A DEX canister.

```bash
./
├── balance_book.mo
├── exchange.mo
├── main.mo
└── types.mo
```

- `main.mo` imports the following two files. **deposit** and **withdraw** functions are defined.
- `balance_book.mo` manages the token data deposited by users.
- `exchange.mo` creates orders and executes transactions..

### Code walk-through

#### `faucet/main.mo`

- `getToken`: Distribute tokens to users.

#### `icp_basic_dex_backend/main.mo`

- `deposit`: Deposit the user's tokens into the DEX.
- `withdraw`: Withdraw tokens from the DEX.
- `placeOrder`:　 Create a sell order for the token and execute it if available for trading.
- `cancelOrder`:　 Cancels the order.

## Client

---

### Stack description

- Javascript
- React.js

### Directory structure

```bash
icp_basic_dex/
└── src/
    └── icp_basic_dex_frontend/
        ├── assets/
        └── src/
        ├── App.css
        ├── App.jsx
        ├── components/
        ├── index.html
        ├── index.js
        └── utils/
```

#### `components`

The components that make up the DEX are.

- Header.jsx: Title and user authentication buttons.
- ListOrder.jsx: View Order List.
- PlaceOrder.jsx: Form to create an order.
- UserBoard.jsx: Display data on tokens held by the user.

#### `utils`

Stores information about the tokens handled by the DEX in an array.
