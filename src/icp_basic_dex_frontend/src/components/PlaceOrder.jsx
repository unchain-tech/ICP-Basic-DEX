import React, { useState } from 'react';
import { Principal } from '@dfinity/principal';
import { Actor } from "@dfinity/agent";
import { canisterId as DEXCanisterId }
  from '../../../declarations/icp_basic_dex_backend';
import { idlFactory as DEXidlFactory }
  from '../../../declarations/icp_basic_dex_backend/icp_basic_dex_backend.did.js';

export const PlaceOrder = (props) => {
  const {
    agent,
    currentPrincipalId,
    tokenCanisters,
    updateOrderList,
  } = props;

  const [order, setOrder] = useState({
    from: '',
    fromAmount: 0,
    to: '',
    toAmount: 0,
  })

  const handleChangeOrder = (event) => {
    setOrder((prevState) => {
      return {
        ...prevState,
        [event.target.name]: event.target.value,
      };
    });
  };

  const handleSubmitOrder = async (event) => {
    event.preventDefault();
    console.log(order);

    const DEXActor = Actor.createActor(DEXidlFactory, {
      agent,
      canisterId: DEXCanisterId,
    });

    // Get from token canister
    const fromTokenCanister = tokenCanisters.find(e => e.tokenSymbol === order.from);
    const fromPrincipal = fromTokenCanister.canisterId;
    // Get to token canister
    const toTokenCanister = tokenCanisters.find(e => e.tokenSymbol === order.to);
    const toPrincipal = toTokenCanister.canisterId;

    try {
      const resultPlace
        = await DEXActor.placeOrder(
          Principal.fromText(fromPrincipal),
          Number(order.fromAmount),
          Principal.fromText(toPrincipal),
          Number(order.toAmount),
        );
      // Check Error
      if (!resultPlace.Ok) {
        alert(`Error: ${Object.keys(resultPlace.Err)[0]}`);
        return;
      }

      // Update Order List
      updateOrderList(agent);

      console.log(`Created order:  ${resultPlace.Ok[0].id}`);
    } catch (error) {
      console.log(`handleSubmitOrder: ${error} `);
    }
  };

  return (
    <>
      {currentPrincipalId &&
        <div className="create-order-area">
          <div className="title">
            <p>PLACE ORDER</p>
          </div>
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
      }
    </>
  )
};