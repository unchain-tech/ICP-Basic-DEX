#!/bin/bash

# Remove old content.
dfx stop
rm -rf .dfx

export ROOT_PRINCIPAL=$(dfx identity get-principal)

echo $ROOT_PRINCIPAL

# ---TODO: DELETE---
dfx start --clean --background
# -------------------
# register, build, and deploy a dapp
dfx deploy GoldDIP20 --argument='("Token Gold Logo", "Token Silver", "TGD", 8, 10000000000000000, principal '\"$ROOT_PRINCIPAL\"', 0)'
dfx deploy SilverDIP20 --argument='("Token Silver Logo", "Token Silver", "TSV", 8, 10000000000000000, principal '\"$ROOT_PRINCIPAL\"', 0)'

# set fees
