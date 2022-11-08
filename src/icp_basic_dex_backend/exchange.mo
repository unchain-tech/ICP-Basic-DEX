import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";

import BalanceBook "balance_book";
import T "types";

module {
    // Internal types
    type TradingPair = (T.Token, T.Token);

    public class Exchange(balance_book : BalanceBook.BalanceBook) {

        // 売り注文のIDと注文内容をマッピング
        // 0 : initCapacity
        // func(order_id_x, order_id_y) : keyEq
        // func(order_id_x) : keyHash
        var orders = HashMap.HashMap<T.OrderId, T.Order>(
            0,
            func(order_id_x, order_id_y) { return (order_id_x == order_id_y) },
            func(order_id_x) { return (order_id_x) },
        );

        // Buffer : 拡張可能な汎用・可変シーケンス。固定長・不変のArrayよりも効率が良いため今回はBufferを使用。
        public func getOrders() : [T.Order] {
            let buff = Buffer.Buffer<T.Order>(0);

            // `orders`の値をエントリー毎に取得し、`buff`に追加
            for (order in orders.vals()) {
                buff.add(order);
            };
            buff.toArray();
        };

        public func getOrder(id : Nat32) : ?T.Order {
            return (orders.get(id));
        };

        public func cancelOrder(id : T.OrderId) : ?T.Order {
            return (orders.remove(id));
        };

        public func addOrder(new_order : T.Order) {
            orders.put(new_order.id, new_order);
            detectMatch(new_order);
        };

        func detectMatch(new_order : T.Order) {
            // 全ての売り注文から、from<->toが一致するものを探す
            for (order in orders.vals()) {
                if (
                    order.id != new_order.id and order.from == new_order.to and order.to == new_order.from and order.fromAmount == new_order.toAmount and order.toAmount == new_order.fromAmount,
                ) {
                    processTrade(order, new_order);
                };
            };
        };

        func processTrade(order_x : T.Order, order_y : T.Order) {
            // 取引内容でXのトークン残高を更新
            let _removed_x = balance_book.removeToken(order_x.owner, order_x.from, order_x.fromAmount);
            balance_book.addToken(order_x.owner, order_x.to, order_x.toAmount);
            // 取引内容でYのトークン残高を更新
            let _removed_y = balance_book.removeToken(order_y.owner, order_y.from, order_y.fromAmount);
            balance_book.addToken(order_y.owner, order_y.to, order_y.toAmount);

            // 取引が成立した注文を削除
            let _removed_order_x = orders.remove(order_x.id);
            let _removed_order_y = orders.remove(order_y.id);

            Debug.print("Success Trade !");
        };
    };

};
