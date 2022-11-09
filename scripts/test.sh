#!/bin/bash

dfx deploy icp_basic_dex_backend


# ===== Create demo user =====
dfx identity new --disable-encryption user1
dfx identity use user1
export USER1_PRINCIPAL=$(dfx identity get-principal)

dfx identity new --disable-encryption user2
dfx identity use user2
export USER2_PRINCIPAL=$(dfx identity get-principal)


# ===== Set Token =====
dfx identity use default

dfx canister call GoldDIP20 mint '(principal '\"$USER1_PRINCIPAL\"', 1000000)'
dfx canister call SilverDIP20 mint '(principal '\"$USER1_PRINCIPAL\"', 1000000)'

dfx canister call GoldDIP20 mint '(principal '\"$USER2_PRINCIPAL\"', 1000000)'
dfx canister call SilverDIP20 mint '(principal '\"$USER2_PRINCIPAL\"', 1000000)'


# ===== Check user Token =====
dfx canister call GoldDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'
## (1_000_000 : nat)
dfx canister call SilverDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'
## (1_000_000 : nat)
dfx canister call GoldDIP20 balanceOf '(principal '\"$USER2_PRINCIPAL\"')'
## (1_000_000 : nat)
dfx canister call SilverDIP20 balanceOf '(principal '\"$USER2_PRINCIPAL\"')'
## (1_000_000 : nat)

# Check DEX Token
export DEX_PRINCIPAL=$(dfx canister id icp_basic_dex_backend)
dfx canister call SilverDIP20 balanceOf '(principal '\"$DEX_PRINCIPAL\"')'
## (0 : nat)


# ===== TEST deposit =====
export GoldDIP20_PRINCIPAL=$(dfx canister id GoldDIP20)
export SilverDIP20_PRINCIPAL=$(dfx canister id SilverDIP20)

echo -e '\n===== TEST DEPOSIT (user1 -> DEX) ====='
# depositを行うユーザーに切り替え
dfx identity use user1

# approveをコールして、DEXがユーザーの代わりにdepositすることを許可する
dfx canister call GoldDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 10000)'

echo -e '\n===== deposit() ====='
dfx canister call icp_basic_dex_backend deposit '(principal '\"$GoldDIP20_PRINCIPAL\"')'
## (variant { Ok = 100_000 : nat })

# # user1の残高チェック
# dfx canister call GoldDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'
# ## (980_000 : nat)

# # DEXの残高チェック
# dfx canister call GoldDIP20 balanceOf '(principal '\"$GoldDIP20_PRINCIPAL\"')'
# ## (100_000 : nat)

# user1がDEXに預けたトークンのデータを確認
echo -e '\n===== getBalances() ====='
dfx canister call icp_basic_dex_backend getBalances
echo -e '\n===== getBalance() ====='
dfx canister call icp_basic_dex_backend getBalance '(principal '\"$GoldDIP20_PRINCIPAL\"')'


echo -e '\n===== TEST DEPOSIT (user2 -> DEX) ====='
# depositを行うユーザーに切り替え
dfx identity use user2

# approveをコールして、DEXがユーザーの代わりにdepositすることを許可する
dfx canister call SilverDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 10000)'

echo -e '\n===== deposit() ====='
dfx canister call icp_basic_dex_backend deposit '(principal '\"$SilverDIP20_PRINCIPAL\"')'
## (variant { Ok = 100_000 : nat })
dfx canister call icp_basic_dex_backend getBalance '(principal '\"$SilverDIP20_PRINCIPAL\"')'


# # user1の残高チェック
# dfx canister call GoldDIP20 balanceOf '(principal '\"$USER2_PRINCIPAL\"')'
# ## (980_000 : nat)

# # DEXの残高チェック
# dfx canister call GoldDIP20 balanceOf '(principal '\"$GoldDIP20_PRINCIPAL\"')'
# ## (100_000 : nat)

# user1がDEXに預けたトークンのデータを確認
echo -e '\n===== getBalances() ====='
dfx canister call icp_basic_dex_backend getBalances


# ===== TEST trading =====
echo -e '\n===== TEST TRADING (user1 [GoldDIP:5000] <-> user2 [SilverDIP20:5000]) ====='

echo -e '\n===== placeOrder( GoldDIP20, 5000, SilverDIP20, 5000 ) ====='
# 売り注文を出すユーザーに切り替え
dfx identity use user1
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 5000, principal '\"$SilverDIP20_PRINCIPAL\"', 5000)'

echo -e '\n===== getOrders() ====='
dfx canister call icp_basic_dex_backend getOrders

echo -e '\n===== placeOrder( #Err(#OrderBookFull) ) ====='
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 1000, principal '\"$SilverDIP20_PRINCIPAL\"', 1000)'
## (variant { Err = variant { OrderBookFull } })

echo -e '\n===== placeOrder( SilverDIP20, 5000, GoldDIP20, 5000 ) [user2] ====='
# 売り注文を出すユーザーに切り替え
dfx identity use user2
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$SilverDIP20_PRINCIPAL\"', 5000, principal '\"$GoldDIP20_PRINCIPAL\"', 5000)'

echo -e '\n===== getOrders() ====='
dfx canister call icp_basic_dex_backend getOrders

# トレード後のユーザー残高を確認
echo -e '\n#----- user2 Balances ------'
dfx canister call icp_basic_dex_backend getBalances

echo -e '\n#----- user1 Balances -----'
# 残高を確認するユーザー "user1" に切り替え
dfx identity use user1
dfx canister call icp_basic_dex_backend getBalances


# ===== TEST withdraw (DEX -> user1) =====
echo  -e '\n===== withdraw() ====='

echo -e '#------ Cleate order ------'
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 5000, principal '\"$SilverDIP20_PRINCIPAL\"', 5000)'
echo -e '#------ get order ------'
dfx canister call icp_basic_dex_backend getOrders

echo -e '#------ withdraw & delete order ------'
# dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 5000, principal '\"$USER1_PRINCIPAL\"')'
dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 5000)'

echo -e '#------ get order ------'
dfx canister call icp_basic_dex_backend getOrders

# user1の残高チェック
dfx canister call GoldDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'

# DEXの残高チェック
dfx canister call GoldDIP20 balanceOf '(principal '\"$DEX_PRINCIPAL\"')'

# user1がDEXに預けたトークンのデータが更新されているか確認
echo  -e '\n===== getBalances() ====='
dfx canister call icp_basic_dex_backend getBalances


# ===== 後始末 =====
dfx identity use default
dfx identity remove user1
dfx identity remove user2