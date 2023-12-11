/* eslint-disable no-console */
import "./App.css";
import React, { useEffect, useState } from "react";

function App() {
  const [address, setAddress] = useState<string | undefined>(undefined);
  const [publicKey, setPublicKey] = useState<string | undefined>(undefined);
  const [isConnected, setIsConnected] = useState<boolean | undefined>(undefined);
  const [network, setNetwork] = useState<string | undefined>(undefined);
  const [isSubmittingTransaction, setIsSubmittingTransaction] = useState<boolean>(false);

  const transaction = {
    arguments: [],
    // Prod:
    function: "0xf15c374bcaf95b011c53b65bd5efdd35d12ba5bdee58dab2c8831e9f0bcb4c27::minter::claim_mint",
    // Test:
    // function: "0x5795f1a0ebfabdbe1860c3588e88b70ce3a687a7a831b0f1cc35185e9f154209::minter::claim_mint",
    type: "entry_function_payload",
    type_arguments: [],
  };

  useEffect(() => {
    async function fetchStatus() {
      const isAlreadyConnected = await window.aptos.isConnected();
      setIsConnected(isAlreadyConnected);
      if (isAlreadyConnected) {
        const [activeAccount, activeNetworkName] = await Promise.all([
          window.aptos.account(),
          window.aptos.network(),
        ]);
        setAddress(activeAccount.address);
        setPublicKey(activeAccount.publicKey);
        setNetwork(activeNetworkName);
      } else {
        setAddress(undefined);
        setPublicKey(undefined);
        setNetwork(undefined);
      }
    }

    window.aptos.onAccountChange(async (account: any) => {
      if (account.address) {
        setIsConnected(true);
        setAddress(account.address);
        setPublicKey(account.publicKey);
        setNetwork(await window.aptos.network());
      } else {
        setIsConnected(false);
        setAddress(undefined);
        setPublicKey(undefined);
        setNetwork(undefined);
      }
    });

    window.aptos.onNetworkChange((params: any) => {
      setNetwork(params.networkName);
    });

    window.aptos.onDisconnect(() => {
      console.log("Disconnected");
    });

    fetchStatus();
  }, []);

  const onConnectClick = async () => {
    if (isConnected) {
      await window.aptos.disconnect();
      setIsConnected(false);
      setAddress(undefined);
      setPublicKey(undefined);
      setNetwork(undefined);
    } else {
      const activeAccount = await window.aptos.connect();
      const activeNetworkName = await window.aptos.network();
      setIsConnected(true);
      setAddress(activeAccount.address);
      setPublicKey(activeAccount.publicKey);
      setNetwork(activeNetworkName);
    }
  };

  const onSubmitTransactionClick = async () => {
    if (!isSubmittingTransaction) {
      setIsSubmittingTransaction(true);
      try {
        const pendingTransaction = await window.aptos.signAndSubmitTransaction(transaction);
        console.log(pendingTransaction);
      } catch (error) {
        console.error(error);
      }
      setIsSubmittingTransaction(false);
    }
  };

  const txnText = isSubmittingTransaction ? "Minting..." : "Submit Mint Transaction";

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          Max's IIT Selfie Mint
        </h1>
        <p>
          {isConnected ? `Address: ${address}` : "Not Connected"}
        </p>
        <p>
          {`Network: ${network}`}
        </p>

        <h3 style={{ fontSize: "12px" }}>Connect the wallet, and mint an NFT!</h3>

        <button className="Button" type="button" style={{ margin: "5px" }}
                onClick={onConnectClick}>{isConnected ? "Disconnect" : "Connect"}</button>
        <button className="Button" type="button"
                onClick={onSubmitTransactionClick}>{txnText}</button>
      </header>
    </div>
  );
}

export default App;
