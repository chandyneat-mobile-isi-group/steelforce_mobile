// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_dao.dart';

// ignore_for_file: type=lint
mixin _$CartDaoMixin on DatabaseAccessor<AppDatabase> {
  $CartItemsTable get cartItems => attachedDatabase.cartItems;
  CartDaoManager get managers => CartDaoManager(this);
}

class CartDaoManager {
  final _$CartDaoMixin _db;
  CartDaoManager(this._db);
  $$CartItemsTableTableManager get cartItems =>
      $$CartItemsTableTableManager(_db.attachedDatabase, _db.cartItems);
}
