#!/bin/bash

dfx identity use default

export ROOT_PRINCIPAL=$(dfx identity get-principal)

# ===== CREATE demo user =====
dfx identity new --disable-encryption user1
dfx identity use user1
export USER1_PRINCIPAL=$(dfx identity get-principal)

dfx identity new --disable-encryption user2
dfx identity use user2
export USER2_PRINCIPAL=$(dfx identity get-principal)

# Set default user 
dfx identity use default

# ===== SETUP Token Canister =====
dfx deploy GoldDIP20 --argument='("Token Gold Logo", "Token Silver", "TGLD", 8, 10_000_000_000_000_000, principal '\"$ROOT_PRINCIPAL\"', 0)'
dfx deploy SilverDIP20 --argument='("Token Silver Logo", "Token Silver", "TSLV", 8, 10_000_000_000_000_000, principal '\"$ROOT_PRINCIPAL\"', 0)'

export GoldDIP20_PRINCIPAL=$(dfx canister id GoldDIP20)
export SilverDIP20_PRINCIPAL=$(dfx canister id SilverDIP20)

# ===== SETUP faucet Canister =====
dfx deploy faucet
export FAUCET_PRINCIPAL=$(dfx canister id faucet)

# Pooling tokens
dfx canister call GoldDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'
dfx canister call SilverDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'

# ===== SETUP icp_basic_dex_backend
dfx deploy icp_basic_dex_backend
export DEX_PRINCIPAL=$(dfx canister id icp_basic_dex_backend)

# ===== TEST faucet =====
echo -e '\n\n#------ faucet ------------'
dfx identity use user1
echo -n "getToken    >  " \
  && dfx canister call faucet getToken '(principal '\"$GoldDIP20_PRINCIPAL\"')'
echo -n "balanceOf   >  " \
  && dfx canister call GoldDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'

echo -e '#------ faucet { Err = variant { AlreadyGiven } } ------------'
dfx canister call faucet getToken '(principal '\"$GoldDIP20_PRINCIPAL\"')'

echo -e
dfx identity use user2
echo -n "getTOken    >  " \
  && dfx canister call faucet getToken '(principal '\"$SilverDIP20_PRINCIPAL\"')'
echo -n "balanceOf   >  " \
  && dfx canister call SilverDIP20 balanceOf '(principal '\"$USER2_PRINCIPAL\"')'

# ===== TEST deposit =====
echo -e '\n\n#------ deposit ------------'
dfx identity use user1
# approveをコールして、DEXがユーザーの代わりにdepositすることを許可する
dfx canister call GoldDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 1_000)'
echo -n "deposit     >  " \
  && dfx canister call icp_basic_dex_backend deposit '(principal '\"$GoldDIP20_PRINCIPAL\"')'
# user1がDEXに預けたトークンのデータを確認
echo -n "getBalance  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER1_PRINCIPAL\"', principal '\"$GoldDIP20_PRINCIPAL\"')'

# depositをコールするuser2に切り替え
echo -e
dfx identity use user2
dfx canister call SilverDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 1_000)'
echo -n "deposit     >  " \
  && dfx canister call icp_basic_dex_backend deposit '(principal '\"$SilverDIP20_PRINCIPAL\"')'
echo -n "getBalance  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER2_PRINCIPAL\"', principal '\"$SilverDIP20_PRINCIPAL\"')'

# ===== TEST trading =====
echo -e '\n\n#------ trading ------------'
# オーダーを出すユーザーに切り替え
dfx identity use user1
echo -n "placeOrder  >  " \
  && dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 100, principal '\"$SilverDIP20_PRINCIPAL\"', 100)'
echo -n "getOrders   >  " \
  && dfx canister call icp_basic_dex_backend getOrders

echo -e '#----- trading (check { Err = variant { OrderBookFull } } -----'
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 100, principal '\"$SilverDIP20_PRINCIPAL\"', 100)'

# オーダーを購入するユーザーに切り替え
echo -e
dfx identity use user2
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$SilverDIP20_PRINCIPAL\"', 100, principal '\"$GoldDIP20_PRINCIPAL\"', 100)'
# 取引が成立してオーダーが削除されていることを確認
echo -n "getOrders   >  " \
  && dfx canister call icp_basic_dex_backend getOrders

# トレード後のユーザー残高を確認
echo -n "getBalance(user2, G)  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER2_PRINCIPAL\"', principal '\"$GoldDIP20_PRINCIPAL\"')'
echo -n "getBalance(user2, S)  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER2_PRINCIPAL\"', principal '\"$SilverDIP20_PRINCIPAL\"')'

echo -e
dfx identity use user1
echo -n "getBalance(user1, G)  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER1_PRINCIPAL\"', principal '\"$GoldDIP20_PRINCIPAL\"')'
echo -n "getBalance(user1, S)  >  " \
  && dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER1_PRINCIPAL\"', principal '\"$SilverDIP20_PRINCIPAL\"')'



# ===== TEST withdraw =====
echo -e '\n\n#------ withdraw & delete order ------'
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 500, principal '\"$SilverDIP20_PRINCIPAL\"', 500)'
echo -n "getOrders   >  " \
  && dfx canister call icp_basic_dex_backend getOrders

echo -n "withdraw    >  " \
  && dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 500)'
echo -n "getOrders   >  " \
  && dfx canister call icp_basic_dex_backend getOrders

# user1の残高チェック
echo -n "balanceOf   >  " \
  && dfx canister call GoldDIP20 balanceOf '(principal '\"$USER1_PRINCIPAL\"')'

# DEXの残高チェック
echo -n "DEX balanceOf>  " \
  && dfx canister call GoldDIP20 balanceOf '(principal '\"$DEX_PRINCIPAL\"')'

echo -e '#----- withdraw (check { Err = variant { BalanceLow } } -----'
dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 1000)'

# ===== 後始末 =====
echo -e '\n\n#------ clean user ------'
dfx identity use default
dfx identity remove user1
dfx identity remove user2