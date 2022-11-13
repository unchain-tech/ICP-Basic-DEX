import React from 'react';

import {
  canisterId as DEXCanisterId,
  createActor
} from '../../../declarations/icp_basic_dex_backend';

export const ListOrder = (props) => {
  const {
    agent,
    userPrincipal,
    orderList,
    updateOrderList,
    updateUserTokens
  } = props;

  const createDEXActor = () => {
    // ログインしているユーザーを設定する
    const options = {
      agent: agent,
    }
    return createActor(DEXCanisterId, options);
  }

  // オーダーの購入を実行する
  const handleBuyOrder = async (order) => {
    try {
      const DEXActor = createDEXActor();
      // オーダーのデータを`placeOrder()`に渡す
      const resultPlace
        = await DEXActor.placeOrder(
          order.to,
          Number(order.toAmount),
          order.from,
          Number(order.fromAmount),
        );
      if (!resultPlace.Ok) {
        alert(`Error: ${Object.keys(resultPlace.Err)[0]}`);
        return;
      }
      // 取引が実行されたため、オーダー一覧を更新する
      updateOrderList();
      // ユーザーボード上のトークンデータを更新する
      updateUserTokens(userPrincipal);

      console.log("Trade Successful!");
    } catch (error) {
      console.log(`handleBuyOrder: ${error} `);
    };
  };

  // オーダーのキャンセルを実行する
  const handleCancelOrder = async (id) => {
    try {
      const DEXActor = createDEXActor();
      // キャンセルしたいオーダーのIDを`cancelOrder()`に渡す
      const resultCancel = await DEXActor.cancelOrder(id);
      if (!resultCancel.Ok) {
        alert(`Error: ${Object.keys(resultCancel.Err)}`);
        return;
      }
      // キャンセルが実行されたため、オーダー一覧を更新する
      updateOrderList();

      console.log(`Canceled order ID: ${resultCancel.Ok}`);
    } catch (error) {
      console.log(`handleCancelOrder: ${error}`);
    }
  }

  return (
    <div className="list-order">
      <p>Order</p>
      <table>
        <tbody>
          <tr>
            <th>From</th>
            <th>Amount</th>
            <th></th>
            <th>To</th>
            <th>Amount</th>
            <th>Action</th>
          </tr>
          {/* オーダー一覧を表示する */}
          {orderList.map((order, index) => {
            return (
              <tr key={`${index}: ${order.token} `} >
                <td data-th="From">{order.fromSymbol}</td>
                <td data-th="Amount">{order.fromAmount.toString()}</td>
                <td>→</td>
                <td data-th="To">{order.toSymbol}</td>
                <td data-th="Amount">{order.toAmount.toString()}</td>
                <td data-th="Action">
                  <div>
                    {/* オーダーに対して操作（Buy, Cancel）を行うボタンを表示 */}
                    <button
                      className="btn-green"
                      onClick={() => handleBuyOrder(order)}
                    >Buy</button>
                    <button
                      className="btn-red"
                      onClick={() => handleCancelOrder(order.id)}
                    >Cancel</button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div >
  );
}