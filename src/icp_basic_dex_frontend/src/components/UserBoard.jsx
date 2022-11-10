import React from 'react';
import { Actor } from "@dfinity/agent";
import { Principal } from '@dfinity/principal';
import { canisterId as DEXCanisterId }
  from '../../../declarations/icp_basic_dex_backend';
import { idlFactory as DEXidlFactory }
  from '../../../declarations/icp_basic_dex_backend/icp_basic_dex_backend.did.js';
import { canisterId as faucetCanisterId }
  from '../../../declarations/faucet';
import { idlFactory as faucetFactory }
  from '../../../declarations/faucet/faucet.did.js';

export const UserBoard = (props) => {
  const {
    agent,
    currentPrincipalId,
    tokenCanisters,
    userTokens,
    setUserTokens,
  } = props;

  const handleDeposit = async (updateIndex) => {
    try {
      const DEXActor = Actor.createActor(DEXidlFactory, {
        agent,
        canisterId: DEXCanisterId,
      });
      const tokenActor = Actor.createActor(tokenCanisters[updateIndex].factory, {
        agent,
        canisterId: tokenCanisters[updateIndex].canisterId,
      });

      // Approve user token transfer by DEX.
      const resultApprove
        = await tokenActor.approve(Principal.fromText(DEXCanisterId), 5000);
      console.log(`resultApprove: ${resultApprove.Ok}`);
      // Deposit token from token canister to DEX.
      const resultDeposit
        = await DEXActor.deposit(Principal.fromText(tokenCanisters[updateIndex].canisterId));
      console.log(`resultDeposit: ${resultDeposit.Ok}`);
      // Get updated balance of token Canister.
      const balance
        = await tokenActor.balanceOf(Principal.fromText(currentPrincipalId));
      // Get updated balance in DEX.
      const dexBalance
        = await DEXActor.getBalance(Principal.fromText(tokenCanisters[updateIndex].canisterId));

      // Set new user information.
      setUserTokens(
        userTokens.map((userToken, index) => (
          index === updateIndex ? {
            symbol: userToken.symbol,
            balance: balance.toString(),
            dexBalance: dexBalance.toString(),
            fee: userToken.fee,
          } : userToken))
      );

    } catch (error) {
      console.log(`handleDeposit: ${error} `);
    }
  };

  const handleWithdraw = async (updateIndex) => {
    try {
      const DEXActor = Actor.createActor(DEXidlFactory, {
        agent,
        canisterId: DEXCanisterId,
      });
      const tokenActor = Actor.createActor(tokenCanisters[updateIndex].factory, {
        agent,
        canisterId: tokenCanisters[updateIndex].canisterId,
      });

      const resultWithdraw
        = await DEXActor.withdraw(Principal.fromText(tokenCanisters[updateIndex].canisterId), 5000);
      console.log(`resultWithdraw: ${resultWithdraw.Ok}`);
      // Get updated balance of token Canister.
      const balance
        = await tokenActor.balanceOf(Principal.fromText(currentPrincipalId));
      // Get updated balance in DEX.
      const dexBalance
        = await DEXActor.getBalance(Principal.fromText(tokenCanisters[updateIndex].canisterId));

      // Set new user information.
      setUserTokens(
        userTokens.map((userToken, index) => (
          index === updateIndex ? {
            symbol: userToken.symbol,
            balance: balance.toString(),
            dexBalance: dexBalance.toString(),
            fee: userToken.fee,
          } : userToken))
      );

    } catch (error) {
      console.log(`handleWithdraw: ${error} `);
    }
  };

  const handleFaucet = async (updateIndex) => {
    try {
      const faucetActor = Actor.createActor(faucetFactory, {
        agent,
        canisterId: faucetCanisterId,
      });
      const tokenActor = Actor.createActor(tokenCanisters[updateIndex].factory, {
        agent,
        canisterId: tokenCanisters[updateIndex].canisterId,
      });

      const resultFaucet
        = await faucetActor.getToken(Principal.fromText(tokenCanisters[updateIndex].canisterId));
      // Check Error
      if (!resultFaucet.Ok) {
        alert(`Error: ${Object.keys(resultFaucet.Err)[0]}`);
        return;
      }
      console.log(`resultFaucet: ${resultFaucet.Ok}`);

      // Get updated balance of token Canister.
      const balance
        = await tokenActor.balanceOf(Principal.fromText(currentPrincipalId));

      // Set new user information.
      setUserTokens(
        userTokens.map((userToken, index) => (
          index === updateIndex ? {
            symbol: userToken.symbol,
            balance: balance.toString(),
            dexBalance: userToken.dexBalance,
            fee: userToken.fee,
          } : userToken))
      );

    } catch (error) {
      console.log(`handleFaucet: ${error}`);
    }
  }

  return (
    <>
      {currentPrincipalId &&
        <div className="token-list">
          <h2>User</h2>
          <li>principal ID: {currentPrincipalId}</li>
          <table>
            <tbody>
              <tr>
                <th>Token</th>
                <th>Balance</th>
                <th>DEX Balance</th>
                <th>Fee</th>
                <th>Action</th>
              </tr>
              {userTokens.map((token, index) => {
                return (
                  <tr key={`${index} : ${token.symbol} `}>
                    <td data-th="Token">{token.symbol}</td>
                    <td data-th="Balance">{token.balance}</td>
                    <td data-th="DEX Balance">{token.dexBalance}</td>
                    <td data-th="Fee">{token.fee}</td>
                    <td data-th="Action">
                      <div className="btn-token">
                        <button
                          className='btn-deposit'
                          onClick={() => handleDeposit(index)}
                        >
                          Deposit
                        </button>
                        <button
                          className='btn-withdraw'
                          onClick={() => handleWithdraw(index)}
                        >
                          Withdraw
                        </button>
                        <button
                          className='btn-faucet'
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
      }
    </>
  )
};