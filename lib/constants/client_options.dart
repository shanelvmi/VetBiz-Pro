// The options of the client form and the Clients screen. Each is saved on the
// client record as this English text, so the values and their order never
// change; what is shown is their label (lib/l10n/client_labels.dart).
// Moved here from add_client_screen.dart and clients_screen.dart unchanged.

/// `types` on a client (more than one can apply).
const List<String> kClientTypes = ['Farmer', 'Vet', 'Wholesaler', 'Retailer'];

/// What the Clients screen shows for a client saved with no type. Not offered
/// in the form.
const String kClientTypeOther = 'Other';

/// `farmerSubType` on a farmer client.
const List<String> kFarmerSubTypes = ['Crop Producer', 'Animal Keeper'];

/// `animalSpecies` on an animal keeper, grouped for the picker. Only the
/// species are saved; the group names are headings.
const Map<String, List<String>> kAnimalGroups = {
  'Livestock': ['Cattle', 'Goat', 'Sheep', 'Pig', 'Donkey'],
  'Poultry': ['Chicken', 'Duck', 'Turkey', 'Guinea Fowl'],
  'Other': ['Bees', 'Dog', 'Cat', 'Rabbit'],
};

/// `vetPracticeType` on a vet client.
const List<String> kVetPracticeTypes = ['Clinic', 'Consultant', 'Hospital', 'Ambulatory'];

/// `status` on a client; the Clients status filter queries it.
const List<String> kClientStatuses = ['Active', 'Inactive'];
