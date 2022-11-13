import React, { useEffect, useState } from 'react';
import './App.css';

import { HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import { Principal } from '@dfinity/principal';

import { icp_basic_dex_backend as DEX }
  from '../../declarations/icp_basic_dex_backend';
import { Header } from './components/Header';
import { UserBoard } from './components/UserBoard';
import { PlaceOrder } from './components/PlaceOrder';
import { ListOrder } from './components/ListOrder';
import { tokens } from './utils/token';

const App = () => {
  const [agent, setAgent] = useState();
  const [userPrincipal, setUserPrincipal] = useState();
  const [userTokens, setUserTokens] = useState([]);
  const [orderList, setOrderList] = useState([]);

  const updateUserTokens = async (principal) => {
    let getTokens = [];
    // ユーザーの保有するトークンのデータを取得
    for (let i = 0; i < tokens.length; ++i) {
      // トークンのメタデータを取得
      const metadata = await tokens[i].canister.getMetadata();
      // ユーザーのトークン保有量を取得
      const balance = await tokens[i].canister.balanceOf(principal);
      // DEXに預けているトークン量を取得
      const dexBalance
        = await DEX.getBalance(principal, Principal.fromText(tokens[i].canisterId))

      // 取得したデータを格納
      const userToken = {
        symbol: metadata.symbol.toString(),
        balance: balance.toString(),
        dexBalance: dexBalance.toString(),
        fee: metadata.fee.toString(),
      }
      getTokens.push(userToken);
    }
    setUserTokens(getTokens);
  }

  // オーダー一覧を更新する
  const updateOrderList = async () => {
    const orders = await DEX.getOrders();
    const createdOrderList = orders.map((order) => {
      const fromToken = tokens.find(
        e => e.canisterId === order.from.toString()
      );

      return {
        id: order.id,
        from: order.from,
        fromSymbol: fromToken.tokenSymbol,
        fromAmount: order.fromAmount,
        to: order.to,
        toSymbol: tokens.find(
          e => e.canisterId === order.to.toString()
        ).tokenSymbol,
        toAmount: order.toAmount,
      }
    })
    setOrderList(createdOrderList);
  }

  // ユーザーがログイン認証済みかを確認
  const checkClientIdentity = async () => {
    try {
      const authClient = await AuthClient.create();
      const resultAuthenticated = await authClient.isAuthenticated();
      // 認証済みであればPrincipalを取得
      if (resultAuthenticated) {
        const identity = await authClient.getIdentity();
        // ICと対話する`agent`を作成する
        const newAgent = new HttpAgent({ identity });
        // ローカル環境の`agent`はICの公開鍵を持っていないため、`fetchRootKey()`で鍵を取得する
        if (process.env.DFX_NETWORK === "local") {
          newAgent.fetchRootKey();
        }

        updateUserTokens(identity.getPrincipal());
        updateOrderList();
        setUserPrincipal(identity.getPrincipal());
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
    checkClientIdentity();
  }, [])

  return (
    <>
      <Header
        updateOrderList={updateOrderList}
        updateUserTokens={updateUserTokens}
        setAgent={setAgent}
        setUserPrincipal={setUserPrincipal}
      />
      {/* ログイン認証していない時 */}
      {!userPrincipal &&
        <div className='title'>
          <h1>Welcome!</h1>
          <h2>Please push the login button.</h2>
        </div>
      }
      {/* ログイン認証済みの時 */}
      {userPrincipal &&
        <main className="app">
          <UserBoard
            agent={agent}
            userPrincipal={userPrincipal}
            userTokens={userTokens}
            setUserTokens={setUserTokens}
          />
          <PlaceOrder
            agent={agent}
            updateOrderList={updateOrderList}
          />
          <ListOrder
            agent={agent}
            userPrincipal={userPrincipal}
            orderList={orderList}
            updateOrderList={updateOrderList}
            updateUserTokens={updateUserTokens}
          />
        </main>
      }
    </>
  )
};

export default App;