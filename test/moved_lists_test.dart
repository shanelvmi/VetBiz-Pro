import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/batch_move_reasons.dart';
import 'package:vetbiz_pro/constants/client_options.dart';
import 'package:vetbiz_pro/constants/crops.dart';
import 'package:vetbiz_pro/constants/transaction_categories.dart';
import 'package:vetbiz_pro/data/payment_status.dart';

/// Lists that were local to a screen and moved to lib/constants or lib/data
/// in step 2F-3. Their values are saved in Firestore, so each test pins the
/// exact values and order, copied from the code they were moved out of.
void main() {
  test('client types (add_client_screen clientTypes, clients_screen _clientTypes)', () {
    expect(kClientTypes, ['Farmer', 'Vet', 'Wholesaler', 'Retailer']);
    expect(kClientTypeOther, 'Other');
  });

  test('farmer sub-types (add_client_screen farmerSubTypes)', () {
    expect(kFarmerSubTypes, ['Crop Producer', 'Animal Keeper']);
  });

  test('animal species and their groups (add_client_screen animalGroups)', () {
    expect(kAnimalGroups.keys.toList(), ['Livestock', 'Poultry', 'Other']);
    expect(kAnimalGroups['Livestock'], ['Cattle', 'Goat', 'Sheep', 'Pig', 'Donkey']);
    expect(kAnimalGroups['Poultry'], ['Chicken', 'Duck', 'Turkey', 'Guinea Fowl']);
    expect(kAnimalGroups['Other'], ['Bees', 'Dog', 'Cat', 'Rabbit']);
  });

  test('crops and their groups (add_client_screen cropGroups)', () {
    expect(kCropGroups.keys.toList(), ['Food Crops', 'Cash Crops', 'Vegetables', 'Fruits']);
    expect(kCropGroups['Food Crops'], [
      'Maize', 'Rice', 'Wheat', 'Cassava', 'Sorghum', 'Millet', 'Beans',
      'Bananas', 'Sweet Potatoes', 'Irish Potatoes', 'Groundnuts',
    ]);
    expect(kCropGroups['Cash Crops'], [
      'Coffee', 'Cotton', 'Tobacco', 'Cashew Nuts', 'Sisal', 'Tea',
      'Pyrethrum', 'Sugarcane', 'Cloves', 'Sesame', 'Sunflower',
    ]);
    expect(kCropGroups['Vegetables'], ['Tomatoes', 'Onions', 'Cabbage', 'Okra']);
    expect(kCropGroups['Fruits'], ['Mangoes', 'Oranges', 'Avocado', 'Watermelon']);
  });

  test('vet practice types (add_client_screen vetPracticeTypes)', () {
    expect(kVetPracticeTypes, ['Clinic', 'Consultant', 'Hospital', 'Ambulatory']);
  });

  test("client statuses (add_client_screen chips, clients_screen filter)", () {
    expect(kClientStatuses, ['Active', 'Inactive']);
  });

  test('payment statuses (Sale/Service toMap, Sales/Services filters)', () {
    expect(PaymentStatus.values, ['Paid', 'Partial', 'Unpaid']);
    // The old rule: totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Unpaid').
    expect(PaymentStatus.of(100, 100), 'Paid');
    expect(PaymentStatus.of(120, 100), 'Paid');
    expect(PaymentStatus.of(0, 0), 'Paid');
    expect(PaymentStatus.of(40, 100), 'Partial');
    expect(PaymentStatus.of(0, 100), 'Unpaid');
  });

  test('transaction categories (add_transaction_screen kExpenseCategoryGroups, kIncomeCategories)', () {
    expect(kExpenseCategoryGroups.keys.toList(),
        ['Administration', 'Premises & Utilities', 'Operations', 'Transport', 'Business', 'Other']);
    expect(kExpenseCategoryGroups['Administration'], ['Meals & Refreshments', 'Salaries & Wages', 'Office Supplies']);
    expect(kExpenseCategoryGroups['Premises & Utilities'], ['Electricity', 'Water', 'Rent']);
    expect(kExpenseCategoryGroups['Operations'], ['Drugs & Medicines', 'Vaccines', 'Veterinary Supplies']);
    expect(kExpenseCategoryGroups['Transport'], ['Fuel', 'Vehicle Maintenance']);
    expect(kExpenseCategoryGroups['Business'], ['Marketing', 'Licences & Registration']);
    expect(kExpenseCategoryGroups['Other'], ['Miscellaneous']);
    expect(kIncomeCategories, [
      'Commission Income',
      'Delivery Income',
      'Training Income',
      'Consultancy Income',
      'Rental Income',
      'Interest Income',
      'Refunds Received',
      'Discounts Received',
      'Asset Disposal Income',
      'Other Income',
    ]);
  });

  test('batch move reasons (move_expired_to_stock_dialog _moveReasons)', () {
    expect(kBatchMoveReasons, ['Expired', 'Deteriorated', 'Other (specify)']);
    expect(kBatchMoveReasonExpired, 'Expired');
    expect(kBatchMoveReasonOther, 'Other (specify)');
  });
}
