import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/batch_move_reasons.dart';
import 'package:vetbiz_pro/constants/client_options.dart';
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

  test('batch move reasons (move_expired_to_stock_dialog _moveReasons)', () {
    expect(kBatchMoveReasons, ['Expired', 'Deteriorated', 'Other (specify)']);
    expect(kBatchMoveReasonExpired, 'Expired');
    expect(kBatchMoveReasonOther, 'Other (specify)');
  });
}
