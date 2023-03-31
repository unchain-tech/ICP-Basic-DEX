import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";

import BalanceBook "balance_book";
import T "types";

module {

  public class Exchange(balance_book : BalanceBook.BalanceBook) {

    // 売り注文のIDと注文内容をマッピング
    // 第一引数 : initCapacity
    // 第二引数 : keyEq（キーを比較する際に使用する関数を指定）
    // 第三引数 : keyHash（キーに使用する値を指定）
    var orders = HashMap.HashMap<T.OrderId, T.Order>(
      0,
      func(order_id_x, order_id_y) { return (order_id_x == order_id_y) },
      func(order_id_x) { return (order_id_x) },
    );

    // 保存されているオーダー一覧を配列で返す
    // `Buffer` : 拡張可能な汎用・可変シーケンス。
    // 固定長・不変のArrayよりも効率が良いためBufferを使用。
    public func getOrders() : [T.Order] {
      let buff = Buffer.Buffer<T.Order>(0);

      // `orders`の値をエントリー毎に取得し、`buff`に追加
      for (order in orders.vals()) {
        buff.add(order);
      };
      // `Buffer`から`Array`に変換して返す
      return (Buffer.toArray<T.Order>(buff));
    };

    // 引数に渡されたIDのオーダーを返す
    public func getOrder(id : Nat32) : ?T.Order {
      return (orders.get(id));
    };

    // 引数に渡されたIDのオーダーを削除する
    public func cancelOrder(id : T.OrderId) : ?T.Order {
      return (orders.remove(id));
    };

    // オーダーを追加する
    // 追加する際、取引が成立するオーダーがあるかを検索して見つかったら取引を実行する
    public func addOrder(new_order : T.Order) {
      orders.put(new_order.id, new_order);
      detectMatch(new_order);
    };

    func detectMatch(new_order : T.Order) {
      // 全ての売り注文から、from<->toが一致するものを探す
      for (order in orders.vals()) {
        if (
          order.id != new_order.id and order.from == new_order.to and order.to == new_order.from and order.fromAmount == new_order.toAmount and order.toAmount == new_order.fromAmount
        ) {
          processTrade(order, new_order);
        };
      };
    };

    func processTrade(order_x : T.Order, order_y : T.Order) {
      // 取引の内容で`order_x`の作成者のトークン残高を更新
      let _removed_x = balance_book.removeToken(order_x.owner, order_x.from, order_x.fromAmount);
      balance_book.addToken(order_x.owner, order_x.to, order_x.toAmount);
      // 取引の内容で`order_y`のトークン残高を更新
      let _removed_y = balance_book.removeToken(order_y.owner, order_y.from, order_y.fromAmount);
      balance_book.addToken(order_y.owner, order_y.to, order_y.toAmount);

      // 取引が成立した注文を削除
      let _removed_order_x = orders.remove(order_x.id);
      let _removed_order_y = orders.remove(order_y.id);

      Debug.print("Success Trade !");
    };
  };

};
