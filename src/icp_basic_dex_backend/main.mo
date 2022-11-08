import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

import BalanceBook "balance_book";
import Exchange "exchange";
import T "types";

actor class Dex() = this {
  // Stable variable to save sell orders at time of upgrade
  stable var orders_stable : [T.Order] = [];
  //
  private stable var book_stable : [var (Principal, [(T.Token, Nat)])] = [var];

  // 売り注文のIDを管理する変数
  stable var last_id : Nat32 = 0;

  // ユーザーの残高を管理するモジュール
  private var balance_book = BalanceBook.BalanceBook();

  // 売り注文を管理するモジュール
  private var exchange = Exchange.Exchange(balance_book);

  // ===== DEPOSIT / WITHDRAW =====
  public shared (msg) func deposit(token : T.Token) : async T.DepositReceipt {
    Debug.print(
      "Message caller: " # Principal.toText(msg.caller) # "| Deposit Token: " # Principal.toText(token),
    );

    // tokenをDIP20のアクターにキャスト
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // DIPのfeeを取得
    let dip_fee = await fetch_dif_fee(token);

    // DIP20のallowanceで残高を取得
    // `Principal.fromActor(this)`: DEXキャニスター（main.mo）自身
    let balance = await dip20.allowance(msg.caller, Principal.fromActor(this));

    // DEXへユーザーの資金を送る
    if (balance <= dip_fee) {
      return #Err(#BalanceLow);
    };
    let token_reciept = await dip20.transferFrom(msg.caller, Principal.fromActor(this), balance - dip_fee);

    // `transferFrom()`の結果をチェック
    switch token_reciept {
      case (#Err e) {
        return #Err(#TransferFailure);
      };
      case _ {};
    };

    // `balance_book`にユーザーとトークンを追加
    balance_book.addToken(msg.caller, token, balance - dip_fee);

    return #Ok(balance - dip_fee);
  };

  public shared (msg) func withdraw(token : T.Token, amount : Nat /*, address : Principal*/) : async T.WithdrawReceipt {
    // キャニスターIDをDIP20Interfaceにキャスト
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;

    // ユーザーへトークンを送る
    // let txReceipt = await dip20.transfer(address, amount);
    let txReceipt = await dip20.transfer(msg.caller, amount);

    switch txReceipt {
      case (#Err e) {
        return #Err(#TransferFailure);
      };
      case _ {};
    };

    // DIPのfeeを取得
    let dip_fee = await fetch_dif_fee(token);
    // `balance_book`から引き出した分のトークンデータを削除
    switch (balance_book.removeToken(msg.caller, token, amount + dip_fee)) {
      case (null) {
        return #Err(#BalanceLow);
      };
      case _ {};
    };

    // ユーザーが登録したオーダーを削除
    for (order in exchange.getOrders().vals()) {
      if (msg.caller == order.owner and token == order.from) {
        // `DEX`内のユーザー預け入れ残高とオーダーのfromAmountと比較

        if (balance_book.hasEnoughBalance(msg.caller, token, order.fromAmount) == false) {
          switch (exchange.cancelOrder(order.id)) {
            // キャンセル成功
            case (?cancel_order) {
              return (#Ok(amount));
            };
            // キャンセル失敗（removenに失敗）
            case (null) {
              return (#Err(#DeleteOrderFailure));
            };
          };
        };
        return #Ok(amount);
      };
    };

    return #Ok(amount);
  };

  // ===== ORDER =====
  // 売り注文を登録する
  public shared (msg) func placeOrder(
    from : T.Token,
    fromAmount : Nat,
    to : T.Token,
    toAmount : Nat,
  ) : async T.PlaceOrderReceipt {

    // ユーザーが`from`トークンで別の売り注文を出していないか確認
    for (order in exchange.getOrders().vals()) {
      if (msg.caller == order.owner and from == order.from) {
        return (#Err(#OrderBookFull));
      };
    };

    // ユーザーの残高が足りるかチェック
    if (balance_book.hasEnoughBalance(msg.caller, from, fromAmount) == false) {
      Debug.print("Not enough balance for user " # Principal.toText(msg.caller) # " in token " # Principal.toText(from));
      return (#Err(#InvalidOrder));
    };

    let id : Nat32 = nextId();
    let owner = msg.caller;

    // `Order`データ構造を作成
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

  // 売り注文をキャンセルする
  public shared (msg) func cancelOrder(order_id : T.OrderId) : async T.CancelOrderReceipt {
    switch (exchange.getOrder(order_id)) {
      // 注文IDが存在する
      case (?order) {
        // キャンセルしようとしているユーザーと、売り注文のオーナーが一致するかチェック
        if (msg.caller != order.owner) {
          return (#Err(#NotAllowed));
        };
        // 売り注文のキャンセルを実行
        switch (exchange.cancelOrder(order_id)) {
          // キャンセル成功
          case (?cancel_order) {
            return (#Ok(cancel_order.id));
          };
          // キャンセル失敗（removenに失敗）
          case (null) {
            return (#Err(#NotExistingOrder));
          };
        };
      };
      // 注文IDが存在しない
      case (null) {
        return (#Err(#NotExistingOrder));
      };
    };
  };

  public query func getOrders() : async ([T.Order]) {
    return (exchange.getOrders());
  };

  // Internal functions
  private func fetch_dif_fee(token : T.Token) : async Nat {
    let dip20 = actor (Principal.toText(token)) : T.DIPInterface;
    let metadata = await dip20.getMetadata();
    metadata.fee;
  };

  private func nextId() : Nat32 {
    last_id += 1;
    return (last_id);
  };

  // ===== DEX STATE FUNCTIONS =====
  // ユーザーがDEXに預けたトークンの残高を取得する
  public shared query (msg) func getBalances() : async [T.Balance] {
    switch (balance_book.get(msg.caller)) {
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
      case (null) {
        return [];
      };
    };
  };

  public shared query (msg) func getBalance(token : T.Token) : async Nat {
    switch (balance_book.get(msg.caller)) {
      case (?token_balances) {
        switch (token_balances.get(token)) {
          case (?amount) {
            return (amount);
          };
          case (null) {
            return (0);
          };
        };
      };
      case (null) {
        return 0;
      };
    };
  };

  // ===== UPGRADE METHODS =====
  // キャニスターのアップグレード前に、ハッシュマップを安定したメモリに保存し、更新に耐えられるようにする。
  system func preupgrade() {
    book_stable := Array.init(balance_book.size(), (Principal.fromText("aaaaa-aa"), []));
    var i = 0;
    for ((x, y) in balance_book.entries()) {
      book_stable[i] := (x, Iter.toArray(y.entries()));
      i += 1;
    };

    // book内で管理しているオーダーブックをstableに保存
    orders_stable := exchange.getOrders();
  };

  // キャニスターのアップグレード後、ブック・マップは安定した配列から再構築されます。
  system func postupgrade() {
    // Reload balance_book.
    for ((key : Principal, value : [(T.Token, Nat)]) in book_stable.vals()) {
      let tmp : HashMap.HashMap<T.Token, Nat> = HashMap.fromIter<T.Token, Nat>(Iter.fromArray<(T.Token, Nat)>(value), 10, Principal.equal, Principal.hash);
      balance_book.put(key, tmp);
    };

    // Reload order
    for (order in orders_stable.vals()) {
      exchange.addOrder(order);
    };

    // Clean stable memory.
    book_stable := [var];
    orders_stable := [];
  };
};
