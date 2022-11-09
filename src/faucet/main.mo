import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

import T "types";

actor class Faucet() {

  private let TOTAL_FAUCET_AMOUNT : Nat = 100_000;
  private let FAUCET_AMOUNT : Nat = 1_000;
  private var amount_counter : Nat = 0;

  // ユーザーとトークンPrincipalをマッピング
  // トークンPrincipalは、複数を想定して配列にする
  var faucet_book = HashMap.HashMap<Principal, [T.Token]>(
    10,
    Principal.equal,
    Principal.hash,
  );

  public shared (msg) func getToken(token : T.Token) : async T.FaucetReceipt {
    let faucet_receipt = checkDistribution(msg.caller, token);
    switch (faucet_receipt) {
      case (#Err e) {
        return #Err(e);
      };
      case _ {};
    };

    let faucet_amount = getFaucetAmount();

    // `Token` PrincipalでDIP20アクターのインスタンスを生成
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // トークンを転送する
    let txReceipt = await dip20.transfer(msg.caller, faucet_amount);
    switch txReceipt {
      case (#Err e) {
        return #Err(#FaucetFailure);
      };
      case _ {};
    };

    // 転送に成功したら、`faucet_book`に保存する
    addUser(msg.caller, token);
    return #Ok(faucet_amount);
  };

  // 一人に配布するトークン量を返す
  private func getFaucetAmount() : Nat {
    return FAUCET_AMOUNT;
  };

  // 既に配布したトータルのトークン量を返す
  private func getFaucetCount() : Nat {
    return amount_counter;
  };

  // トークンを配布したユーザーとそのトークンを保存する
  private func addUser(user : Principal, token : T.Token) {
    // 配布量を更新する
    amount_counter += FAUCET_AMOUNT;

    // 配布するトークンをユーザーに紐づけて保存する
    switch (faucet_book.get(user)) {
      case null {
        let new_data = Array.make<T.Token>(token);
        faucet_book.put(user, new_data);
      };
      case (?tokens) {
        let buff = Buffer.Buffer<T.Token>(2);
        for (token in tokens.vals()) {
          buff.add(token);
        };
        // ユーザーの情報を上書きする
        faucet_book.put(user, buff.toArray());
      };
    };
  };

  // Faucetとしてトークンを配布しているかどうかを確認する
  // 配布可能なら`#Ok`、不可能なら`#Err`を返す
  private func checkDistribution(user : Principal, token : T.Token) : T.FaucetReceipt {
    if (amount_counter >= TOTAL_FAUCET_AMOUNT) {
      return (#Err(#InsufficientToken));
    };

    switch (faucet_book.get(user)) {
      case null {
        return #Ok(FAUCET_AMOUNT);
      };
      case (?tokens) {
        switch (Array.find<T.Token>(tokens, func(x : T.Token) { x == token })) {
          case null {
            return #Ok(FAUCET_AMOUNT);
          };
          case (?token) return #Err(#AlreadyGiven);
        };
      };
    };
  };
};
