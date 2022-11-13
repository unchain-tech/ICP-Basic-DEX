import React from 'react';

import { Principal } from '@dfinity/principal';
import {
  canisterId as DEXCanisterId,
  createActor as DEXCreateActor,
  icp_basic_dex_backend as DEX
} from '../../../declarations/icp_basic_dex_backend';
import {
  canisterId as faucetCanisterId,
  createActor as faucetCreateActor
} from '../../../declarations/faucet';

import { tokens } from '../utils/token';

export const UserBoard = (props) => {
  const {
    agent,
    userPrincipal,
    userTokens,
    setUserTokens,
  } = props;

  const TOKEN_AMOUNT = 500;

  const options = {
    agent: agent,
  }

  // ユーザーボード上のトークンデータを更新する
  const updateUserToken = async (updateIndex) => {
    // ユーザーが保有するトークン量を取得
    const balance
      = await tokens[updateIndex].canister.balanceOf(userPrincipal);
    // ユーザーがDEXに預けたトークン量を取得
    const dexBalance
      = await DEX.getBalance(
        userPrincipal,
        Principal.fromText(tokens[updateIndex].canisterId))

    setUserTokens(
      userTokens.map((userToken, index) => (
        index === updateIndex ? {
          symbol: userToken.symbol,
          balance: balance.toString(),
          dexBalance: dexBalance.toString(),
          fee: userToken.fee,
        } : userToken))
    );
  }

  const handleDeposit = async (updateIndex) => {
    try {
      const DEXActor = DEXCreateActor(DEXCanisterId, options);
      const tokenActor
        = tokens[updateIndex].createActor(
          tokens[updateIndex].canisterId,
          options
        );

      // ユーザーの代わりにDEXがトークンを転送することを承認する
      const resultApprove
        = await tokenActor.approve(Principal.fromText(DEXCanisterId), TOKEN_AMOUNT);
      if (!resultApprove.Ok) {
        alert(`Error: ${Object.keys(resultApprove.Err)[0]}`);
        return;
      }
      // DEXにトークンを入金する
      const resultDeposit
        = await DEXActor.deposit(Principal.fromText(tokens[updateIndex].canisterId));
      if (!resultDeposit.Ok) {
        alert(`Error: ${Object.keys(resultDeposit.Err)[0]}`);
        return;
      }
      console.log(`resultDeposit: ${resultDeposit.Ok}`);

      updateUserToken(updateIndex);
    } catch (error) {
      console.log(`handleDeposit: ${error} `);
    }
  };

  const handleWithdraw = async (updateIndex) => {
    try {
      const DEXActor = DEXCreateActor(DEXCanisterId, options);
      // DEXからトークンを出金する
      const resultWithdraw
        = await DEXActor.withdraw(Principal.fromText(tokens[updateIndex].canisterId), TOKEN_AMOUNT);
      if (!resultWithdraw.Ok) {
        alert(`Error: ${Object.keys(resultWithdraw.Err)[0]}`);
        return;
      }
      console.log(`resultWithdraw: ${resultWithdraw.Ok}`);

      updateUserToken(updateIndex);
    } catch (error) {
      console.log(`handleWithdraw: ${error} `);
    }
  };

  // Faucetからトークンを取得する
  const handleFaucet = async (updateIndex) => {
    try {
      const faucetActor = faucetCreateActor(faucetCanisterId, options);
      const resultFaucet
        = await faucetActor.getToken(Principal.fromText(tokens[updateIndex].canisterId));
      if (!resultFaucet.Ok) {
        alert(`Error: ${Object.keys(resultFaucet.Err)[0]}`);
        return;
      }
      console.log(`resultFaucet: ${resultFaucet.Ok}`);

      updateUserToken(updateIndex);
    } catch (error) {
      console.log(`handleFaucet: ${error}`);
    }
  }

  return (
    <>
      <div className="user-board">
        <h2>User</h2>
        <li>principal ID: {userPrincipal.toString()}</li>
        <table>
          <tbody>
            <tr>
              <th>Token</th>
              <th>Balance</th>
              <th>DEX Balance</th>
              <th>Fee</th>
              <th>Action</th>
            </tr>
            {/* トークンのデータを一覧表示する */}
            {userTokens.map((token, index) => {
              return (
                <tr key={`${index} : ${token.symbol} `}>
                  <td data-th="Token">{token.symbol}</td>
                  <td data-th="Balance">{token.balance}</td>
                  <td data-th="DEX Balance">{token.dexBalance}</td>
                  <td data-th="Fee">{token.fee}</td>
                  <td data-th="Action">
                    <div>
                      {/* トークンに対して行う操作（Deposit / Withdraw / Faucet）のボタンを表示 */}
                      <button
                        className='btn-green'
                        onClick={() => handleDeposit(index)}
                      >
                        Deposit
                      </button>
                      <button
                        className='btn-red'
                        onClick={() => handleWithdraw(index)}
                      >
                        Withdraw
                      </button>
                      <button
                        className='btn-blue'
                        onClick={() => handleFaucet(index)}
                      >
                        Faucet
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  )
};