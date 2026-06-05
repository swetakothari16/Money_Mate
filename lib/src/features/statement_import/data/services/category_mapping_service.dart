import '../../../../core/enums/expense_category.dart';

abstract class CategoryMappingService {
  String mapMerchantToCategory(String merchant);
}

class RuleBasedCategoryMappingService implements CategoryMappingService {
  const RuleBasedCategoryMappingService();

  @override
  String mapMerchantToCategory(String merchant) {
    final lowerMerchant = merchant.toLowerCase();

    // 1. Food & Dining
    if (_containsAny(lowerMerchant, [
      'swiggy',
      'zomato',
      'starbucks',
      'mcdonald',
      'domino',
      'kfc',
      'burger',
      'cafe',
      'dining',
      'restaurant',
      'pizza',
      'subway',
      'bakery',
      'diner',
      'eats',
    ])) {
      return ExpenseCategory.food.name;
    }

    // 2. Groceries
    if (_containsAny(lowerMerchant, [
      'grocery',
      'groceries',
      'bigbasket',
      'blinkit',
      'zepto',
      'dmart',
      'supermarket',
      'reliance fresh',
      'spencer',
      'nature\'s basket',
      'instamart',
      'mart',
      'market',
    ])) {
      return ExpenseCategory.groceries.name;
    }

    // 3. Transport
    if (_containsAny(lowerMerchant, [
      'uber',
      'ola',
      'metro',
      'taxi',
      'cab',
      'fuel',
      'petrol',
      'shell',
      'hpcl',
      'bpcl',
      'indianoil',
      'auto',
      'commute',
      'parking',
      'toll',
    ])) {
      return ExpenseCategory.transport.name;
    }

    // 4. Shopping
    if (_containsAny(lowerMerchant, [
      'amazon',
      'flipkart',
      'myntra',
      'zara',
      'h&m',
      'hnm',
      'shopping',
      'retail',
      'fashion',
      'nike',
      'adidas',
      'decathlon',
      'apparel',
      'clothing',
      'mall',
    ])) {
      return ExpenseCategory.shopping.name;
    }

    // 5. Subscriptions
    if (_containsAny(lowerMerchant, [
      'netflix',
      'spotify',
      'youtube',
      'disney',
      'prime video',
      'hulu',
      'hotstar',
      'hbo',
      'subscriptions',
      'sub',
      'patreon',
    ])) {
      return ExpenseCategory.subscriptions.name;
    }

    // 6. Bills & Utilities
    if (_containsAny(lowerMerchant, [
      'electricity',
      'water',
      'gas',
      'power',
      'airtel',
      'jio',
      'vodafone',
      'idea',
      'bsnl',
      'broadband',
      'bill',
      'utility',
      'utilities',
      'recharge',
      'wifi',
    ])) {
      return ExpenseCategory.bills.name;
    }

    // 7. Travel
    if (_containsAny(lowerMerchant, [
      'indigo',
      'flight',
      'makemytrip',
      'travel',
      'hotel',
      'airbnb',
      'irctc',
      'railway',
      'booking',
      'expedia',
      'agoda',
      'trip',
      'airlines',
      'resort',
      'vacation',
    ])) {
      return ExpenseCategory.travel.name;
    }

    // 8. Entertainment
    if (_containsAny(lowerMerchant, [
      'cinema',
      'movie',
      'theatre',
      'bookmyshow',
      'pvr',
      'inox',
      'gaming',
      'ticket',
      'show',
      'fun',
      'park',
      'concert',
      'steam',
      'playstation',
      'xbox',
    ])) {
      return ExpenseCategory.entertainment.name;
    }

    // 9. Health & Medical
    if (_containsAny(lowerMerchant, [
      'hospital',
      'pharmacy',
      'medical',
      'doctor',
      'clinic',
      'chemist',
      'apollo',
      'medicine',
      'care',
      'diagnostic',
      'dental',
      'health',
    ])) {
      return ExpenseCategory.health.name;
    }

    // 10. Education
    if (_containsAny(lowerMerchant, [
      'udemy',
      'coursera',
      'school',
      'college',
      'education',
      'fees',
      'book',
      'books',
      'tuition',
      'learning',
      'course',
    ])) {
      return ExpenseCategory.education.name;
    }

    // 11. Rent & Housing
    if (_containsAny(lowerMerchant, [
      'rent',
      'landlord',
      'society',
      'maintenance',
      'realty',
      'estate',
      'housing',
    ])) {
      return ExpenseCategory.rent.name;
    }

    // 12. Personal Care
    if (_containsAny(lowerMerchant, [
      'salon',
      'spa',
      'parlour',
      'personal care',
      'hair',
      'makeup',
      'grooming',
    ])) {
      return ExpenseCategory.personalCare.name;
    }

    // 13. Gifts & Donations
    if (_containsAny(lowerMerchant, [
      'gift',
      'donation',
      'gifts',
      'ngo',
      'charity',
      'donate',
    ])) {
      return ExpenseCategory.gifts.name;
    }

    // 14. Pets
    if (_containsAny(lowerMerchant, [
      'pet',
      'pets',
      'dog',
      'cat',
      'veterinary',
      'vet',
      'kibble',
    ])) {
      return ExpenseCategory.pets.name;
    }

    // Default to 'other' if no match
    return ExpenseCategory.other.name;
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
