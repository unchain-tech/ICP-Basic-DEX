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

# deploy Internet Identity
dfx deploy internet_identity

dfx deploy icp_basic_dex_backend

dfx deploy  icp_basic_dex_frontend