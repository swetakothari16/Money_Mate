import 'package:flutter/material.dart';

/// Helper class to map icon name strings or category name strings to Flutter [IconData].
class IconMapper {
  IconMapper._();

  /// Gets the [IconData] corresponding to the given [iconName] or fallback [categoryName].
  static IconData getIcon(String? iconName, {String? categoryName}) {
    final name = (iconName ?? categoryName ?? '').toLowerCase().trim();
    switch (name) {
      case 'restaurant':
      case 'food':
      case 'food & dining':
      case 'food & drinks':
        return Icons.restaurant_rounded;
      case 'directions_car':
      case 'transport':
      case 'transportation':
        return Icons.directions_car_rounded;
      case 'shopping_bag':
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'movie':
      case 'entertainment':
        return Icons.movie_rounded;
      case 'local_hospital':
      case 'health':
      case 'health & medical':
      case 'medical':
        return Icons.local_hospital_rounded;
      case 'school':
      case 'education':
        return Icons.school_rounded;
      case 'receipt_long':
      case 'bills':
      case 'bills & utilities':
        return Icons.receipt_long_rounded;
      case 'home':
      case 'rent':
      case 'rent & housing':
      case 'housing':
        return Icons.home_rounded;
      case 'local_grocery_store':
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'flight':
      case 'travel':
        return Icons.flight_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      case 'shield':
      case 'insurance':
        return Icons.shield_rounded;
      case 'spa':
      case 'personal care':
        return Icons.spa_rounded;
      case 'card_giftcard':
      case 'gifts':
      case 'gifts & donations':
        return Icons.card_giftcard_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'account_balance_wallet':
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      case 'work':
      case 'freelance':
        return Icons.work_rounded;
      case 'trending_up':
      case 'investment':
      case 'investments':
        return Icons.trending_up_rounded;
      case 'business_center':
      case 'business':
        return Icons.business_center_rounded;
      case 'apartment':
      case 'rental':
      case 'rental income':
        return Icons.apartment_rounded;
      case 'replay':
      case 'refund':
        return Icons.replay_rounded;
      case 'swap_horiz':
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'more_horiz':
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
