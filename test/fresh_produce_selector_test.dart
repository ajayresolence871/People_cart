import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/features/home/services/fresh_produce_selector.dart';
import 'package:people_cart/models/category.dart';
import 'package:people_cart/models/product.dart';

void main() {
  test(
    'fresh zone only selects products from fruit and vegetable categories',
    () {
      final categories = [
        Category(id: 'produce', name: 'Fruits & Vegetables'),
        Category(id: 'dairy', name: 'Dairy, Bread & Eggs'),
      ];
      final products = [
        Product(id: 'banana', name: 'Banana', price: 45, categoryId: 'produce'),
        Product(id: 'tomato', name: 'Tomato', price: 50, categoryId: 'produce'),
        Product(id: 'milk', name: 'Milk', price: 35, categoryId: 'dairy'),
      ];

      final fresh = selectFreshProduce(
        categories: categories,
        products: products,
      );

      expect(fresh.map((product) => product.id), ['tomato', 'banana']);
    },
  );

  test('fresh zone supports selected produce categories and search', () {
    final categories = [
      Category(id: 'fruits', name: 'Fruits'),
      Category(id: 'vegetables', name: 'Vegetables'),
    ];
    final products = [
      Product(id: 'apple', name: 'Red Apple', price: 30, categoryId: 'fruits'),
      Product(
        id: 'tomato',
        name: 'Tomato',
        price: 40,
        categoryId: 'vegetables',
      ),
    ];

    final result = selectFreshProduce(
      categories: categories,
      products: products,
      categoryId: 'fruits',
      query: 'apple',
    );

    expect(result.map((product) => product.id), ['apple']);
  });
}
