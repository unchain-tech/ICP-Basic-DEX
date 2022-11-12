import React from 'react';

import { Actor } from '@dfinity/agent';
import { canisterId as DEXCanisterId }
  from '../../../declarations/icp_basic_dex_backend';
import { idlFactory as DEXidlFactory }
  from '../../../declarations/icp_basic_dex_backend/icp_basic_dex_backend.did.js';
import { Principal } from '@dfinity/principal';

export const ListOrder = (props) => {
  const { agent, currentPrincipalId, orderList, updateOrderList, updateUserTokens } = props;

  // Buy order hander
  const handleBuyOrder = async (order) => {
    // Create DEX actor
    const DEXActor = Actor.createActor(DEXidlFactory, {
      agent,
      canisterId: DEXCanisterId,
    });
    try {

      // Call placeOrder
      const resultPlace
        = await DEXActor.placeOrder(
          order.to,
          Number(order.toAmount),
          order.from,
          Number(order.fromAmount),
        );

      // Check Error
      if (!resultPlace.Ok) {
        alert(`Error: ${Object.keys(resultPlace.Err)[0]}`);
        return;
      }

      // Update order list
      updateOrderList(agent);

      // Update user balances
      updateUserTokens(agent, Principal.fromText(currentPrincipalId));

      console.log("Trade Successful!");
    } catch (error) {
      console.log(`handleBuyOrder: ${error} `);
    };
  };


  // Cancel order handler
  const handleCancelOrder = async (id) => {
    try {
      const DEXActor = Actor.createActor(DEXidlFactory, {
        agent,
        canisterId: DEXCanisterId,
      });

      // Call cancelOrder
      const resultCancel = await DEXActor.cancelOrder(id);

      // Check Error
      if (!resultCancel.Ok) {
        alert(`Error: ${Object.keys(resultCancel.Err)}`);
        return;
      }

      // Update orderbook
      updateOrderList(agent);

      console.log(`Canceled order ID: ${resultCancel.Ok}`);
    } catch (error) {
      console.log(`handleCancelOrder: ${error}`);
    }
  }


  return (
    <div className="order-list" style={{ backgroundColor: "rgb(8, 2, 38)" }}>
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
    </div>
  );
}