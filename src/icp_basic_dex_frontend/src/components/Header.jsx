import React from 'react';
import { AuthClient } from '@dfinity/auth-client';
import { HttpAgent } from '@dfinity/agent';
import { canisterId as IICanisterID }
  from '../../../declarations/internet_identity';

export const Header = (props) => {
  const {
    updateOrderList,
    updateUserTokens,
    setAgent,
    setUserPrincipal,
  } = props;

  const handleSuccess = (authClient) => {
    // 認証したユーザーの`identity`を取得
    const identity = authClient.getIdentity();

    // 認証したユーザーの`principal`を取得
    const principal = identity.getPrincipal();

    // 取得した`identity`を使用して、ICと対話する`agent`を作成する
    const newAgent = new HttpAgent({ identity });
    if (process.env.DFX_NETWORK === "local") {
      newAgent.fetchRootKey();
    }

    // 認証したユーザーが保有するトークンのデータを取得
    updateUserTokens(principal);
    // オーダー一覧を取得
    updateOrderList();
    // ユーザーのデータを保存
    setUserPrincipal(principal.toText());
    setAgent(newAgent);
  };

  const handleLogin = async () => {
    // アプリケーションが接続しているネットワークに応じて、
    // ユーザー認証に使用するInternet IdentityのURLを決定する
    let iiUrl;
    if (process.env.DFX_NETWORK === "local") {
      iiUrl = `http://localhost:8000/?canisterId=${IICanisterID}`;
    } else if (process.env.DFX_NETWORK === "ic") {
      // iiUrl = `https://${IICanisterID}.ic0.app`;
      iiUrl = 'https://identity.ic0.app/#authorize'; // TODO: mainnetにデプロイしたときに問題ないかチェック
    } else {
      iiUrl = `https://${IICanisterID}.dfinity.network`;
    }
    // ログイン認証を実行
    const authClient = await AuthClient.create();
    authClient.login({
      identityProvider: iiUrl,
      onSuccess: handleSuccess(authClient),
      onError: (error) => {
        console.error(`Login Failed: , ${error}`);
      }
    })
  };

  return (
    <ul>
      <li>SIMPLE DEX</li>
      <li style={{ float: 'right' }}>
        <button
          onClick={handleLogin}>
          Login Internet Identity
        </button>
      </li>
    </ul>
  )
}