import 'package:flutter/material.dart';

class IconCatalog {
  static const IconData defaultCategoryIcon = Icons.category_rounded;
  static const IconData defaultWalletIcon = Icons.account_balance_wallet_rounded;

  static const List<IconData> selectableCategoryIcons = [
    Icons.shopping_bag_rounded,
    Icons.attach_money_rounded,
    Icons.school_rounded,
    Icons.flight_takeoff_rounded,
    Icons.storefront_rounded,
    Icons.card_giftcard_rounded,
  ];

  static IconData resolveCategoryIcon(int codePoint) {
    return _materialIcons[codePoint] ?? defaultCategoryIcon;
  }

  static IconData resolveWalletIcon(int codePoint) {
    return _materialIcons[codePoint] ?? defaultWalletIcon;
  }

  static final Map<int, IconData> _materialIcons = {
    Icons.account_balance_rounded.codePoint: Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded.codePoint:
        Icons.account_balance_wallet_rounded,
    Icons.attach_money_rounded.codePoint: Icons.attach_money_rounded,
    Icons.business_center_rounded.codePoint: Icons.business_center_rounded,
    Icons.card_giftcard_rounded.codePoint: Icons.card_giftcard_rounded,
    Icons.directions_car_filled_rounded.codePoint:
        Icons.directions_car_filled_rounded,
    Icons.flight_takeoff_rounded.codePoint: Icons.flight_takeoff_rounded,
    Icons.health_and_safety_rounded.codePoint:
        Icons.health_and_safety_rounded,
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.lightbulb_circle_rounded.codePoint:
        Icons.lightbulb_circle_rounded,
    Icons.payments_rounded.codePoint: Icons.payments_rounded,
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.savings_rounded.codePoint: Icons.savings_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
    Icons.storefront_rounded.codePoint: Icons.storefront_rounded,
    Icons.swap_horiz_rounded.codePoint: Icons.swap_horiz_rounded,
    Icons.work_history_rounded.codePoint: Icons.work_history_rounded,
  };
}
