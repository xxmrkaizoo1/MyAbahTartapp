import 'package:flutter_test/flutter_test.dart';
import 'package:myabahtartlejen/models/enums.dart';
import 'package:myabahtartlejen/models/product.dart';
import 'package:myabahtartlejen/models/shop_models.dart';
import 'package:myabahtartlejen/services/cart.dart';

void main() {
  const pineapple = Product(id: 'golden-pineapple-tart', name: 'Golden Pineapple Tart', categoryId: 'classics', price: 48, stock: 3);
  const eggTart = Product(
    id: 'egg-tart',
    name: 'Egg Tart',
    categoryId: 'classics',
    price: 10,
    sizePrices: {'S': 10, 'L': 25},
    sizeStock: {'S': 0, 'L': 4},
    stock: 4,
  );

  test('cart never holds more than is in stock', () {
    final cart = Cart();
    expect(cart.add(pineapple, null, 2), 2);
    expect(cart.add(pineapple, null, 5), 1);
    expect(cart.count, 3);
    expect(cart.subtotal, 144);
  });

  test('sized products default to the first size in stock and price by size', () {
    expect(eggTart.sizes, [ProductSize.small, ProductSize.large]);
    expect(eggTart.defaultSize, ProductSize.large);
    expect(eggTart.priceFor(ProductSize.large), 25);
    expect(eggTart.fromPrice, 10);
    expect(eggTart.toMap()['stock'], 4);
  });

  test('vouchers respect the minimum spend and never exceed the subtotal', () {
    const welcome = Voucher(code: 'WELCOME10', value: 10, minSubtotal: 60);
    const sweet = Voucher(code: 'SWEET15', type: Voucher.typePercent, value: 15, minSubtotal: 100);

    expect(welcome.discountFor(59), 0);
    expect(welcome.discountFor(60), 10);
    expect(sweet.discountFor(144), 21.6);
    expect(const Voucher(code: 'BIG', value: 500).discountFor(48), 48);
  });

  test('standard delivery becomes free over the threshold', () {
    const storefront = Storefront.fallback;
    expect(storefront.feeFor(DeliveryMethod.standard, 99), 5);
    expect(storefront.feeFor(DeliveryMethod.standard, 100), 0);
    expect(storefront.feeFor(DeliveryMethod.express, 500), 150);

    final cart = Cart()
      ..add(pineapple, null, 2)
      ..applyVoucher(const Voucher(code: 'WELCOME10', value: 10, minSubtotal: 60));
    final summary = cart.summary(storefront, DeliveryMethod.standard);
    expect(summary.subtotal, 96);
    expect(summary.deliveryFee, 5);
    expect(summary.discount, 10);
    expect(summary.total, 91);
  });
}
