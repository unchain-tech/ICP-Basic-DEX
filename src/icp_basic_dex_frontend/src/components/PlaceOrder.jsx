import React, { useState } from 'react';
import { Principal } from '@dfinity/principal';
import { canisterId as DEXCanisterId, createActor }
  from '../../../declarations/icp_basic_dex_backend';

export const PlaceOrder = (props) => {
  const {
    agent,
    tokenCanisters,
    updateOrderList,
  } = props;

  // フォームに入力されたオーダーのデータを保存する
  const [order, setOrder] = useState({
    from: '',
    fromAmount: 0,
    to: '',
    toAmount: 0,
  })

  // フォームに入力されたデータを取得して、`order`に保存する
  const handleChangeOrder = (event) => {
    setOrder((prevState) => {
      return {
        ...prevState,
        [event.target.name]: event.target.value,
      };
    });
  };

  // ユーザーが入力したオーダーをDEXに登録する
  const handleSubmitOrder = async (event) => {
    // フォームが持つデフォルトの動作（フォームの内容をURLに送信）をキャンセルする
    event.preventDefault();
    console.log(`order: ${order}`);

    try {
      // ログインしているユーザーがDEXとやりとりを行うためにアクターを作成する
      const options = {
        agent: agent,
      };
      const DEXActor = createActor(DEXCanisterId, options);

      // `from`に入力されたトークンシンボルに一致するトークンデータを、`tokenCanisters[]`から取得
      const fromTokenCanister = tokenCanisters.find(e => e.tokenSymbol === order.from);
      const fromPrincipal = fromTokenCanister.canisterId;
      // `to`に入力されたトークンシンボルに一致するトークンデータを、`tokenCanisters[]`から取得
      const toTokenCanister = tokenCanisters.find(e => e.tokenSymbol === order.to);
      const toPrincipal = toTokenCanister.canisterId;

      const resultPlace
        = await DEXActor.placeOrder(
          Principal.fromText(fromPrincipal),
          Number(order.fromAmount),
          Principal.fromText(toPrincipal),
          Number(order.toAmount),
        );
      if (!resultPlace.Ok) {
        alert(`Error: ${Object.keys(resultPlace.Err)[0]}`);
        return;
      }
      console.log(`Created order:  ${resultPlace.Ok[0].id}`);

      // オーダーが登録されたので、一覧を更新する
      updateOrderList();

    } catch (error) {
      console.log(`handleSubmitOrder: ${error} `);
    }
  };

  return (
    <>
      <div className="place-order">
        <div className="title">
          <p>PLACE ORDER</p>
        </div>
        {/* オーダーを入力するフォームを表示 */}
        <form className="form" onSubmit={handleSubmitOrder} >
          <div>
            <div>
              <label>From</label>
              <select
                name="from"
                type="from"
                onChange={handleChangeOrder}
                required>
                <option value="">Select token</option>
                <option value="TGLD">TGLD</option>
                <option value="TSLV">TSLV</option>
              </select>
            </div>
            <div>
              <label>Amount</label>
              <input
                name="fromAmount"
                type="number"
                onChange={handleChangeOrder}
                required
              />
            </div>
            <div>
              <span>→</span>
            </div>
            <div>
              <label>To</label>
              <select
                name="to"
                type="to"
                onChange={handleChangeOrder}
                required>
                <option value="">Select token</option>
                <option value="TGLD">TGLD</option>
                <option value="TSLV">TSLV</option>
              </select>
            </div>
            <div>
              <label>Amount</label>
              <input
                name="toAmount"
                type="number"
                onChange={handleChangeOrder}
                required
              />
            </div>
          </div>
          <button
            className='btn-green'
            type="submit"
          >
            Submit Order
          </button>
        </form>
      </div>
    </>
  )
};