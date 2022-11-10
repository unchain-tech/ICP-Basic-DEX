import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

import BalanceBook "balance_book";
import Exchange "exchange";
import T "types";

actor class Dex() = this {

  // アップグレード時にオーダーを保存しておく`Stable`変数
  private stable var ordersEntries : [T.Order] = [];

  // DEXに預けたユーザーのトークン残高を保存する`Stable`変数
  private stable var balanceBookEntries : [var (Principal, [(T.Token, Nat)])] = [var];

  // オーダーのIDを管理する`Stable`変数
  private stable var last_id : Nat32 = 0;

  // DEXのユーザートークンを管理するモジュール
  private var balance_book = BalanceBook.BalanceBook();

  // オーダーを管理するモジュール
  private var exchange = Exchange.Exchange(balance_book);

  // ===== DEPOSIT / WITHDRAW =====
  // ユーザーがDEXにトークンを預ける時にコールする
  // 成功すると預けた量を、失敗するとエラー文を返す
  public shared (msg) func deposit(token : T.Token) : async T.DepositReceipt {
    Debug.print(
      "Message caller: " # Principal.toText(msg.caller) # "| Deposit Token: " # Principal.toText(token),
    );

    // `Token` PrincipalでDIP20アクターのインスタンスを生成
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // トークンに設定された`fee`を取得
    let dip_fee = await fetch_dif_fee(token);

    // ユーザーが保有するトークン量を取得
    // `Principal.fromActor(this)`: DEX canister (main.mo) itself
    let balance = await dip20.allowance(msg.caller, Principal.fromActor(this));

    // 残高不足の場合エラーとなる
    if (balance <= dip_fee) {
      return #Err(#BalanceLow);
    };
    // DEXに転送
    let token_reciept = await dip20.transferFrom(msg.caller, Principal.fromActor(this), balance - dip_fee);

    // `transferFrom()`の結果を確認
    switch token_reciept {
      case (#Err e) return #Err(#TransferFailure);
      case _ {};
    };

    // `balance_book`にユーザーPrincipalとトークンデータを記録
    balance_book.addToken(msg.caller, token, balance - dip_fee);

    return #Ok(balance - dip_fee);
  };

  // DEXからトークンを引き出す時にコールされる
  // 成功すると引き出したトークン量が、失敗するとエラー文を返す
  public shared (msg) func withdraw(token : T.Token, amount : Nat) : async T.WithdrawReceipt {
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // `transfer`でユーザーにトークンを転送する
    let txReceipt = await dip20.transfer(msg.caller, amount);

    switch txReceipt {
      case (#Err e) return #Err(#TransferFailure);
      case _ {};
    };

    let dip_fee = await fetch_dif_fee(token);

    // `balance_book`のトークンデータを修正する
    switch (balance_book.removeToken(msg.caller, token, amount + dip_fee)) {
      case null return #Err(#BalanceLow);
      case _ {};
    };

    // ユーザーが作成したオーダーを削除する
    for (order in exchange.getOrders().vals()) {
      if (msg.caller == order.owner and token == order.from) {
        // ユーザの預金残高とオーダーの`fromAmount`を比較する
        if (balance_book.hasEnoughBalance(msg.caller, token, order.fromAmount) == false) {
          // `cancelOrder()`を実行する
          switch (exchange.cancelOrder(order.id)) {
            case null return (#Err(#DeleteOrderFailure));
            case (?cancel_order) return (#Ok(amount));
          };
        };
        return #Ok(amount);
      };
    };
    return #Ok(amount);
  };

  // ===== ORDER =====
  // ユーザーがオーダーを作成する時にコールされる
  // 成功するとオーダーの内容が、失敗するとエラー文を返す
  public shared (msg) func placeOrder(
    from : T.Token,
    fromAmount : Nat,
    to : T.Token,
    toAmount : Nat,
  ) : async T.PlaceOrderReceipt {

    // ユーザーが`from`トークンで別のオーダーを出していないことを確認
    for (order in exchange.getOrders().vals()) {
      if (msg.caller == order.owner and from == order.from) {
        return (#Err(#OrderBookFull));
      };
    };

    // ユーザーが十分なトークン量を持っているか確認
    if (balance_book.hasEnoughBalance(msg.caller, from, fromAmount) == false) {
      Debug.print("Not enough balance for user " # Principal.toText(msg.caller) # " in token " # Principal.toText(from));
      return (#Err(#InvalidOrder));
    };

    // オーダーのIDを取得する
    let id : Nat32 = nextId();
    // `placeOrder`を呼び出したユーザーPrincipalを変数に格納する
    // msg.callerのままだと、下記の構造体に設定できないため
    let owner = msg.caller;

    // オーダーを作成する
    let order : T.Order = {
      id;
      owner;
      from;
      fromAmount;
      to;
      toAmount;
    };
    exchange.addOrder(order);

    return (#Ok(exchange.getOrder(id)));
  };

  // ユーザーがオーダーを削除する時にコールされる
  // 成功したら削除したオーダーのIDを、失敗したらエラー文を返す
  public shared (msg) func cancelOrder(order_id : T.OrderId) : async T.CancelOrderReceipt {
    // オーダーがあるかどうか
    switch (exchange.getOrder(order_id)) {
      case null return (#Err(#NotExistingOrder));
      case (?order) {
        // キャンセルしようとしているユーザーが、売り注文を作成したユーザー（所有者）と一致するかどうかをチェックする
        if (msg.caller != order.owner) {
          return (#Err(#NotAllowed));
        };
        // `cancleOrder`を実行する
        switch (exchange.cancelOrder(order_id)) {
          case null return (#Err(#NotExistingOrder));
          case (?cancel_order) {
            return (#Ok(cancel_order.id));
          };
        };
      };
    };
  };

  // Get all sell orders
  public query func getOrders() : async ([T.Order]) {
    return (exchange.getOrders());
  };

  // ===== INTERNAL FUNCTIONS =====
  // トークンに設定された`fee`を取得する
  private func fetch_dif_fee(token : T.Token) : async Nat {
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;
    let metadata = await dip20.getMetadata();
    metadata.fee;
  };

  // オーダーのIDを更新して返す
  private func nextId() : Nat32 {
    last_id += 1;
    return (last_id);
  };

  // ===== DEX STATE FUNCTIONS =====
  // ユーザーがDEXに預けたトークンの残高を取得する時にコールされる
  // データがあれば配列でトークンデータを返し、なければ空の配列を返す
  public shared query (msg) func getBalances() : async [T.Balance] {
    // ユーザーのデータがあるかどうか
    switch (balance_book.get(msg.caller)) {
      case null return [];
      case (?token_balance) {
        // 配列の値の順番を保ったまま、関数で各値を変換する(`(Principal, Nat)` -> `Balace`)。
        Array.map<(Principal, Nat), T.Balance>(
          Iter.toArray(token_balance.entries()),
          func(key : Principal, value : Nat) : T.Balance {
            {
              owner = msg.caller;
              token = key;
              amount = value;
            };
          },
        );
      };
    };
  };

  // 引数で渡されたトークンPrincipalの残高を取得する
  public shared query (msg) func getBalance(token : T.Token) : async Nat {
    // ユーザーのデータがあるかどうか
    switch (balance_book.get(msg.caller)) {
      case null return 0;
      case (?token_balances) {
        // トークンのデータがあるかどうか
        switch (token_balances.get(token)) {
          case null return (0);
          case (?amount) {
            return (amount);
          };
        };
      };
    };
  };

  // ===== UPGRADE METHODS =====
  // アップグレード前に、ハッシュマップに保存したデータを安定したメモリに保存する。
  system func preupgrade() {
    // DEXに預けられたユーザーのトークンデータを`Array`に保存
    balanceBookEntries := Array.init(balance_book.size(), (Principal.fromText("aaaaa-aa"), []));
    var i = 0;
    for ((x, y) in balance_book.entries()) {
      balanceBookEntries[i] := (x, Iter.toArray(y.entries()));
      i += 1;
    };

    // book内で管理しているオーダーを保存
    ordersEntries := exchange.getOrders();
  };

  // キャニスターのアップグレード後、`Array`から`HashMap`に再構築する。
  system func postupgrade() {
    // `balance_book`を再構築
    for ((key : Principal, value : [(T.Token, Nat)]) in balanceBookEntries.vals()) {
      let tmp : HashMap.HashMap<T.Token, Nat> = HashMap.fromIter<T.Token, Nat>(Iter.fromArray<(T.Token, Nat)>(value), 10, Principal.equal, Principal.hash);
      balance_book.put(key, tmp);
    };

    // オーダーを再構築
    for (order in ordersEntries.vals()) {
      exchange.addOrder(order);
    };

    // `Stable`に使用したメモリをクリアする.
    balanceBookEntries := [var];
    ordersEntries := [];
  };
};
