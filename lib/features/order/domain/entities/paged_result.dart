import 'package:equatable/equatable.dart';

class PagedResult<T> extends Equatable {
  const PagedResult(
      {required this.items, required this.page, required this.hasMore});

  final List<T> items;
  final int page;
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, hasMore];
}
