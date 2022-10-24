module {
    public type Token = Principal;

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

    public type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat8;
        totalSupply : Nat;
        owner : Principal;
        fee : Nat;
    };

    public type DIPInterface = actor {
        allowance : (owner : Principal, spender : Principal) -> async Nat;
        faucet : (to : Principal, value : Nat) -> async TxReceipt;
        getMetadata : () -> async Metadata;
        mint : (to : Principal, value : Nat) -> async TxReceipt;
        transfer : (to : Principal, value : Nat) -> async TxReceipt;
        transferFrom : (from : Principal, to : Principal, value : Nat) -> async TxReceipt;
    };

    public type DepositReceipt = {
        #Ok : Nat;
        // #Err : DepositErr;
        #Err : {
            #BalanceLow;
            #TransferFailure;
        };
    };

    public type WithdrawReceipt = {
        #Ok : Nat;
        // #Err : WithdrawErr;
        #Err : {
            #BalanceLow;
            #TransferFailure;
        };
    };

    public type Balance = {
        owner : Principal;
        token : Principal;
        amount : Nat;
    };
};
