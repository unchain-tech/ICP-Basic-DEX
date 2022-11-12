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
    setCurrentPrincipalId,
  } = props;

  // Login Internet Identity handler
  const handleLogin = async () => {
    // Autofills the <input> for the II Url to point to the correct canister.
    console.log(`process.env.DFX_NETWORK: ${process.env.DFX_NETWORK}`);

    let iiUrl;
    if (process.env.DFX_NETWORK === "local") {
      iiUrl = `http://localhost:8000/?canisterId=${IICanisterID}`;
    } else if (process.env.DFX_NETWORK === "ic") {
      iiUrl = `https://${IICanisterID}.ic0.app`;
    } else {
      iiUrl = `https://${IICanisterID}.dfinity.network`;
    }
    // Start Login process.
    // First we have to create and AuthClient.
    const authClient = await AuthClient.create();

    // Login with Internet Identity.
    await new Promise((resolve, reject) => {
      authClient.login({
        identityProvider: iiUrl,
        onSuccess: resolve,
        onError: reject,
      });
    });
    // const result = await authClient.login({
    //   identityProvider: iiUrl,
    // });
    // console.log(`login: ${result}`);

    // Get the identity from the auth client:
    const identity = authClient.getIdentity();
    // Using the identity obtained from the auth client,
    // we can create an agent to interact with the IC.
    const newAgent = new HttpAgent({ identity });

    if (process.env.DFX_NETWORK === "local") {
      newAgent.fetchRootKey();
    }
    setAgent(newAgent);

    const principal = await authClient.getIdentity().getPrincipal();
    // Get information about the tokens held by the Logged-in user.
    updateUserTokens(newAgent, principal);
    // Set Order list
    updateOrderList(newAgent);
    setCurrentPrincipalId(principal.toText());
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