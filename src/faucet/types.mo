module {

  // ===== DIP20 TOKEN INTERFACE =====
  public type TxReceipt = {
    #Ok : Nat;
    #Err : {
      #InsufficientAllowance;
      #InsufficientBalance;
      #ErrorOperationStyle;
      #Unauthorized;
      #LedgerTrap;
      #ErrorTo;
      #Other : Text;
      #BlockUsed;
      #AmountTooSmall;
    };
  };

  public type DIPInterface = actor {
    balanceOf : (who : Principal) -> async Nat;
    transfer : (to : Principal, value : Nat) -> async TxReceipt;
  };

  // ===== FAUCET =====
  public type FaucetReceipt = {
    #Ok : Nat;
    #Err : {
      #AlreadyGiven;
      #FaucetFailure;
      #InsufficientToken;
    };
  };
};
