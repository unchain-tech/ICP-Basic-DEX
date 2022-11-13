import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

import T "types";

shared (msg) actor class Faucet() = this {
  private type Token = Principal;

  private let TOTAL_FAUCET_AMOUNT : Nat = 100_000;
  private let FAUCET_AMOUNT : Nat = 1_000;
  private let owner : Principal = msg.caller;

  // アップグレード時にトークンを配布したユーザーを保存しておく`stable`変数
  private stable var faucetBookEntries : [var (Principal, [Token])] = [var];

  // ユーザーとトークンPrincipalをマッピング
  // トークンPrincipalは、複数を想定して配列にする
  private var faucet_book = HashMap.HashMap<Principal, [Token]>(
    10,
    Principal.equal,
    Principal.hash,
  );

  public shared (msg) func getToken(token : Token) : async T.FaucetReceipt {
    let faucet_receipt = await checkDistribution(msg.caller, token);
    switch (faucet_receipt) {
      case (#Err e) return #Err(e);
      case _ {};
    };

    // `Token` PrincipalでDIP20アクターのインスタンスを生成
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // トークンを転送する
    let txReceipt = await dip20.transfer(msg.caller, FAUCET_AMOUNT);
    switch txReceipt {
      case (#Err e) return #Err(#FaucetFailure);
      case _ {};
    };

    // 転送に成功したら、`faucet_book`に保存する
    addUser(msg.caller, token);
    return #Ok(FAUCET_AMOUNT);
  };

  public shared (msg) func clearBook() {
    assert (msg.caller != owner);
    faucet_book := HashMap.HashMap<Principal, [Token]>(
      10,
      Principal.equal,
      Principal.hash,
    );
  };

  // トークンを配布したユーザーとそのトークンを保存する
  private func addUser(user : Principal, token : Token) {
    // 配布するトークンをユーザーに紐づけて保存する
    switch (faucet_book.get(user)) {
      case null {
        let new_data = Array.make<Token>(token);
        faucet_book.put(user, new_data);
      };
      case (?tokens) {
        let buff = Buffer.Buffer<Token>(2);
        for (token in tokens.vals()) {
          buff.add(token);
        };
        // ユーザーの情報を上書きする
        faucet_book.put(user, Buffer.toArray<Token>(buff));
      };
    };
  };

  // Faucetとしてトークンを配布しているかどうかを確認する
  // 配布可能なら`#Ok`、不可能なら`#Err`を返す
  private func checkDistribution(user : Principal, token : Token) : async T.FaucetReceipt {
    // `Token` PrincipalでDIP20アクターのインスタンスを生成
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;
    let balance = await dip20.balanceOf(Principal.fromActor(this));

    if (balance == 0) {
      return (#Err(#InsufficientToken));
    };

    switch (faucet_book.get(user)) {
      case null return #Ok(FAUCET_AMOUNT);
      case (?tokens) {
        switch (Array.find<Token>(tokens, func(x : Token) { x == token })) {
          case null return #Ok(FAUCET_AMOUNT);
          case (?token) return #Err(#AlreadyGiven);
        };
      };
    };
  };

  // ===== UPGRADE =====
  system func preupgrade() {
    // `faucet_book`に保存されているデータのサイズでArrayの初期化をする
    // Principal.fromText()は空文字を入れるとエラーになるので、ここでは管理者のPrincipalを指す"aaaaa-aa"を指定
    faucetBookEntries := Array.init(faucet_book.size(), (Principal.fromText("aaaaa-aa"), []));
    var i = 0;
    for ((x, y) in faucet_book.entries()) {
      faucetBookEntries[i] := (x, y);
      i += 1;
    };
  };

  system func postupgrade() {
    // Arrayに保存したデータを`HashMap`に再構築する
    for ((key : Principal, value : [Token]) in faucetBookEntries.vals()) {
      faucet_book.put(key, value);
    };
    // `Stable`に使用したメモリをクリアする
    faucetBookEntries := [var];
  };
};
