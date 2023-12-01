#!/bin/bash

TOTAL_PASSED=0
TOTAL_FAILED=0

compare_result() {
    local label=$1
    local expect=$2
    local result=$3

    if [ "$expect" = "$result" ]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        echo "$label: OK"
        return 0
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        echo "$label: ERR"
        diff <(echo $expect) <(echo $result)
        return 1
    fi
}

# ===== 準備 =====
dfx stop
rm -rf .dfx
dfx start --clean --background

# ユーザーの準備
dfx identity use default
export ROOT_PRINCIPAL=$(dfx identity get-principal)

# `||（OR演算子）`：左側のコマンドが失敗（終了ステータス0以外）した場合、右側のコマンドが実行される
## 既にuser1が存在する場合、`dfx identity new user1`コマンドは実行エラーとなってしまうので、対策として`|| true`を使用
dfx identity new user1 --storage-mode=plaintext || true
dfx identity use user1
export USER1_PRINCIPAL=$(dfx identity get-principal)

dfx identity new user2 --storage-mode=plaintext || true
dfx identity use user2
export USER2_PRINCIPAL=$(dfx identity get-principal)

dfx identity use default

# Tokenキャニスターの準備
dfx deploy GoldDIP20 --argument='("Token Gold Logo", "Token Silver", "TGLD", 8, 10_000_000_000_000_000, principal '\"$ROOT_PRINCIPAL\"', 0)'
dfx deploy SilverDIP20 --argument='("Token Silver Logo", "Token Silver", "TSLV", 8, 10_000_000_000_000_000, principal '\"$ROOT_PRINCIPAL\"', 0)'
export GoldDIP20_PRINCIPAL=$(dfx canister id GoldDIP20)
export SilverDIP20_PRINCIPAL=$(dfx canister id SilverDIP20)

# Faucetキャニスターの準備
dfx deploy faucet
export FAUCET_PRINCIPAL=$(dfx canister id faucet)

## トークンをfaucetキャニスターにプールする
dfx canister call GoldDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'
dfx canister call SilverDIP20 mint '(principal '\"$FAUCET_PRINCIPAL\"', 100_000)'

# icp_basic_dex_backendキャニスターの準備
dfx deploy icp_basic_dex_backend
export DEX_PRINCIPAL=$(dfx canister id icp_basic_dex_backend)

dfx identity use user1

# ===== テスト =====
# user1がトークンを取得する
echo '===== getToken ====='
EXPECT="(variant { Ok = 1_000 : nat })"
RESULT=`dfx canister call faucet getToken '(principal '\"$GoldDIP20_PRINCIPAL\"')'` 
compare_result "return 1_000" "$EXPECT" "$RESULT"

EXPECT="(variant { Err = variant { AlreadyGiven } })"
RESULT=`dfx canister call faucet getToken '(principal '\"$GoldDIP20_PRINCIPAL\"')'` 
compare_result "return Err AlreadyGiven" "$EXPECT" "$RESULT"

echo '===== deposit ====='
# approveをコールして、DEXがuser1の代わりにdepositすることを許可する
dfx canister call GoldDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 1_000)' > /dev/null
EXPECT="(variant { Ok = 1_000 : nat })"
RESULT=`dfx canister call icp_basic_dex_backend deposit '(principal '\"$GoldDIP20_PRINCIPAL\"')'` 
compare_result "return 1_000" "$EXPECT" "$RESULT"

EXPECT="(variant { Err = variant { BalanceLow } })"
RESULT=`dfx canister call icp_basic_dex_backend deposit '(principal '\"$GoldDIP20_PRINCIPAL\"')'` 
compare_result "return Err BalanceLow" "$EXPECT" "$RESULT"

echo '===== placeOrder ====='
EXPECT='(
  variant {
    Ok = opt record {
      id = 1 : nat32;
      to = principal "'$SilverDIP20_PRINCIPAL'";
      fromAmount = 100 : nat;
      owner = principal "'$USER1_PRINCIPAL'";
      from = principal "'$GoldDIP20_PRINCIPAL'";
      toAmount = 100 : nat;
    }
  },
)'
RESULT=`dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 100, principal '\"$SilverDIP20_PRINCIPAL\"', 100)'`
compare_result "return order details" "$EXPECT" "$RESULT"

echo '===== getOrders ====='
EXPECT='(
  vec {
    record {
      id = 1 : nat32;
      to = principal "'$SilverDIP20_PRINCIPAL'";
      fromAmount = 100 : nat;
      owner = principal "'$USER1_PRINCIPAL'";
      from = principal "'$GoldDIP20_PRINCIPAL'";
      toAmount = 100 : nat;
    };
  },
)'
RESULT=`dfx canister call icp_basic_dex_backend getOrders`
compare_result "return save order" "$EXPECT" "$RESULT"

# 重複するオーダーを出して、エラーが返ってくることを確認する
EXPECT="(variant { Err = variant { OrderBookFull } })"
RESULT=`dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 100, principal '\"$SilverDIP20_PRINCIPAL\"', 100)'`
compare_result "return Err OrderBookFull" "$EXPECT" "$RESULT"

echo '===== cancelOrder ====='
EXPECT="(variant { Ok = 1 : nat32 })"
RESULT=`dfx canister call icp_basic_dex_backend cancelOrder '(1)'`
compare_result "return cancel result" "$EXPECT" "$RESULT"

# 存在しないオーダーの削除を行うと、エラーが返ってくることを確認する
EXPECT="(variant { Err = variant { NotExistingOrder } })"
RESULT=`dfx canister call icp_basic_dex_backend cancelOrder '(1)'`
compare_result "return Err NotExistingOrder" "$EXPECT" "$RESULT"

# オーダーのオーナーではないユーザーが削除しようとするとエラーを出す
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 100, principal '\"$SilverDIP20_PRINCIPAL\"', 100)' > /dev/null
# オーダーのオーナーではないuser2に切り替え、削除を行う
dfx identity use user2
EXPECT="(variant { Err = variant { NotAllowed } })"
RESULT=`dfx canister call icp_basic_dex_backend cancelOrder '(2)'`
compare_result "return Err NotAllowed" "$EXPECT" "$RESULT"

# ===== 取引機能テストの準備 =====
# オーダーを購入するuser2に切り替える
dfx identity use user2
# トークンを付与する
dfx canister call faucet getToken '(principal '\"$SilverDIP20_PRINCIPAL\"')'
dfx canister call SilverDIP20 approve '(principal '\"$DEX_PRINCIPAL\"', 1_000)' > /dev/null
dfx canister call icp_basic_dex_backend deposit '(principal '\"$SilverDIP20_PRINCIPAL\"')' > /dev/null
# user1が出したオーダーを購入するために`placeOrder`を実行する
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$SilverDIP20_PRINCIPAL\"', 100, principal '\"$GoldDIP20_PRINCIPAL\"', 100)' > /dev/null
# ============================

# 取引が成立してオーダーが削除されていることを確認する
EXPECT="(vec {})"
RESULT=`dfx canister call icp_basic_dex_backend getOrders`
compare_result "return null" "$EXPECT" "$RESULT"

# トレード後のユーザー残高を確認する
echo '===== getBalance ====='
EXPECT="(100 : nat)"
RESULT=`dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER2_PRINCIPAL\"', principal '\"$GoldDIP20_PRINCIPAL\"')'`
compare_result "return 100" "$EXPECT" "$RESULT"

EXPECT="(900 : nat)"
RESULT=`dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER2_PRINCIPAL\"', principal '\"$SilverDIP20_PRINCIPAL\"')'`
compare_result "return 900" "$EXPECT" "$RESULT"

dfx identity use user1
EXPECT="(900 : nat)"
RESULT=`dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER1_PRINCIPAL\"', principal '\"$GoldDIP20_PRINCIPAL\"')'`
compare_result "return 900" "$EXPECT" "$RESULT"

EXPECT="(100 : nat)"
RESULT=`dfx canister call icp_basic_dex_backend getBalance '(principal '\"$USER1_PRINCIPAL\"', principal '\"$SilverDIP20_PRINCIPAL\"')'`
compare_result "return 100" "$EXPECT" "$RESULT"

echo '===== withdraw ====='
# [GoldDIP20 500 -> SilverDIP20 500]のオーダーを出す
## DEXキャニスターからトークンを引き出した後、残高不足(900 - 500 - 500 = -100)のためオーダーが削除されることを確認するため
dfx canister call icp_basic_dex_backend placeOrder '(principal '\"$GoldDIP20_PRINCIPAL\"', 500, principal '\"$SilverDIP20_PRINCIPAL\"', 500)' > /dev/null

EXPECT="(variant { Ok = 500 : nat })"
RESULT=`dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 500)'`
compare_result "return 500" "$EXPECT" "$RESULT"

# オーダーが削除されていることを確認する
EXPECT="(vec {})"
RESULT=`dfx canister call icp_basic_dex_backend getOrders`
compare_result "return (vec {})" "$EXPECT" "$RESULT"

# 残高以上の引き出しを行う
EXPECT="(variant { Err = variant { BalanceLow } })"
RESULT=`dfx canister call icp_basic_dex_backend withdraw '(principal '\"$GoldDIP20_PRINCIPAL\"', 1000)'`
compare_result "return Err BalanceLow" "$EXPECT" "$RESULT"

# ===== 後始末 =====
dfx identity use default
dfx identity remove user1
dfx identity remove user2
dfx stop

# ===== テスト結果の確認 =====
echo '===== Result ====='
if [ $TOTAL_FAILED -eq 0 ]; then
  echo "PASSED. $TOTAL_PASSED passed, $TOTAL_FAILED failed."
  exit 0
else
  echo "FAILED. $TOTAL_PASSED passed, $TOTAL_FAILED failed."
  exit 1
fi