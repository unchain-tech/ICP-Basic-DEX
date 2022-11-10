import React, { useEffect, useState } from 'react';
import './App.css';

import { Actor, HttpAgent } from "@dfinity/agent";
import { AuthClient } from "@dfinity/auth-client";
import { Principal } from '@dfinity/principal';

import { canisterId as DEXCanisterId }
  from '../../declarations/icp_basic_dex_backend';
import { idlFactory as DEXidlFactory }
  from '../../declarations/icp_basic_dex_backend/icp_basic_dex_backend.did.js';
import { canisterId as GoldDIP20canisterId }
  from '../../declarations/GoldDIP20';
import { idlFactory as GoldIdlFactory }
  from '../../declarations/GoldDIP20/GoldDIP20.did.js';
import { canisterId as SilverDIP20canisterId }
  from '../../declarations/SilverDIP20';
import { idlFactory as SilverIdlFactory }
  from '../../declarations/SilverDIP20/SilverDIP20.did.js';

import { Header } from './components/Header';
import { UserBoard } from './components/UserBoard';
import { PlaceOrder } from './components/PlaceOrder';
import { ListOrder } from './components/ListOrder';

const App = () => {

  const tokenCanisters = [
    {
      canisterName: 'GoldDIP20',
      tokenSymbol: 'TGD',
      factory: GoldIdlFactory,
      canisterId: GoldDIP20canisterId,
    },
    {
      canisterName: 'SilverDIP20',
      tokenSymbol: 'TSV',
      factory: SilverIdlFactory,
      canisterId: SilverDIP20canisterId,
    },
  ];

  const [agent, setAgent] = useState();

  const [currentPrincipalId, setCurrentPrincipalId] = useState("");

  const [userTokens, setUserTokens] = useState([]);

  const [orderList, setOrderList] = useState([]);

  const updateUserTokens = async (agent, principal) => {
    const DEXActor = Actor.createActor(DEXidlFactory, {
      agent,
      canisterId: DEXCanisterId,
    });

    let tokens = [];
    // Get information about the tokens held by the Logged-in user.
    for (let i = 0; i < tokenCanisters.length; ++i) {
      const tokenActor = Actor.createActor(tokenCanisters[i].factory, {
        agent,
        canisterId: tokenCanisters[i].canisterId,
      });

      // Get metadata of token.
      const metadata = await tokenActor.getMetadata();
      // Get token held by user.
      const balance = await tokenActor.balanceOf(principal);

      // Get token balance deposited by the user in the DEX.
      const dexBalance
        = await DEXActor.getBalance(Principal.fromText(tokenCanisters[i].canisterId));
      console.log(`dexBalance: ${dexBalance}`);

      // Set information of user.
      const userToken = {
        symbol: metadata.symbol.toString(),
        balance: balance.toString(),
        dexBalance: dexBalance.toString(),
        fee: metadata.fee.toString(),
      }
      tokens.push(userToken);
    }
    // return tokens;
    setUserTokens(tokens);
  }

  const updateOrderList = async (agent) => {
    const DEXActor = Actor.createActor(DEXidlFactory, {
      agent,
      canisterId: DEXCanisterId,
    });

    // Set Order list
    const orders = await DEXActor.getOrders();
    const createdOrderList = orders.map((order) => {
      return {
        id: order.id,
        from: order.from,
        fromSymbol: tokenCanisters.find(e => e.canisterId === order.from.toString()).tokenSymbol,
        fromAmount: order.fromAmount,
        to: order.to,
        toSymbol: tokenCanisters.find(e => e.canisterId === order.to.toString()).tokenSymbol,
        toAmount: order.toAmount,
      }
    })
    // return orders;
    setOrderList(createdOrderList);
  }

  const checkClientIdentity = async () => {
    try {
      const authClient = await AuthClient.create();
      const resultAuthenticated = await authClient.isAuthenticated();
      if (resultAuthenticated) {
        const principal = authClient.getIdentity().getPrincipal();
        console.log(`principal: ${principal.toText()}`);
        setCurrentPrincipalId(principal.toText());

        // Using the identity obtained from the auth client,
        // we can create an agent to interact with the IC.
        const identity = authClient.getIdentity();
        const newAgent = new HttpAgent({ identity });

        if (process.env.DFX_NETWORK === "local") {
          newAgent.fetchRootKey();
        }

        updateUserTokens(newAgent, principal);
        updateOrderList(newAgent);
        setAgent(newAgent);
      } else {
        console.log(`isAuthenticated: ${resultAuthenticated}`);
      }
    } catch (error) {
      console.log(`checkClientIdentity: ${error}`);
    }
  }

  // ページがリロードされた時、以下の関数を実行
  useEffect(() => {
    console.log('useEffect');
    checkClientIdentity();
  }, [])

  return (
    <>
      <Header
        updateOrderList={updateOrderList}
        updateUserTokens={updateUserTokens}
        setAgent={setAgent}
        setCurrentPrincipalId={setCurrentPrincipalId}
      />
      <main className="app">
        <UserBoard
          agent={agent}
          tokenCanisters={tokenCanisters}
          currentPrincipalId={currentPrincipalId}
          userTokens={userTokens}
          setUserTokens={setUserTokens}
        />
        <PlaceOrder
          agent={agent}
          tokenCanisters={tokenCanisters}
          currentPrincipalId={currentPrincipalId}
          updateOrderList={updateOrderList}
        />
        <ListOrder
          agent={agent}
          currentPrincipalId={currentPrincipalId}
          orderList={orderList}
          updateOrderList={updateOrderList}
          updateUserTokens={updateUserTokens}
        />
      </main>
    </>
  )
};

export default App;