import React, { useEffect, useState } from 'react';
import './App.css';

import { HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import { Principal } from '@dfinity/principal';

import { icp_basic_dex_backend as DEX }
  from '../../declarations/icp_basic_dex_backend';
import { canisterId as GoldDIP20canisterId, createActor as GoldDIP20CreateActor, GoldDIP20 }
  from '../../declarations/GoldDIP20';
import { canisterId as SilverDIP20canisterId, createActor as SilverDIP20CreateActor, SilverDIP20 }
  from '../../declarations/SilverDIP20';

import { Header } from './components/Header';
import { UserBoard } from './components/UserBoard';
import { PlaceOrder } from './components/PlaceOrder';
import { ListOrder } from './components/ListOrder';

const App = () => {
  // DEX上で扱うトークンのデータを配列に格納
  const tokenCanisters = [
    {
      canisterName: 'GoldDIP20',
      canister: GoldDIP20,
      tokenSymbol: 'TGLD',
      createActor: GoldDIP20CreateActor,
      canisterId: GoldDIP20canisterId,
    },
    {
      canisterName: 'SilverDIP20',
      canister: SilverDIP20,
      tokenSymbol: 'TSLV',
      createActor: SilverDIP20CreateActor,
      canisterId: SilverDIP20canisterId,
    },
  ];

  const [agent, setAgent] = useState();
  const [userPrincipal, setUserPrincipal] = useState("");
  const [userTokens, setUserTokens] = useState([]);
  const [orderList, setOrderList] = useState([]);

  const updateUserTokens = async (principal) => {
    let tokens = [];
    // ユーザーの保有するトークンのデータを取得
    for (let i = 0; i < tokenCanisters.length; ++i) {
      // トークンのメタデータを取得
      const metadata = await tokenCanisters[i].canister.getMetadata();
      // ユーザーのトークン保有量を取得
      const balance = await tokenCanisters[i].canister.balanceOf(principal);
      // DEXに預けているトークン量を取得
      const dexBalance
        = await DEX.getBalance(principal, Principal.fromText(tokenCanisters[i].canisterId))

      // 取得したデータを格納
      const userToken = {
        symbol: metadata.symbol.toString(),
        balance: balance.toString(),
        dexBalance: dexBalance.toString(),
        fee: metadata.fee.toString(),
      }
      tokens.push(userToken);
    }
    setUserTokens(tokens);
  }

  // オーダー一覧を更新する
  const updateOrderList = async () => {
    const orders = await DEX.getOrders();
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
    setOrderList(createdOrderList);
  }

  // ユーザーがログイン認証済みかを確認
  const checkClientIdentity = async () => {
    try {
      const authClient = await AuthClient.create();
      const resultAuthenticated = await authClient.isAuthenticated();
      // 認証済みであればPrincipalを取得
      if (resultAuthenticated) {
        const identity = authClient.getIdentity();
        const principal = identity.getPrincipal();
        // ICと対話する`agent`を作成する
        const newAgent = new HttpAgent({ identity });
        // ローカル環境の`agent`はICの公開鍵を持っていないため、`fetchRootKey()`で鍵を取得する
        if (process.env.DFX_NETWORK === "local") {
          newAgent.fetchRootKey();
        }

        updateUserTokens(principal);
        updateOrderList();
        setUserPrincipal(principal.toText());
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
            tokenCanisters={tokenCanisters}
            userPrincipal={userPrincipal}
            userTokens={userTokens}
            setUserTokens={setUserTokens}
          />
          <PlaceOrder
            agent={agent}
            tokenCanisters={tokenCanisters}
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