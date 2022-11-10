#!/bin/bash

# Remove old content.
dfx stop
rm -rf .dfx

dfx identity use default

export ROOT_PRINCIPAL=$(dfx identity get-principal)

echo $ROOT_PRINCIPAL

dfx start --clean --background

# register, build, and deploy a dapp
dfx deploy GoldDIP20 --argument='("Token Gold Logo", "Token Silver", "TGD", 8, 10000000000000000, principal '\"$ROOT_PRINCIPAL\"', 0)'
dfx deploy SilverDIP20 --argument='("Token Silver Logo", "Token Silver", "TSV", 8, 10000000000000000, principal '\"$ROOT_PRINCIPAL\"', 0)'

export GoldDIP20_PRINCIPAL=$(dfx canister id GoldDIP20)
export SilverDIP20_PRINCIPAL=$(dfx canister id SilverDIP20)

# ===== Deploy Internet Identity =====
dfx deploy internet_identity

# ===== Deploy faucet canister and mint token =====
dfx deploy faucet

export FAUCET_PRINCIPAL=$(dfx canister id faucet)
dfx canister call GoldDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'
dfx canister call SilverDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'

# ===== Deploy icp_basic_dex_backend canister =====
dfx deploy icp_basic_dex_backend

# ===== Deploy icp_basic_dex_frontend =====
dfx deploy icp_basic_dex_frontend