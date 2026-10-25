// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get common_language => 'Lugha';

  @override
  String get common_save => 'Hifadhi';

  @override
  String get common_cancel => 'Ghairi';

  @override
  String get common_delete => 'Futa';

  @override
  String get common_edit => 'Hariri';

  @override
  String get common_remove => 'Ondoa';

  @override
  String get common_close => 'Funga';

  @override
  String get common_ok => 'Sawa';

  @override
  String get common_yes => 'Ndiyo';

  @override
  String get common_no => 'Hapana';

  @override
  String get common_confirm => 'Thibitisha';

  @override
  String get common_done => 'Tayari';

  @override
  String get common_apply => 'Tumia';

  @override
  String get common_reset => 'Weka upya';

  @override
  String get common_refresh => 'Onyesha upya';

  @override
  String get common_retry => 'Jaribu tena';

  @override
  String get common_tryAgain => 'Jaribu Tena';

  @override
  String get common_undo => 'Tendua';

  @override
  String get common_details => 'Maelezo';

  @override
  String get common_viewDetails => 'Angalia Maelezo';

  @override
  String get common_copy => 'Nakili';

  @override
  String get common_share => 'Shiriki';

  @override
  String get common_print => 'Chapisha';

  @override
  String get common_search => 'Tafuta';

  @override
  String get common_add => 'Ongeza';

  @override
  String get common_clear => 'Safisha';

  @override
  String get common_change => 'Badilisha';

  @override
  String get common_call => 'Piga simu';

  @override
  String get common_moreActions => 'Vitendo zaidi';

  @override
  String get common_loading => 'Inapakia…';

  @override
  String get common_optional => 'Si lazima';

  @override
  String get common_all => 'Zote';

  @override
  String get common_date => 'Tarehe';

  @override
  String get common_amount => 'Kiasi';

  @override
  String get common_total => 'Jumla';

  @override
  String get common_status => 'Hali';

  @override
  String get common_type => 'Aina';

  @override
  String get common_email => 'Barua pepe';

  @override
  String get common_password => 'Nenosiri';

  @override
  String get common_notes => 'Maelezo ya ziada';

  @override
  String get error_generic => 'Kuna tatizo limetokea. Jaribu tena.';

  @override
  String get error_noPermission => 'Huna ruhusa ya kufanya hivyo.';

  @override
  String get error_noConnection =>
      'Hakuna mtandao. Angalia intaneti yako kisha ujaribu tena.';

  @override
  String get error_tooSlow => 'Imechukua muda mrefu mno. Jaribu tena.';

  @override
  String get error_notFound => 'Kitu hicho hakipo tena.';

  @override
  String get error_alreadyExists => 'Hicho tayari kipo.';

  @override
  String get error_rateLimited =>
      'Maombi ni mengi mno. Subiri kidogo kisha ujaribu tena.';

  @override
  String get error_photoTooLarge =>
      'Picha hii ni kubwa mno. Chagua iliyo ndogo zaidi.';

  @override
  String get error_adminOnly =>
      'Ni admin tu anayeweza kuhariri au kufuta rekodi hii.';

  @override
  String get login_wrongCredentials => 'Barua pepe au nenosiri si sahihi.';

  @override
  String get login_accountDisabled =>
      'Akaunti hii imezimwa. Wasiliana na msimamizi wako.';

  @override
  String get login_tooManyAttempts =>
      'Umejaribu mara nyingi mno. Subiri kidogo kisha ujaribu tena.';

  @override
  String get login_signInFailed => 'Imeshindikana kuingia. Jaribu tena.';

  @override
  String get common_facility => 'Kituo';

  @override
  String get common_signOut => 'Toka';

  @override
  String get common_hideDetails => 'Ficha maelezo';

  @override
  String get dateRange_title => 'Chagua Kipindi cha Tarehe';

  @override
  String get dateRange_start => 'Tarehe ya Kuanza:';

  @override
  String get dateRange_end => 'Tarehe ya Mwisho:';

  @override
  String get error_couldNotLoad => 'Imeshindwa kupakia taarifa';

  @override
  String get error_indexNeeded =>
      'Ukurasa huu unahitaji faharasa ya hifadhidata itengenezwe mara moja kwanza.';

  @override
  String get error_createIndex => 'Tengeneza Faharasa Inayokosekana';

  @override
  String get error_createIndexHint =>
      'Hii inafungua Firebase Console ikiwa na faharasa inayohitajika tayari imejazwa.';

  @override
  String get maintenance_title => 'Tutarudi hivi punde';

  @override
  String get maintenance_defaultMessage =>
      'Tunafanya matengenezo yaliyopangwa kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.';

  @override
  String get time_justNow => 'Sasa hivi';

  @override
  String time_minutesAgo(int count) {
    return 'dakika $count zilizopita';
  }

  @override
  String time_hoursAgo(int count) {
    return 'saa $count zilizopita';
  }

  @override
  String time_daysAgo(int count) {
    return 'siku $count zilizopita';
  }

  @override
  String get payments_method => 'Njia ya Malipo';

  @override
  String get products_categoriesHeading => 'MAKUNDI';

  @override
  String get products_stockStatusHeading => 'HALI YA STOO';

  @override
  String get products_allProducts => 'Bidhaa Zote';

  @override
  String get products_statusAll => 'Hali Zote';

  @override
  String get products_statusInStock => 'Ipo Stoo';

  @override
  String get products_statusLowStock => 'Stoo Chache';

  @override
  String get products_statusReorderSoon => 'Agiza Karibuni';

  @override
  String get products_statusDepleted => 'Imeisha';

  @override
  String get products_statusExpired => 'Muda Umepita';

  @override
  String get summary_trendNew => 'Mpya';

  @override
  String get loading_accountTitle => 'Inapakia akaunti yako...';

  @override
  String get loading_accountSubtitle =>
      'Inaandaa taarifa na huduma za kituo chako';

  @override
  String facilities_settingUp(String facilityName) {
    return 'Inaandaa $facilityName...';
  }

  @override
  String get facilities_yourFacility => 'kituo chako';

  @override
  String get subscription_expiredTitle => 'Usajili Umekwisha';

  @override
  String get subscription_expiredAssistant =>
      'Usajili wa kituo hiki umekwisha, kwa hiyo mauzo na huduma mpya haziwezi kurekodiwa kwa sasa. Bado unaweza kuona taarifa zote zilizopo. Tafadhali muombe msimamizi wako ahuishe usajili.';

  @override
  String get subscription_expiredAdmin =>
      'Usajili wako umekwisha, kwa hiyo mauzo na huduma mpya haziwezi kurekodiwa kwa sasa. Bado unaweza kuona taarifa zako zote zilizopo. Tuma malipo ili kurejesha huduma kamili.';

  @override
  String get subscription_goTo => 'Nenda kwenye Usajili';

  @override
  String get productCategory_antibiotic => 'Antibiotiki';

  @override
  String get productCategory_anthelmintics => 'Dawa za Minyoo';

  @override
  String get productCategory_vitaminsSupplements => 'Vitamini na Virutubisho';

  @override
  String get productCategory_hormonesReproductive => 'Homoni na Uzazi';

  @override
  String get productCategory_vaccines => 'Chanjo';

  @override
  String get productCategory_disinfectant => 'Dawa za Kuua Vijidudu';

  @override
  String get productCategory_feeds => 'Vyakula vya Mifugo';

  @override
  String get productCategory_antiInflammatory => 'Dawa za Kupunguza Uvimbe';

  @override
  String get productCategory_ectoparasiticides => 'Dawa za Kupe na Viroboto';

  @override
  String get productCategory_woundManagement => 'Matibabu ya Vidonda';

  @override
  String get productCategory_surgicalSupplies => 'Vifaa vya Upasuaji';

  @override
  String get productCategory_farmToolsEquipment => 'Zana na Vifaa vya Shamba';

  @override
  String get productCategory_seeds => 'Mbegu';

  @override
  String get productCategory_fertilizers => 'Mbolea';

  @override
  String get productCategory_cropPesticides => 'Viuatilifu vya Mazao';

  @override
  String get productCategory_miscellaneous => 'Mengineyo';

  @override
  String get productCategory_uncategorized => 'Bila Kundi';

  @override
  String get productGroup_vet => 'Mifugo';

  @override
  String get productGroup_agro => 'Kilimo';

  @override
  String get productGroup_veterinary => 'Tiba ya Mifugo';

  @override
  String get productType_injectable => 'Sindano';

  @override
  String get productType_oralLiquid => 'Maji ya Kunywa';

  @override
  String get productType_powder => 'Unga';

  @override
  String get productType_tabletBolus => 'Vidonge/Bolus';

  @override
  String get productType_topical => 'Ya Kupaka';

  @override
  String get productType_intramammary => 'Ya Kiwele';

  @override
  String get productType_spray => 'Ya Kunyunyiza';

  @override
  String get productType_granules => 'Chembechembe';

  @override
  String get productType_wettablePowder => 'Unga wa Kuchanganya na Maji';

  @override
  String get productType_emulsifiableConcentrate =>
      'Kimiminika cha Kuchanganya (EC)';

  @override
  String get productType_seed => 'Mbegu';

  @override
  String get productType_fertilizer => 'Mbolea';

  @override
  String get productType_feed => 'Chakula cha Mifugo';

  @override
  String get productType_equipment => 'Kifaa';

  @override
  String get productType_other => 'Nyingine';

  @override
  String get unit_pcs => 'pcs';

  @override
  String get unit_kg => 'kg';

  @override
  String get unit_g => 'g';

  @override
  String get unit_litres => 'lita';

  @override
  String get unit_ml => 'ml';

  @override
  String get unit_vials => 'vichupa';

  @override
  String get unit_ampoules => 'ampuli';

  @override
  String get unit_bottles => 'chupa';

  @override
  String get unit_sachets => 'sacheti';

  @override
  String get unit_sacks => 'magunia';

  @override
  String get unit_bags => 'mifuko';

  @override
  String get unit_boxes => 'maboksi';

  @override
  String get unit_cartons => 'katoni';

  @override
  String get unit_packs => 'pakiti';

  @override
  String get unit_strips => 'kadi';

  @override
  String get unit_tablets => 'vidonge';

  @override
  String get unit_tubes => 'tyubu';

  @override
  String get unit_rolls => 'roli';

  @override
  String get unit_pairs => 'jozi';

  @override
  String get unit_others => 'nyinginezo';

  @override
  String get serviceCategory_surgical => 'Upasuaji';

  @override
  String get serviceCategory_treatment => 'Matibabu';

  @override
  String get serviceCategory_management => 'Usimamizi';

  @override
  String get serviceCategory_consultation => 'Ushauri';

  @override
  String get serviceCategory_diagnostics => 'Uchunguzi';

  @override
  String get serviceCategory_preventive => 'Kinga';

  @override
  String get serviceCategory_other => 'Nyingine';

  @override
  String get facilityType_agrovet => 'Agrovet';

  @override
  String get facilityType_vetClinic => 'Kliniki ya Mifugo';

  @override
  String get facilityType_vetHospital => 'Hospitali ya Mifugo';

  @override
  String get facilityType_ambulatoryVet => 'Daktari wa Mifugo wa Kutembelea';

  @override
  String get facilityType_other => 'Nyingine';

  @override
  String get paymentMethod_cash => 'Taslimu';

  @override
  String get paymentMethod_mPesa => 'M-Pesa';

  @override
  String get paymentMethod_mixxByYas => 'Mixx by Yas';

  @override
  String get paymentMethod_haloPesa => 'HaloPesa';

  @override
  String get paymentMethod_airtelMoney => 'Airtel Money';

  @override
  String get paymentMethod_bankTransfer => 'Uhamisho wa Benki';

  @override
  String get paymentMethod_onCredit => 'Kwa Mkopo';

  @override
  String get activityType_account => 'Akaunti';

  @override
  String get activityType_debtors => 'Wadaiwa';

  @override
  String get activityType_products => 'Bidhaa';

  @override
  String get activityType_inventoryMove => 'Uhamisho wa Stoo';

  @override
  String get activityType_sales => 'Mauzo';

  @override
  String get activityType_sale => 'Mauzo';

  @override
  String get activityType_services => 'Huduma';

  @override
  String get activityType_transactions => 'Miamala';

  @override
  String get activityType_trash => 'Takataka';

  @override
  String get activityType_reportDraftDeleted => 'Rasimu ya Ripoti Imefutwa';

  @override
  String get restockFrequency_weekly => 'Kila Wiki';

  @override
  String get restockFrequency_everyTwoWeeks => 'Kila Wiki 2';

  @override
  String get restockFrequency_monthly => 'Kila Mwezi';

  @override
  String get restockFrequency_rarely => 'Mara Chache';

  @override
  String get role_admin => 'Msimamizi';

  @override
  String get role_assistant => 'Msaidizi';

  @override
  String get role_coAdmin => 'Msimamizi Mwenza';

  @override
  String get userStatus_pending => 'Anasubiri';

  @override
  String get userStatus_active => 'Hai';

  @override
  String get userStatus_deactivated => 'Amesimamishwa';

  @override
  String get userStatus_rejected => 'Amekataliwa';

  @override
  String get membershipAction_approved => 'Ameidhinishwa';

  @override
  String get membershipAction_rejected => 'Amekataliwa';

  @override
  String get membershipAction_deactivated => 'Amesimamishwa';

  @override
  String get membershipAction_reactivated => 'Amerejeshwa';

  @override
  String get facilityStatus_active => 'Inafanya Kazi';

  @override
  String get facilityStatus_inactive => 'Haifanyi Kazi';

  @override
  String get facilityStatus_pending => 'Inasubiri';

  @override
  String get submissionStatus_pending => 'Inasubiri';

  @override
  String get submissionStatus_approved => 'Imeidhinishwa';

  @override
  String get submissionStatus_rejected => 'Imekataliwa';

  @override
  String get plan_daily => 'Kila Siku';

  @override
  String get plan_weekly => 'Kila Wiki';

  @override
  String get plan_monthly => 'Kila Mwezi';

  @override
  String get plan_yearly => 'Kila Mwaka';

  @override
  String get clientType_farmer => 'Mkulima';

  @override
  String get clientType_vet => 'Daktari wa Mifugo';

  @override
  String get clientType_wholesaler => 'Muuzaji wa Jumla';

  @override
  String get clientType_retailer => 'Muuzaji wa Rejareja';

  @override
  String get clientType_other => 'Mwingine';

  @override
  String get farmerSubType_cropProducer => 'Mkulima wa Mazao';

  @override
  String get farmerSubType_animalKeeper => 'Mfugaji';

  @override
  String get animal_cattle => 'Ng\'ombe';

  @override
  String get animal_goat => 'Mbuzi';

  @override
  String get animal_sheep => 'Kondoo';

  @override
  String get animal_pig => 'Nguruwe';

  @override
  String get animal_donkey => 'Punda';

  @override
  String get animal_chicken => 'Kuku';

  @override
  String get animal_duck => 'Bata';

  @override
  String get animal_turkey => 'Bata Mzinga';

  @override
  String get animal_guineaFowl => 'Kanga';

  @override
  String get animal_bees => 'Nyuki';

  @override
  String get animal_dog => 'Mbwa';

  @override
  String get animal_cat => 'Paka';

  @override
  String get animal_rabbit => 'Sungura';

  @override
  String get animalGroup_livestock => 'Mifugo';

  @override
  String get animalGroup_poultry => 'Ndege wa Kufugwa';

  @override
  String get animalGroup_other => 'Wengine';

  @override
  String get vetPractice_clinic => 'Kliniki';

  @override
  String get vetPractice_consultant => 'Mshauri';

  @override
  String get vetPractice_hospital => 'Hospitali';

  @override
  String get vetPractice_ambulatory => 'Huduma ya Kutembelea';

  @override
  String get clientStatus_active => 'Hai';

  @override
  String get clientStatus_inactive => 'Hayuko Hai';

  @override
  String get paymentStatus_paid => 'Imelipwa';

  @override
  String get paymentStatus_partial => 'Imelipwa Sehemu';

  @override
  String get paymentStatus_unpaid => 'Haijalipwa';

  @override
  String get moveReason_expired => 'Imeisha Muda';

  @override
  String get moveReason_deteriorated => 'Imeharibika';

  @override
  String get moveReason_other => 'Nyingine (eleza)';

  @override
  String get cropGroup_foodCrops => 'Mazao ya Chakula';

  @override
  String get cropGroup_cashCrops => 'Mazao ya Biashara';

  @override
  String get cropGroup_vegetables => 'Mboga';

  @override
  String get cropGroup_fruits => 'Matunda';

  @override
  String get crop_maize => 'Mahindi';

  @override
  String get crop_rice => 'Mpunga';

  @override
  String get crop_wheat => 'Ngano';

  @override
  String get crop_cassava => 'Muhogo';

  @override
  String get crop_sorghum => 'Mtama';

  @override
  String get crop_millet => 'Uwele';

  @override
  String get crop_beans => 'Maharage';

  @override
  String get crop_bananas => 'Ndizi';

  @override
  String get crop_sweetPotatoes => 'Viazi Vitamu';

  @override
  String get crop_irishPotatoes => 'Viazi Mviringo';

  @override
  String get crop_groundnuts => 'Karanga';

  @override
  String get crop_coffee => 'Kahawa';

  @override
  String get crop_cotton => 'Pamba';

  @override
  String get crop_tobacco => 'Tumbaku';

  @override
  String get crop_cashewNuts => 'Korosho';

  @override
  String get crop_sisal => 'Mkonge';

  @override
  String get crop_tea => 'Chai';

  @override
  String get crop_pyrethrum => 'Pareto';

  @override
  String get crop_sugarcane => 'Miwa';

  @override
  String get crop_cloves => 'Karafuu';

  @override
  String get crop_sesame => 'Ufuta';

  @override
  String get crop_sunflower => 'Alizeti';

  @override
  String get crop_tomatoes => 'Nyanya';

  @override
  String get crop_onions => 'Vitunguu';

  @override
  String get crop_cabbage => 'Kabichi';

  @override
  String get crop_okra => 'Bamia';

  @override
  String get crop_mangoes => 'Maembe';

  @override
  String get crop_oranges => 'Machungwa';

  @override
  String get crop_avocado => 'Parachichi';

  @override
  String get crop_watermelon => 'Tikiti Maji';

  @override
  String get expenseGroup_administration => 'Utawala';

  @override
  String get expenseGroup_premisesUtilities => 'Majengo na Huduma';

  @override
  String get expenseGroup_operations => 'Uendeshaji';

  @override
  String get expenseGroup_transport => 'Usafiri';

  @override
  String get expenseGroup_business => 'Biashara';

  @override
  String get expenseGroup_other => 'Mengineyo';

  @override
  String get expenseCategory_mealsRefreshments => 'Chakula na Viburudisho';

  @override
  String get expenseCategory_salariesWages => 'Mishahara na Ujira';

  @override
  String get expenseCategory_officeSupplies => 'Vifaa vya Ofisi';

  @override
  String get expenseCategory_electricity => 'Umeme';

  @override
  String get expenseCategory_water => 'Maji';

  @override
  String get expenseCategory_rent => 'Kodi ya Pango';

  @override
  String get expenseCategory_drugsMedicines => 'Dawa';

  @override
  String get expenseCategory_veterinarySupplies => 'Vifaa vya Mifugo';

  @override
  String get expenseCategory_fuel => 'Mafuta';

  @override
  String get expenseCategory_vehicleMaintenance => 'Matengenezo ya Gari';

  @override
  String get expenseCategory_marketing => 'Matangazo';

  @override
  String get expenseCategory_licencesRegistration => 'Leseni na Usajili';

  @override
  String get incomeCategory_commission => 'Mapato ya Kamisheni';

  @override
  String get incomeCategory_delivery => 'Mapato ya Usafirishaji';

  @override
  String get incomeCategory_training => 'Mapato ya Mafunzo';

  @override
  String get incomeCategory_consultancy => 'Mapato ya Ushauri';

  @override
  String get incomeCategory_rental => 'Mapato ya Kodi ya Pango';

  @override
  String get incomeCategory_interest => 'Mapato ya Riba';

  @override
  String get incomeCategory_refundsReceived => 'Marejesho Yaliyopokelewa';

  @override
  String get incomeCategory_discountsReceived => 'Punguzo Lililopokelewa';

  @override
  String get incomeCategory_assetDisposal => 'Mapato ya Kuuza Mali';

  @override
  String get incomeCategory_other => 'Mapato Mengine';

  @override
  String get common_method => 'Njia';

  @override
  String common_filterValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String common_totalValue(String amount) {
    return 'Jumla: $amount';
  }

  @override
  String get common_today => 'Leo';

  @override
  String get common_yesterday => 'Jana';

  @override
  String common_perPage(int count) {
    return '$count kwa ukurasa';
  }

  @override
  String common_page(int page) {
    return 'Ukurasa $page';
  }

  @override
  String get common_dialerFailed => 'Imeshindwa kufungua simu';

  @override
  String get common_printReceipt => 'Chapisha Risiti';

  @override
  String get common_resetFilters => 'Futa vichujio';

  @override
  String get common_notesOptional => 'Maelezo (si lazima)';

  @override
  String get common_notifications => 'Arifa';

  @override
  String get payments_title => 'Malipo';

  @override
  String payments_titleForClient(String clientName) {
    return 'Malipo - $clientName';
  }

  @override
  String get payments_subtitle =>
      'Malipo yote yaliyopokelewa katika biashara yako';

  @override
  String get payments_typeSales => 'Mauzo';

  @override
  String get payments_typeServices => 'Huduma';

  @override
  String get payments_typeDebtRepayments => 'Marejesho ya Madeni';

  @override
  String get payments_typeOtherIncome => 'Mapato Mengine';

  @override
  String get payments_allMethods => 'Njia Zote';

  @override
  String get payments_searchHint => 'Tafuta mlipaji, kumbukumbu, ankara...';

  @override
  String payments_newEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Maingizo $count mapya yapo',
      one: 'Ingizo 1 jipya lipo',
    );
    return '$_temp0';
  }

  @override
  String get payments_emptyPeriod => 'Hakuna malipo katika kipindi hiki.';

  @override
  String get payments_colDateTime => 'Tarehe na Saa';

  @override
  String get payments_payer => 'Mlipaji';

  @override
  String get payments_source => 'Chanzo';

  @override
  String get payments_reference => 'Kumbukumbu';

  @override
  String get payments_recordedBy => 'Imerekodiwa na';

  @override
  String get payments_thisWeek => 'Wiki Hii';

  @override
  String get payments_thisMonth => 'Mwezi Huu';

  @override
  String payments_paymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'malipo $count',
      one: 'malipo 1',
    );
    return '$_temp0';
  }

  @override
  String get payments_outstanding => 'Yanayodaiwa';

  @override
  String payments_debtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'madeni $count',
      one: 'deni 1',
    );
    return '$_temp0';
  }

  @override
  String get payments_detailsTitle => 'Maelezo ya Malipo';

  @override
  String get payments_received => 'Malipo Yamepokelewa';

  @override
  String get payments_noReceipt => 'Hakuna risiti ya malipo haya';

  @override
  String get subscription_title => 'Usajili';

  @override
  String get subscription_statusTrial => 'Majaribio';

  @override
  String get subscription_statusTrialNoSetup =>
      'Majaribio - bado hakuna usajili';

  @override
  String get subscription_statusActive => 'Hai';

  @override
  String get subscription_statusGrace => 'Malipo yamechelewa - muda wa neema';

  @override
  String get subscription_statusLocked => 'Imefungwa - usajili umekwisha';

  @override
  String subscription_expiredOn(String date) {
    return 'Uliisha $date';
  }

  @override
  String subscription_trialExpiresOn(String date) {
    return 'Majaribio yanaisha $date';
  }

  @override
  String subscription_renewsOn(String date) {
    return 'Unasasishwa / unaisha $date';
  }

  @override
  String get subscription_readOnly =>
      'Akaunti yako iko katika hali ya kusoma tu. Tuma malipo hapa chini ili kurejesha huduma kamili - taarifa zako ziko salama na hazijaguswa.';

  @override
  String subscription_promoAllPlans(String percent) {
    return 'Punguzo la $percent% kwa kila mpango - linatumika lenyewe hapa chini.';
  }

  @override
  String subscription_promoSomePlans(String percent) {
    return 'Punguzo la $percent% kwa mipango iliyochaguliwa - linatumika lenyewe hapa chini.';
  }

  @override
  String get subscription_choosePlan => 'Chagua Mpango';

  @override
  String get subscription_referenceLabel => 'Namba ya Muamala / Uthibitisho';

  @override
  String get subscription_referenceHint => 'mf. namba ya uthibitisho ya M-Pesa';

  @override
  String get subscription_attachProof => 'Ambatisha Uthibitisho (si lazima)';

  @override
  String get subscription_proofAttached => 'Uthibitisho umeambatishwa';

  @override
  String get subscription_pendingWarning =>
      'Malipo yako ya mwisho bado yanakaguliwa. Tafadhali subiri yaidhinishwe au yakataliwe kabla ya kutuma mengine.';

  @override
  String get subscription_priceUnavailableWarning =>
      'Bei ya mpango huu haipatikani kwa sasa. Tafadhali jaribu tena baadaye au wasiliana na msaada.';

  @override
  String get subscription_awaitingReview => 'Inasubiri Ukaguzi';

  @override
  String get subscription_pricingUnavailable => 'Bei Haipatikani';

  @override
  String get subscription_submitForReview => 'Tuma Malipo kwa Ukaguzi';

  @override
  String get subscription_recentSubmissions => 'Malipo ya Karibuni';

  @override
  String get subscription_noSubmissionsYetDot =>
      'Bado hakuna malipo yaliyotumwa.';

  @override
  String get subscription_viewAll => 'Tazama yote';

  @override
  String get subscription_enterReference =>
      'Weka namba ya kumbukumbu / uthibitisho wa malipo';

  @override
  String get subscription_submitted => 'Malipo yametumwa';

  @override
  String get subscription_submittedDetail =>
      'Yatakaguliwa na kuthibitishwa hivi karibuni';

  @override
  String get subscription_submitFailed => 'Imeshindwa kutuma malipo';

  @override
  String subscription_rejectReason(String reason) {
    return 'Sababu: $reason';
  }

  @override
  String get subscription_noReason => 'Hakuna sababu iliyotolewa';

  @override
  String get subscription_historyTitle => 'Historia ya Usajili';

  @override
  String get subscription_historySubtitle =>
      'Malipo yako na hali ya ukaguzi wake';

  @override
  String subscription_platformTeam(String appName) {
    return 'Timu ya $appName';
  }

  @override
  String subscription_historyLoadError(String error) {
    return 'Imeshindwa kupakia historia: $error';
  }

  @override
  String get subscription_noSubmissionsYet => 'Bado hakuna malipo yaliyotumwa';

  @override
  String get subscription_noSubmissionsHint =>
      'Malipo utakayotuma yataonekana hapa.';

  @override
  String get subscription_totalSubmissions => 'Jumla ya Malipo Yaliyotumwa';

  @override
  String get subscription_allPayments => 'Malipo yote';

  @override
  String get subscription_awaitingReviewLower => 'Inasubiri ukaguzi';

  @override
  String get subscription_notAccepted => 'Hayakukubaliwa';

  @override
  String get subscription_searchHint =>
      'Tafuta kwa mpango, njia, kumbukumbu au sababu...';

  @override
  String get subscription_plan => 'Mpango';

  @override
  String get subscription_noMatches =>
      'Hakuna malipo yanayolingana na vichujio vyako';

  @override
  String get subscription_colSubmitted => 'Yalitumwa';

  @override
  String subscription_rejectedOn(String date) {
    return 'Yalikataliwa $date';
  }

  @override
  String get subscription_noSubmissions => 'Hakuna malipo';

  @override
  String subscription_showingRange(int total, int start, int end) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya malipo $total',
      one: 'Inaonyesha $start hadi $end kati ya malipo 1',
    );
    return '$_temp0';
  }

  @override
  String get store_title => 'Stoo';

  @override
  String get store_subtitle => 'Simamia bidhaa zako za stoo';

  @override
  String get store_stockValue => 'Thamani ya Stoo';

  @override
  String get store_searchHint => 'Tafuta bidhaa, chapa au bechi...';

  @override
  String store_productsInStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bidhaa $count ziko stoo',
      one: 'Bidhaa 1 iko stoo',
    );
    return '$_temp0';
  }

  @override
  String get store_empty => 'Hakuna bidhaa stoo';

  @override
  String get products_totalProducts => 'Jumla ya Bidhaa';

  @override
  String get products_statusActive => 'Hai';

  @override
  String get products_statusNotStocked => 'Haijawahi Kuwekwa';

  @override
  String get products_statusUnknown => 'Haijulikani';

  @override
  String get products_statusExpiringSoon => 'Inakaribia Kuisha Muda';

  @override
  String get products_confirmDeleteTitle => 'Thibitisha Kufuta';

  @override
  String get products_confirmDeleteBody =>
      'Una uhakika unataka kufuta bidhaa hii?';

  @override
  String get products_movedToTrash => 'Bidhaa imehamishiwa Takataka';

  @override
  String get products_deleteFailed => 'Imeshindwa kufuta bidhaa';

  @override
  String get products_restored => 'Bidhaa imerejeshwa';

  @override
  String get products_restoreFailed => 'Imeshindwa kurejesha bidhaa';

  @override
  String get products_noMatches =>
      'Hakuna bidhaa zinazolingana na vichujio vyako';

  @override
  String get products_restockShelf => 'Jaza Rafu';

  @override
  String get products_stock => 'Stoo';

  @override
  String get products_price => 'Bei';

  @override
  String get products_release => 'Toa';

  @override
  String get products_addNewBatch => 'Ongeza Bechi Mpya';

  @override
  String get products_viewBatches => 'Tazama Bechi';

  @override
  String get products_stockAlerts => 'Tahadhari za Stoo';

  @override
  String get products_addProduct => 'Ongeza Bidhaa';

  @override
  String products_showingRange(int total, int start, int end) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya bidhaa $total',
      one: 'Inaonyesha $start hadi $end kati ya bidhaa 1',
    );
    return '$_temp0';
  }

  @override
  String products_sellableBatch(String quantity, String unit, String batch) {
    return 'Inayouzwa: $quantity $unit • Bechi: $batch';
  }

  @override
  String products_buyPrice(String price) {
    return 'Kununua: $price';
  }

  @override
  String products_expiryDate(String date) {
    return 'Mwisho wa matumizi: $date';
  }

  @override
  String store_batchName(String batchNo) {
    return 'Bechi $batchNo';
  }

  @override
  String get store_unlabeledBatch => 'bechi isiyo na namba';

  @override
  String get store_expiredStockTitle => 'Bidhaa Iliyoisha Muda';

  @override
  String get store_expiredStockBody =>
      'Bidhaa hii imeisha muda. Bado unataka kuitoa kwenda rafuni?';

  @override
  String store_expiredPortionLine(String quantity, String unit, String batch) {
    return '• $quantity $unit kutoka $batch';
  }

  @override
  String get store_releaseAnyway => 'Toa Hata Hivyo';

  @override
  String get store_releaseTitle => 'Toa Kwenda Rafuni';

  @override
  String store_availableStock(String quantity, String unit) {
    return 'Stoo iliyopo: $quantity $unit';
  }

  @override
  String get store_quantityToRelease => 'Kiasi cha kutoa';

  @override
  String get store_notesHint => 'mf., Ubora umekaguliwa, tayari kuuzwa';

  @override
  String store_quantityRange(String max) {
    return 'Weka kiasi kuanzia 1 hadi $max';
  }

  @override
  String store_released(String quantity, String unit, String product) {
    return 'Umetoa $quantity $unit za $product kwenda rafuni';
  }

  @override
  String get store_releaseFailed => 'Imeshindwa kutoa bidhaa';

  @override
  String get common_unknown => 'Haijulikani';

  @override
  String common_showingRange(int start, int end) {
    return 'Inaonyesha $start hadi $end';
  }

  @override
  String get common_phone => 'Simu';

  @override
  String get common_address => 'Anwani';

  @override
  String get common_name => 'Jina';

  @override
  String get common_description => 'Maelezo';

  @override
  String get common_category => 'Kundi';

  @override
  String get common_required => 'Inahitajika';

  @override
  String common_requiredLabel(String label) {
    return '$label *';
  }

  @override
  String get common_export => 'Hamisha';

  @override
  String get common_actions => 'Vitendo';

  @override
  String get common_summary => 'Muhtasari';

  @override
  String get common_noNotes => 'Hakuna maelezo yaliyoongezwa';

  @override
  String get common_none => 'Hakuna';

  @override
  String get common_searchEllipsis => 'Tafuta...';

  @override
  String get common_noFacility => 'Hakuna kituo kilichochaguliwa';

  @override
  String get common_linkFailed => 'Imeshindwa kufungua kiungo';

  @override
  String get common_linkFailedDetail =>
      'Nakili kutoka kwenye kumbukumbu ya hitilafu badala yake';

  @override
  String get common_noPrinterTitle => 'Hakuna Printa Iliyounganishwa';

  @override
  String get common_noPrinterBody =>
      'Unganisha printa ya risiti ya Bluetooth kwenye Mipangilio ya Printa kwanza.';

  @override
  String get common_goToPrinterSettings => 'Nenda kwenye Mipangilio ya Printa';

  @override
  String get common_receiptSentToPrinter => 'Risiti imetumwa kwa printa';

  @override
  String get common_printFailed => 'Imeshindwa kuchapisha risiti';

  @override
  String get common_printFailedDetail => 'Printa haikuikubali';

  @override
  String get transactionType_expense => 'Matumizi';

  @override
  String get transactions_title => 'Miamala';

  @override
  String get transactions_subtitle => 'Miamala yote ya mapato na matumizi';

  @override
  String get transactions_record => 'Rekodi Muamala';

  @override
  String get transactions_edit => 'Hariri Muamala';

  @override
  String get transactions_update => 'Sasisha Muamala';

  @override
  String get transactions_expenses => 'Matumizi';

  @override
  String get transactions_incomeVsExpenses =>
      'Mapato Mengine dhidi ya Matumizi';

  @override
  String get transactions_searchHint => 'Tafuta kwa maelezo, kundi...';

  @override
  String transactions_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Miamala $count',
      one: 'Muamala 1',
    );
    return '$_temp0';
  }

  @override
  String get transactions_empty => 'Hakuna miamala.';

  @override
  String transactions_emptyForType(String type) {
    return 'Hakuna miamala ya $type.';
  }

  @override
  String get transactions_deleteTitle => 'Futa muamala huu?';

  @override
  String transactions_deleteBody(String description, String amount) {
    return '\"$description\" - $amount\n\nUnaweza kuurejesha kutoka Takataka.';
  }

  @override
  String get transactions_movedToTrash => 'Muamala umehamishiwa Takataka';

  @override
  String get transactions_deleteFailed => 'Imeshindwa kufuta muamala';

  @override
  String get transactions_restored => 'Muamala umerejeshwa';

  @override
  String get transactions_restoreFailed => 'Imeshindwa kurejesha muamala';

  @override
  String get transactions_detailsTitle => 'Maelezo ya Muamala';

  @override
  String get transactions_allShown =>
      'Inaonyesha miamala yote ya hivi karibuni';

  @override
  String get transactions_loadMore => 'Pakia miamala zaidi';

  @override
  String get transactions_fillRequired =>
      'Jaza sehemu zote zinazohitajika kwa usahihi';

  @override
  String get transactions_selectPaymentMethod =>
      'Chagua jinsi muamala huu ulivyolipwa';

  @override
  String get transactions_updated => 'Muamala umesasishwa';

  @override
  String get transactions_updateFailed => 'Imeshindwa kusasisha muamala';

  @override
  String get transactions_saved => 'Muamala umehifadhiwa';

  @override
  String get transactions_saveFailed => 'Imeshindwa kuhifadhi muamala';

  @override
  String get transactions_selectCategory => 'Chagua kundi...';

  @override
  String get transactions_descriptionHint => 'Hii ilikuwa ya nini?';

  @override
  String get transactions_noteLabel => 'Kumbukumbu/Maelezo (si lazima)';

  @override
  String get transactions_noteHint => 'Ongeza taarifa yoyote ya ziada';

  @override
  String get transactions_amountPayment => 'Kiasi na Malipo';

  @override
  String transactions_amountRequired(String currency) {
    return 'Kiasi ($currency) *';
  }

  @override
  String get transactions_selectMethod => 'Chagua njia';

  @override
  String get transactions_noCategories => 'Hakuna makundi yaliyopatikana';

  @override
  String get transactions_selectCategoryTitle => 'Chagua Kundi';

  @override
  String get transactions_searchCategories => 'Tafuta makundi...';

  @override
  String get debtSource_service => 'Huduma';

  @override
  String get debtors_title => 'Madeni Yanayoendelea';

  @override
  String get debtors_subtitle => 'Fuatilia na simamia madeni yote yanayodaiwa';

  @override
  String debtors_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wadaiwa $count wapya wapo',
      one: 'Mdaiwa 1 mpya yupo',
    );
    return '$_temp0';
  }

  @override
  String get debtors_emptyNone => 'Hakuna madeni yanayodaiwa';

  @override
  String get debtors_emptySearch =>
      'Hakuna wadaiwa wanaolingana na utafutaji wako';

  @override
  String get debtors_totalDebtors => 'Jumla ya Wadaiwa';

  @override
  String get debtors_withBalance => 'Wenye salio linalodaiwa';

  @override
  String get debtors_totalOwed => 'Jumla Inayodaiwa';

  @override
  String get debtors_outstandingBalance => 'Salio linalodaiwa';

  @override
  String get debtors_overdueDebtors => 'Wadaiwa Waliochelewa';

  @override
  String debtors_overDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Zaidi ya siku $days',
      one: 'Zaidi ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String get debtors_paidThisMonth => 'Kilicholipwa Mwezi Huu';

  @override
  String get debtors_fromDebtPayments => 'Kutoka malipo ya madeni';

  @override
  String get debtors_recordPayment => 'Rekodi Malipo';

  @override
  String get debtors_overdue => 'Imechelewa';

  @override
  String get debtors_current => 'Ndani ya muda';

  @override
  String get debtors_colOverdue => 'Muda wa Kuchelewa';

  @override
  String debtors_rangeDays(int from, int to) {
    return 'Siku $from-$to za kuchelewa';
  }

  @override
  String debtors_rangeDaysPlus(int from) {
    return 'Siku $from+ za kuchelewa';
  }

  @override
  String get debtors_searchHint => 'Tafuta mdaiwa kwa jina...';

  @override
  String get debtors_debtor => 'Mdaiwa';

  @override
  String get debtors_oldestDebtSince => 'Deni la Zamani Zaidi Tangu';

  @override
  String debtors_daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Siku $count',
      one: 'Siku 1',
    );
    return '$_temp0';
  }

  @override
  String get debtors_sendReminder => 'Tuma Ukumbusho';

  @override
  String get debtors_paymentHistory => 'Historia ya Malipo';

  @override
  String get debtors_none => 'Hakuna wadaiwa';

  @override
  String get debtors_detailsTitle => 'Maelezo ya Mdaiwa';

  @override
  String get debtors_overdueAmount => 'Kiasi Kilichochelewa';

  @override
  String get debtors_lastTransaction => 'Muamala wa Mwisho';

  @override
  String debtors_outstandingDebts(int count) {
    return 'Madeni Yanayodaiwa ($count)';
  }

  @override
  String get debtors_addNote => 'Ongeza Maelezo';

  @override
  String debtors_invoiceLine(String invoice, String date) {
    return 'Ankara: $invoice • $date';
  }

  @override
  String get debtors_pay => 'Lipa';

  @override
  String get debtors_exportFailed =>
      'Imeshindwa kuhamisha madeni yanayoendelea';

  @override
  String get debtors_noteHint => 'mf. Ameahidi kulipa kufikia Ijumaa';

  @override
  String get debtors_noteSaveFailed => 'Imeshindwa kuhifadhi maelezo';

  @override
  String debtors_reminderBody(String name, String amount) {
    return 'Mkumbushe $name kuhusu salio lake la $amount kupitia:';
  }

  @override
  String get debtors_viaSms => 'SMS';

  @override
  String get debtors_viaWhatsApp => 'WhatsApp';

  @override
  String get debtors_whatsAppFailed => 'Imeshindwa kufungua WhatsApp';

  @override
  String get debtors_messagesFailed => 'Imeshindwa kufungua Ujumbe';

  @override
  String get debtors_reminderFailed => 'Imeshindwa kutuma ukumbusho';

  @override
  String get debtors_errChooseDebtor => 'Chagua mdaiwa wa malipo haya';

  @override
  String debtors_errNoMatch(String name) {
    return 'Hakuna mdaiwa aliyepatikana kwa jina \"$name\"';
  }

  @override
  String get debtors_errTooShort => 'Andika angalau herufi 2 za jina la mdaiwa';

  @override
  String get debtors_errPickSuggestion =>
      'Chagua mdaiwa kutoka kwenye mapendekezo';

  @override
  String debtors_clientLabel(String name) {
    return 'Mteja: $name';
  }

  @override
  String get debtors_totalOwedLabel => 'Jumla inayodaiwa:';

  @override
  String get debtors_selectPaymentMethod =>
      'Chagua jinsi malipo haya yalivyofanywa';

  @override
  String get debtors_signInAgain => 'Ingia tena ili urekodi malipo haya';

  @override
  String get debtors_selectClient => 'Chagua mteja';

  @override
  String debtors_paymentRecorded(String amount, String name) {
    return 'Malipo ya $amount yamerekodiwa kwa $name';
  }

  @override
  String get debtors_paymentSaveFailed => 'Imeshindwa kuhifadhi malipo';

  @override
  String get debtors_debtorSearchHint => 'Tafuta kwa jina au simu';

  @override
  String get debtors_debtorHelper =>
      'Wateja wanaodaiwa pesa kwa sasa ndio pekee walioorodheshwa';

  @override
  String debtors_amountOwed(String amount) {
    return 'Kiasi kinachodaiwa: $amount';
  }

  @override
  String get debtors_paymentAmount => 'Kiasi cha Malipo';

  @override
  String get debtors_errEnterAmount => 'Weka kiasi';

  @override
  String get debtors_errValidAmount => 'Weka kiasi sahihi';

  @override
  String get debtors_errMoreThanOwed => 'Huwezi kulipa zaidi ya kinachodaiwa';

  @override
  String get debtors_errMoreThanTotal =>
      'Huwezi kulipa zaidi ya jumla inayodaiwa';

  @override
  String get debtors_savePayment => 'Hifadhi Malipo';

  @override
  String get clients_title => 'Wateja';

  @override
  String get clients_subtitle => 'Simamia wateja wako wote mahali pamoja';

  @override
  String get clients_add => 'Ongeza Mteja';

  @override
  String get clients_edit => 'Hariri Mteja';

  @override
  String get clients_total => 'Jumla ya Wateja';

  @override
  String get clients_allTime => 'Muda wote';

  @override
  String get clients_newThisMonth => 'Wapya Mwezi Huu';

  @override
  String get clients_mostActiveType => 'Aina Inayoongoza';

  @override
  String clients_percentOfClients(String percent) {
    return '$percent% ya wateja';
  }

  @override
  String get clients_lastAdded => 'Aliyeongezwa Mwisho';

  @override
  String get clients_searchHint => 'Tafuta kwa jina, simu, anwani...';

  @override
  String get clients_deleteTitle => 'Futa Mteja';

  @override
  String get clients_deleteFailed => 'Imeshindwa kufuta mteja';

  @override
  String clients_deleteToTrashBody(String name) {
    return '\"$name\" anahamishiwa Tupio. Unaweza kutendua sasa au kumrejesha kutoka Tupio ndani ya siku 30.';
  }

  @override
  String get clients_movedToTrash => 'Mteja amehamishiwa Tupio';

  @override
  String get clients_restored => 'Mteja amerejeshwa';

  @override
  String get clients_restoreFailed => 'Imeshindwa kumrejesha mteja';

  @override
  String clients_deleteRefusedOwes(String amount) {
    return 'Mteja huyu bado anadaiwa $amount. Kamilisha malipo au ondoa madeni kwanza.';
  }

  @override
  String get clients_shareFailed => 'Imeshindwa kushiriki kadi ya mteja';

  @override
  String get clients_detailsTitle => 'Maelezo ya Mteja';

  @override
  String get clients_clientType => 'Aina ya Mteja';

  @override
  String get clients_joinedOn => 'Alijiunga Tarehe';

  @override
  String get clients_totalTransactions => 'Jumla ya Miamala';

  @override
  String get clients_totalSpent => 'Jumla Aliyotumia';

  @override
  String get clients_saveShare => 'Hifadhi / Shiriki';

  @override
  String get clients_searchingNote => 'Inatafuta kwa jina (katika aina zote)';

  @override
  String clients_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wateja $count wapya wapo',
      one: 'Mteja 1 mpya yupo',
    );
    return '$_temp0';
  }

  @override
  String clients_emptySearch(String query) {
    return 'Hakuna wateja wanaolingana na \"$query\"';
  }

  @override
  String get clients_empty => 'Hakuna wateja waliopatikana';

  @override
  String get clients_client => 'Mteja';

  @override
  String get clients_indexNeeded =>
      'Kichujio hiki kinahitaji faharasa ya hifadhidata itengenezwe mara moja kwanza.';

  @override
  String clients_loadError(String error) {
    return 'Imeshindwa kupakia wateja: $error';
  }

  @override
  String get clients_createIndex => 'Tengeneza Faharasa';

  @override
  String get clients_indexBuildingHint =>
      'Hii huchukua dakika moja au mbili kukamilika baada ya kuitengeneza - kisha jaribu kichujio hiki tena.';

  @override
  String get clients_none => 'Hakuna wateja';

  @override
  String get clients_errSelectType => 'Chagua angalau aina moja ya mteja';

  @override
  String get clients_saveFailed => 'Imeshindwa kuhifadhi mteja';

  @override
  String get clients_added => 'Mteja ameongezwa';

  @override
  String get clients_updated => 'Mteja amesasishwa';

  @override
  String get clients_duplicateTitle => 'Mteja tayari yupo';

  @override
  String get clients_duplicateByPhone =>
      'Mteja mwenye namba hii ya simu tayari yupo:';

  @override
  String get clients_duplicateByName =>
      'Mteja mwenye jina linalofanana tayari yupo:';

  @override
  String get clients_noPhone => 'Hakuna namba ya simu';

  @override
  String clients_duplicateBody(String action, String match) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'add': 'mteja huyu hajahifadhiwa',
      'other': 'mabadiliko yako hayajahifadhiwa',
    });
    String _temp1 = intl.Intl.selectLogic(match, {
      'phone': 'weka namba nyingine ya simu',
      'other': 'badilisha jina kidogo',
    });
    return 'Ili kuepuka wateja waliorudiwa, $_temp0. Ikiwa ni mtu yule yule, tumia mteja aliyepo kutoka kwenye orodha ya Wateja. Ikiwa ni mtu tofauti, $_temp1 kisha ujaribu tena.';
  }

  @override
  String get clients_infoSection => 'Taarifa za Mteja';

  @override
  String get clients_nameHint => 'Weka jina la mteja';

  @override
  String get clients_phoneHint => 'mf. 07XX XXX XXX';

  @override
  String get clients_addressHint => 'Weka anwani';

  @override
  String get clients_notesHint => 'Taarifa yoyote ya ziada kuhusu mteja...';

  @override
  String get clients_quickSummary => 'Muhtasari wa Haraka';

  @override
  String get clients_tip =>
      'Unaweza kusasisha aina za wanyama au mazao ya mteja huyu wakati wowote kwa kuhariri wasifu wake.';

  @override
  String get clients_cropInfo => 'Taarifa za Mazao (Si lazima)';

  @override
  String get clients_animalInfo => 'Taarifa za Wanyama (Si lazima)';

  @override
  String get clients_cropHint =>
      'Ongeza mazao yanayolimwa na mteja huyu ikiwa yapo.';

  @override
  String get clients_animalHint =>
      'Ongeza wanyama anaowamiliki mteja huyu ikiwa wapo.';

  @override
  String get clients_farmerTypeHint =>
      'Chagua aina ya mkulima hapa chini ili kuongeza mazao au wanyama.';

  @override
  String get clients_farmerType => 'Aina ya Mkulima';

  @override
  String get clients_addCrops => 'Ongeza Mazao';

  @override
  String get clients_addAnimals => 'Ongeza Wanyama';

  @override
  String get clients_selectCrops => 'Chagua Mazao';

  @override
  String get clients_selectAnimals => 'Chagua Aina za Wanyama';

  @override
  String get clients_noMatches => 'Hakuna kinacholingana';

  @override
  String get clients_additionalDetails => 'Maelezo ya Ziada';

  @override
  String get clients_practiceType => 'Aina ya Kazi';

  @override
  String get clients_businessName => 'Jina la Biashara';

  @override
  String get clients_businessNameHint => 'Weka jina la biashara';

  @override
  String get clients_update => 'Sasisha Mteja';

  @override
  String get clients_save => 'Hifadhi Mteja';

  @override
  String get common_tryAgainLower => 'Jaribu tena';

  @override
  String get common_restore => 'Rejesha';

  @override
  String get common_noFacilityDot => 'Hakuna kituo kilichochaguliwa.';

  @override
  String get team_working => 'Inashughulikia...';

  @override
  String team_actionDone(String name, String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'approved': '$name ameidhinishwa',
      'rejected': '$name amekataliwa',
      'deactivated': '$name amesimamishwa',
      'reactivated': '$name amerejeshwa',
      'other': '$name $action',
    });
    return '$_temp0';
  }

  @override
  String get team_updateFailed => 'Imeshindwa kusasisha msaidizi';

  @override
  String get team_removed => 'Msaidizi ameondolewa kwenye kituo hiki';

  @override
  String get team_removeFailed => 'Imeshindwa kumwondoa msaidizi';

  @override
  String get team_signInSwitchFailed =>
      'Msaidizi amesimamishwa, lakini kuingia kwake hakukuweza kuzimwa. Mrejeshe kisha umsimamishe tena.';

  @override
  String get team_reassigned => 'Msaidizi amehamishwa';

  @override
  String get team_reassignFailed => 'Imeshindwa kumhamisha msaidizi';

  @override
  String get team_thisAssistant => 'msaidizi huyu';

  @override
  String get team_thisAssistantCap => 'Msaidizi huyu';

  @override
  String get team_thisPerson => 'mtu huyu';

  @override
  String get team_thisCoAdmin => 'msimamizi mwenza huyu';

  @override
  String team_moveTitle(String name) {
    return 'Mhamishe $name';
  }

  @override
  String get team_moveBody =>
      'Chagua kituo atakachofanyia kazi. Akaunti yake na idhini yake vinabaki.';

  @override
  String get team_noOtherFacility => 'Huna kituo kingine cha kumhamishia.';

  @override
  String get team_inviteTo => 'Mwalike Msaidizi Kwenye...';

  @override
  String get team_unknownFacility => 'Kituo kisichojulikana';

  @override
  String get team_you => 'Wewe';

  @override
  String get team_facilityAdmin => 'Msimamizi wa kituo';

  @override
  String get team_approve => 'Idhinisha';

  @override
  String get team_reject => 'Kataa';

  @override
  String get team_deactivate => 'Simamisha';

  @override
  String get team_reactivate => 'Rejesha';

  @override
  String get team_reassign => 'Hamisha';

  @override
  String get team_removeFromFacility => 'Ondoa Kwenye Kituo';

  @override
  String get team_removeFromFacilityConfirm => 'Ondoa kwenye kituo';

  @override
  String team_deactivateTitle(String name) {
    return 'Msimamishe $name?';
  }

  @override
  String get team_deactivateBody =>
      'Atatolewa mara moja na hataweza kuingia hadi umrejeshe. Hii haibadilishi nafasi yake - ni msimamizi wa jukwaa pekee anayeweza kufanya hivyo.';

  @override
  String get team_updateStatusFailed => 'Imeshindwa kusasisha hali';

  @override
  String team_facilityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vituo $count',
    );
    return '$_temp0';
  }

  @override
  String team_removeTitle(String name, String facility) {
    return 'Mwondoe $name kwenye $facility?';
  }

  @override
  String team_removePoint1(String name, String facility) {
    return '$name hatakuwa tena sehemu ya $facility, na hataona kumbukumbu zake.';
  }

  @override
  String team_removePoint2(String name, String facility) {
    return 'Alichorekodi $name kinabaki kwenye historia ya $facility.';
  }

  @override
  String get team_removePoint3 =>
      'Akaunti yake inabaki. Akiingia tena anaweza kuweka msimbo wa mwaliko ili ajiunge na kituo tena.';

  @override
  String team_rejectTitle(String name) {
    return 'Mkatae $name?';
  }

  @override
  String team_rejectPoint1(String name, String facility) {
    return '$name ameondolewa kwenye $facility na hasubiri tena idhini.';
  }

  @override
  String get team_rejectPoint2 =>
      'Akiingia tena ataona ombi halikuidhinishwa, na ataombwa msimbo wa mwaliko - anaweza kujiunga tena kwa msimbo mpya.';

  @override
  String get team_rejectPoint3 =>
      'Hatumiwi ujumbe. Mwambie mwenyewe ukipenda ajue.';

  @override
  String get team_title => 'Wafanyakazi';

  @override
  String get team_subtitle => 'Simamia ruhusa na hali ya wafanyakazi wako';

  @override
  String get team_inviteAssistant => 'Mwalike Msaidizi';

  @override
  String get team_noAdmin => 'Hakuna msimamizi aliyeingia';

  @override
  String get team_noFacilities =>
      'Hakuna vituo vilivyopatikana kwa akaunti yako.';

  @override
  String get team_acrossFacilities => 'Katika vituo vyako';

  @override
  String get team_haveAccess => 'Wana ruhusa';

  @override
  String get team_accessPaused => 'Ruhusa imesimamishwa';

  @override
  String get team_waitingApproval => 'Wanasubiri Idhini';

  @override
  String get team_needDecision => 'Wanahitaji uamuzi wako';

  @override
  String get team_searchHint => 'Tafuta kwa jina, simu au kituo...';

  @override
  String get team_emptyTitle => 'Bado hakuna wafanyakazi';

  @override
  String get team_emptyHint =>
      'Tumia Mwalike Msaidizi kuongeza mfanyakazi wako wa kwanza.';

  @override
  String get team_noAssistants => 'Bado hakuna wasaidizi';

  @override
  String get team_noMatches =>
      'Hakuna wafanyakazi wanaolingana na vichujio vyako';

  @override
  String get team_colUserName => 'Jina la mtumiaji';

  @override
  String get team_colRole => 'Nafasi';

  @override
  String get team_notRecorded => 'Haijarekodiwa';

  @override
  String get team_registered => 'Amejisajili';

  @override
  String get team_detailsTitle => 'Maelezo ya Mfanyakazi';

  @override
  String team_nameYou(String name) {
    return '$name  (wewe)';
  }

  @override
  String get team_joined => 'Alijiunga';

  @override
  String team_askedAgain(String date) {
    return 'Aliomba kujiunga tena: $date';
  }

  @override
  String get team_approvedLabel => 'Aliidhinishwa';

  @override
  String get team_waitingForApproval => 'Anasubiri idhini';

  @override
  String team_byName(String name) {
    return 'na $name';
  }

  @override
  String get team_approvedBeforeRecords =>
      'Aliidhinishwa kabla idhini hazijaanza kurekodiwa';

  @override
  String get team_lastStatusChange => 'Mabadiliko ya mwisho ya hali';

  @override
  String team_byNameRole(String name, String role) {
    return 'na $name ($role)';
  }

  @override
  String get team_lastActive => 'Mara ya mwisho kuonekana';

  @override
  String get team_history => 'Historia';

  @override
  String team_historyLine(String when, String name) {
    return '$when  ·  na $name';
  }

  @override
  String get team_useCardButtons =>
      'Tumia vitufe kwenye kadi ya mtu huyu kumwidhinisha, kumkataa au kumwondoa.';

  @override
  String get team_noAssistantsPage => 'Hakuna wasaidizi';

  @override
  String team_showingRange(int start, int end, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya wasaidizi $total',
      one: 'Inaonyesha $start hadi $end kati ya msaidizi 1',
    );
    return '$_temp0';
  }

  @override
  String get invite_checking => 'Inakagua kama kuna mwaliko uliopo...';

  @override
  String invite_checkFailed(String error) {
    return 'Imeshindwa kukagua mwaliko uliopo: $error';
  }

  @override
  String get invite_generating => 'Inatengeneza msimbo wako wa mwaliko...';

  @override
  String invite_generateFailed(String error) {
    return 'Imeshindwa kutengeneza mwaliko: $error';
  }

  @override
  String get invite_revoking => 'Inafuta msimbo...';

  @override
  String invite_revokeFailed(String error) {
    return 'Imeshindwa kufuta: $error';
  }

  @override
  String get invite_shareHint =>
      'Mpe mtu unayemwajiri msimbo huu - ataiweka anapojisajili kama Msaidizi.';

  @override
  String invite_expires(String date) {
    return 'Unaisha $date';
  }

  @override
  String get invite_copied => 'Imenakiliwa';

  @override
  String get invite_revoke => 'Futa';

  @override
  String get invite_generateNew => 'Tengeneza mpya badala yake';

  @override
  String get invite_generateHint =>
      'Tengeneza msimbo wa mara moja kwa mtu unayemwajiri - unafanya kazi kwa saa 48 au hadi utumike mara moja, kinachotangulia.';

  @override
  String get invite_generate => 'Tengeneza Msimbo wa Mwaliko';

  @override
  String get settings_title => 'Mipangilio';

  @override
  String get settings_subscriptionBilling => 'Usajili na Malipo';

  @override
  String get settings_accountData => 'Akaunti na Data';

  @override
  String get settings_exportData => 'Hamisha Data';

  @override
  String get hours_title => 'Saa za Biashara';

  @override
  String get account_title => 'Simamia Akaunti';

  @override
  String get settings_general => 'Jumla';

  @override
  String get printer_title => 'Mipangilio ya Printa na Risiti';

  @override
  String get settings_helpSupport => 'Msaada';

  @override
  String get settings_appInfo => 'Kuhusu Programu';

  @override
  String get settings_preferences => 'Mapendeleo';

  @override
  String get uiSettings_title => 'Mipangilio ya Mwonekano';

  @override
  String get settings_themeLayout => 'Rangi na mpangilio';

  @override
  String get settings_currency => 'Sarafu';

  @override
  String get settings_languageBoth => 'Language / Lugha';

  @override
  String get settings_selectLanguageBoth => 'SELECT LANGUAGE / CHAGUA LUGHA';

  @override
  String settings_versionLine(String appName, String version) {
    return '$appName - v$version';
  }

  @override
  String get settings_selectPane => 'Chagua mpangilio upande wa kushoto';

  @override
  String get settings_appName => 'Jina la Programu';

  @override
  String get settings_version => 'Toleo';

  @override
  String get settings_builtFor => 'Imetengenezwa Kwa';

  @override
  String get settings_builtForValue =>
      'Usimamizi wa biashara za mifugo na pembejeo za kilimo';

  @override
  String get uiSettings_colourTheme => 'RANGI';

  @override
  String get uiSettings_appearance => 'MWONEKANO';

  @override
  String get uiSettings_darkMode => 'Hali ya Giza';

  @override
  String get uiSettings_themeModeSystem => 'Kama Kifaa';

  @override
  String get uiSettings_themeModeLight => 'Mwanga';

  @override
  String get uiSettings_themeModeDark => 'Giza';

  @override
  String get uiSettings_layout => 'MPANGILIO';

  @override
  String get uiSettings_layoutFixed => 'Mpangilio Usiobadilika';

  @override
  String get uiSettings_layoutFixedHint =>
      'Huacha menyu ya pembeni wazi na huficha kitufe cha kuifunga kwenye skrini kubwa.';

  @override
  String get uiSettings_system => 'MFUMO';

  @override
  String get uiSettings_systemRefresh => 'Onyesha Upya Mfumo';

  @override
  String get uiSettings_systemRefreshHint =>
      'Hupakia upya data yako yote. Unabaki umeingia.';

  @override
  String get uiSettings_savedOnDevice => 'Imehifadhiwa kwenye kifaa hiki';

  @override
  String get uiSettings_refreshTitle => 'Onyesha upya programu?';

  @override
  String get uiSettings_refreshBody =>
      'Hii hupakia data yako upya na kukurudisha mwanzo. Unabaki umeingia, lakini chochote ambacho hujahifadhi kitapotea.';

  @override
  String get uiSettings_refreshDone => 'Data yako imesasishwa.';

  @override
  String get uiSettings_refreshFailed =>
      'Imeshindikana kuonyesha upya data yako.';

  @override
  String get uiSettings_themePasture => 'Malisho';

  @override
  String get uiSettings_themeClinic => 'Kliniki';

  @override
  String get uiSettings_themeHarvest => 'Mavuno';

  @override
  String get uiSettings_themeLedger => 'Daftari';

  @override
  String get hours_saved => 'Saa za biashara zimehifadhiwa';

  @override
  String get hours_saveFailed => 'Imeshindwa kuhifadhi saa za biashara';

  @override
  String get hours_intro =>
      'Huweka wakati kitufe cha \"Generate Today\'s Report\" kinapoanza kufanya kazi kwenye View Reports.';

  @override
  String get hours_weekdays => 'Siku za kazi (Jtatu–Ijumaa)';

  @override
  String get hours_saturday => 'Jumamosi';

  @override
  String get hours_sunday => 'Jumapili';

  @override
  String get hours_allowAnytime => 'Ruhusu wakati wowote';

  @override
  String get hours_allowAnytimeHint =>
      'Ruhusa ya dharura - huwezesha kitufe cha ripoti bila kujali ratiba hapo juu. Iwashe mnapofunga mapema, na uizime mambo yakirudi kawaida.';

  @override
  String get hours_save => 'Hifadhi Saa za Biashara';

  @override
  String get hours_closedAllDay => 'Imefungwa siku nzima';

  @override
  String hours_closesAt(String time) {
    return 'Inafungwa saa $time';
  }

  @override
  String get hours_noClosingTime =>
      'Hakuna muda wa kufunga unaohitajika - imefungwa siku nzima.';

  @override
  String get profile_logoUpdated => 'Nembo imesasishwa';

  @override
  String get profile_logoFailed => 'Imeshindwa kusasisha nembo';

  @override
  String get profile_yourFacility => 'Kituo chako';

  @override
  String get profile_title => 'Wasifu wa Biashara';

  @override
  String get profile_logoHint =>
      'Nembo hii inaonekana kwenye dashibodi, risiti, na popote kituo chako kinapoonyeshwa ndani ya programu.';

  @override
  String get profile_changeLogo => 'Badilisha Nembo';

  @override
  String get profile_uploadLogo => 'Pakia Nembo';

  @override
  String get searchIndex_title => 'Jenga Upya Faharasa ya Kutafuta Wateja';

  @override
  String get searchIndex_body =>
      'Hii huwafanya wateja walioongezwa kabla utafutaji haujakuwepo waonekane vizuri wanapotafutwa kwa jina, na huiwezesha programu kumtambua mteja mpya ambaye namba ya simu au jina lake linalingana na mteja uliye naye. Inahitaji kuendeshwa mara moja tu - wateja ambao tayari wako sawa hawaguswi.';

  @override
  String get searchIndex_nothing =>
      'Hakuna cha kusasisha - kila mteja tayari anatafutika.';

  @override
  String searchIndex_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imekamilika. Wateja $count wamesasishwa na sasa wanatafutika.',
      one: 'Imekamilika. Mteja 1 amesasishwa na sasa anatafutika.',
    );
    return '$_temp0';
  }

  @override
  String searchIndex_failed(String error) {
    return 'Imeshindwa kukamilisha: $error';
  }

  @override
  String get searchIndex_run => 'Endesha Sasa';

  @override
  String get printer_unavailableConnect =>
      'Uchapishaji kwa Bluetooth haupatikani kwenye jukwaa hili. Skrini hii inahitaji programu halisi ya Android au iOS yenye Bluetooth - haiwezi kuunganisha printa kutoka kwenye kivinjari.';

  @override
  String get printer_unavailableList =>
      'Uchapishaji kwa Bluetooth haupatikani kwenye jukwaa hili. Skrini hii inahitaji programu halisi ya Android au iOS yenye Bluetooth - haiwezi kuonyesha vifaa vilivyounganishwa kutoka kwenye kivinjari.';

  @override
  String printer_connected(String name) {
    return 'Imeunganishwa na $name';
  }

  @override
  String printer_connectFailedNamed(String name) {
    return 'Imeshindwa kuunganisha na $name';
  }

  @override
  String get printer_connectFailed => 'Imeshindwa kuunganisha printa';

  @override
  String get printer_disconnectFailed => 'Imeshindwa kutenganisha printa';

  @override
  String get printer_testSent => 'Ukurasa wa majaribio umetumwa kwa printa';

  @override
  String get printer_testFailed => 'Imeshindwa kuchapisha ukurasa wa majaribio';

  @override
  String get printer_savedPrinter => 'Printa iliyohifadhiwa';

  @override
  String get printer_statusConnected => 'Imeunganishwa';

  @override
  String get printer_statusNotConnected => 'Haijaunganishwa';

  @override
  String get printer_disconnect => 'Tenganisha';

  @override
  String get printer_forget => 'Sahau printa hii';

  @override
  String get printer_paired => 'Vifaa Vilivyounganishwa';

  @override
  String get printer_pairHint =>
      'Unganisha printa yako kwenye mipangilio ya Bluetooth ya kifaa chako kwanza - orodha hii inaonyesha tu vifaa vilivyokwisha unganishwa huko.';

  @override
  String get printer_noPaired =>
      'Hakuna vifaa vilivyounganishwa vilivyopatikana.';

  @override
  String get printer_connect => 'Unganisha';

  @override
  String get printer_printOptions => 'Chaguo za Kuchapisha';

  @override
  String get printer_paperSize => 'Ukubwa wa Karatasi';

  @override
  String printer_paperWidth(String width) {
    return '${width}mm';
  }

  @override
  String get printer_autoPrint =>
      'Chapisha risiti kiotomatiki baada ya kila mauzo';

  @override
  String get printer_sending => 'Inatuma...';

  @override
  String get printer_sendTest => 'Tuma Jaribio la Kuchapisha';

  @override
  String get printer_connectFirst =>
      'Unganisha printa hapo juu kabla ya kujaribu.';

  @override
  String get common_serviceRecords => 'Rekodi za Huduma';

  @override
  String get trash_restored => 'Kipengee kimerejeshwa';

  @override
  String get trash_restoreFailed => 'Imeshindwa kurejesha kipengee';

  @override
  String get trash_deleteForeverTitle => 'Futa Kabisa?';

  @override
  String trash_deleteForeverBody(String label) {
    return '\"$label\" itafutwa kabisa. Hili haliwezi kutenduliwa.';
  }

  @override
  String get trash_deleteForever => 'Futa Kabisa';

  @override
  String get trash_deleted => 'Imefutwa kabisa';

  @override
  String get trash_deleteFailed => 'Imeshindwa kufuta kipengee kabisa';

  @override
  String get trash_empty => 'Takataka ni tupu';

  @override
  String trash_expiringBanner(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vipengee $count vitafutwa kabisa ndani ya siku $days. Virejeshe sasa ikiwa bado unavihitaji.',
      one:
          'Kipengee 1 kitafutwa kabisa ndani ya siku $days. Kirejeshe sasa ikiwa bado unakihitaji.',
    );
    return '$_temp0';
  }

  @override
  String get trash_deletingSoon => 'Kinafutwa hivi karibuni';

  @override
  String get trash_expiresTomorrow => 'Kinaisha kesho';

  @override
  String trash_expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kinaisha baada ya siku $count',
      one: 'Kinaisha baada ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String trash_deletedBy(String name) {
    return 'Kimefutwa na $name';
  }

  @override
  String trash_deletedByOn(String name, String date) {
    return 'Kimefutwa na $name tarehe $date';
  }

  @override
  String get export_title => 'Kituo cha Kuhamisha Data';

  @override
  String get export_step1 => '1. Chagua Aina ya Data';

  @override
  String get export_step2 => '2. Kipindi na Tarehe';

  @override
  String get export_step3 => '3. Muundo wa Faili';

  @override
  String get export_salesTransactions => 'Mauzo na Miamala';

  @override
  String get export_salesTransactionsHint =>
      'Mauzo (pamoja na yaliyohifadhiwa) na historia ya miamala';

  @override
  String get export_serviceRecordsHint =>
      'Huduma zilizotolewa (pamoja na zilizohifadhiwa), kwa mteja na kundi';

  @override
  String get export_productCatalog => 'Orodha ya Bidhaa na Akiba';

  @override
  String get export_productCatalogHint =>
      'Viwango vya akiba vya sasa, gharama, na orodha ya bidhaa';

  @override
  String get export_clientDirectory => 'Orodha ya Wateja na Salio';

  @override
  String get export_clientDirectoryHint =>
      'Mawasiliano ya wateja na salio wanalodaiwa sasa';

  @override
  String get export_debtors => 'Wadaiwa / Salio Linalodaiwa';

  @override
  String get export_debtorsHint => 'Orodha ya kila kinachodaiwa sasa';

  @override
  String get export_paymentsLedger => 'Daftari la Malipo';

  @override
  String get export_paymentsLedgerHint =>
      'Kila malipo yaliyopokelewa - mauzo, huduma, madeni, mapato mengine';

  @override
  String get export_activityLog => 'Kumbukumbu za Shughuli';

  @override
  String get export_activityLogHint => 'Nani alifanya nini, na lini';

  @override
  String export_done(String dataset) {
    return '$dataset imehamishwa';
  }

  @override
  String export_failed(String dataset) {
    return 'Imeshindwa kuhamisha $dataset';
  }

  @override
  String get export_selectStart => 'Chagua Tarehe ya Kuanza';

  @override
  String get export_selectEnd => 'Chagua Tarehe ya Mwisho';

  @override
  String get export_dateRange => 'Kipindi';

  @override
  String get export_last7 => 'Siku 7 Zilizopita';

  @override
  String get export_last30 => 'Siku 30 Zilizopita';

  @override
  String get export_lastMonth => 'Mwezi Uliopita';

  @override
  String get export_thisYear => 'Mwaka Huu';

  @override
  String get export_allTime => 'Muda Wote';

  @override
  String get export_customRange => 'Chagua Tarehe...';

  @override
  String get export_notApplicable => 'Haihusiki - hii ni hali ya sasa';

  @override
  String get export_pickRange => 'Tafadhali chagua kipindi hapa chini';

  @override
  String get export_allRecords => 'Rekodi Zote (Bila Vichujio)';

  @override
  String export_rangeLine(String start, String end) {
    return '$start  hadi  $end';
  }

  @override
  String get export_scope => 'Kipindi Kilichochaguliwa';

  @override
  String get export_modify => 'Badilisha';

  @override
  String get export_xlsx => 'Faili la Excel (.xlsx)';

  @override
  String get export_xlsxHint =>
      'Vichwa vilivyokolezwa, kurasa kadhaa, tarehe halisi - linafunguka vizuri, tayari kuhifadhiwa';

  @override
  String get export_csv => 'CSV (Maandishi Matupu)';

  @override
  String get export_csvHint =>
      'Maandishi rahisi ya kawaida - yanafunguka kwenye Excel, Sheets, au kihariri chochote';

  @override
  String get export_pickRangeFirst =>
      'Chagua kipindi hapo juu kabla ya kuhamisha.';

  @override
  String get export_pickRangeWarning => 'Chagua kipindi kabla ya kuhamisha';

  @override
  String get export_generate => 'Tengeneza na Hamisha Data';

  @override
  String get account_logoutAllTitle => 'Toka Kwenye Vifaa Vyote?';

  @override
  String get account_logoutAllBody =>
      'Hii itafuta vipindi vilivyo hai na kukutoa kwenye simu, tableti au kompyuta nyingine zote zilizoingia kwenye akaunti yako.';

  @override
  String get account_logoutEverywhere => 'Toka Kila Mahali';

  @override
  String get account_logoutAllFailed => 'Imeshindwa kufuta vipindi vingine';

  @override
  String get account_thisFacility => 'kituo hiki';

  @override
  String get account_wipeTitle => 'Futa Data Yote?';

  @override
  String account_wipeFacility(String facility) {
    return 'Data ya biashara ya \"$facility\" itafutwa kabisa.';
  }

  @override
  String get account_wipeBody =>
      'Rekodi zote za mauzo, bidhaa, wateja na miamala za kituo hiki zinafutwa. Vituo vyako vingine haviguswi. Taarifa zako za kuingia hazibadiliki.';

  @override
  String get account_wipe => 'Futa Data';

  @override
  String get account_confirmTitle => 'Thibitisha Kitendo';

  @override
  String account_typeErase(String word) {
    return 'Tafadhali andika \"$word\" ili kukamilisha kufuta rekodi zote:';
  }

  @override
  String get account_wiped => 'Data yote ya biashara imefutwa kabisa';

  @override
  String get account_wipeFailed => 'Imeshindwa kufuta rekodi';

  @override
  String get account_cannotDeactivateTitle => 'Haiwezi Kusimamishwa';

  @override
  String get account_cannotDeactivateBody =>
      'Akaunti hii ina ruhusa ya Msimamizi wa Jukwaa, kwa hiyo haiwezi kusimamishwa - si na wewe, wala na mtu mwingine. Hii inazuia jukwaa kufungiwa nje ya zana zake za usimamizi.';

  @override
  String get account_deactivateTitle => 'Simamisha Akaunti';

  @override
  String get account_deactivateBody =>
      'Una uhakika unataka kusimamisha akaunti yako? Utatolewa mara moja, na utahitaji msimamizi wa kituo chako (au Msimamizi wa Jukwaa) kuirejesha kabla hujaingia tena.';

  @override
  String get account_confirmDeactivation => 'Thibitisha Kusimamisha';

  @override
  String account_typeToConfirm(String word) {
    return 'Andika \"$word\" kuthibitisha:';
  }

  @override
  String get account_deactivated => 'Akaunti yako imesimamishwa.';

  @override
  String get account_deactivateFailed => 'Imeshindwa kusimamisha akaunti';

  @override
  String get account_deleteTitle => 'Futa Akaunti';

  @override
  String get account_deleteWarning =>
      'Kufuta akaunti yako ni kwa kudumu na hakuwezi kutenduliwa. Data yako yote itafutwa.';

  @override
  String get account_deleted => 'Akaunti yako imefutwa';

  @override
  String get account_deleteFailed => 'Imeshindwa kufuta akaunti';

  @override
  String get account_checking => 'Inakagua...';

  @override
  String get account_platformAdminNoDelete =>
      'Akaunti za Msimamizi wa Jukwaa haziwezi kufutwa hapa.';

  @override
  String get account_deleteOwnedFirst =>
      'Futa kwanza vituo vyote unavyomiliki kwenye View Facilities.';

  @override
  String get account_deleteHint =>
      'Futa akaunti yako kabisa. Kitendo hiki hakiwezi kutenduliwa.';

  @override
  String get account_dangerZone => 'Eneo la Hatari';

  @override
  String get account_dangerHint =>
      'Vitendo hivi vinaathiri akaunti yako na data ya biashara. Kagua kwa makini kabla ya kuendelea.';

  @override
  String get account_logoutAll => 'Toka Kwenye Vifaa Vyote';

  @override
  String get account_logoutAllHint =>
      'Tenganisha kipindi chako kutoka kwenye vifaa vingine vyote.';

  @override
  String get account_wipeAll => 'Futa Data Yote ya Biashara';

  @override
  String get account_wipeInProgress =>
      'Inafuta - tafadhali subiri, hii inaweza kuchukua muda...';

  @override
  String get account_wipeHint =>
      'Futa kabisa rekodi za miamala, mauzo na bidhaa huku ukibaki na wasifu wako wa kuingia.';

  @override
  String get account_deactivateHint =>
      'Zima akaunti yako kwa muda. Inaweza kurejeshwa baadaye.';

  @override
  String get common_walkIn => 'Mteja wa papo hapo';

  @override
  String services_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Huduma $count mpya zipo',
      one: 'Huduma 1 mpya ipo',
    );
    return '$_temp0';
  }

  @override
  String get services_empty => 'Bado hakuna huduma';

  @override
  String get services_emptyFiltered =>
      'Hakuna huduma zinazolingana na vichujio vyako';

  @override
  String get services_totalServices => 'Jumla ya Huduma';

  @override
  String get services_paidAmount => 'Kiasi Kilicholipwa';

  @override
  String get services_digitalPayments => 'Malipo ya Kidijitali';

  @override
  String get services_last30 => 'Siku 30 zilizopita';

  @override
  String get services_last7 => 'Siku 7 zilizopita';

  @override
  String get services_thisMonth => 'Mwezi huu';

  @override
  String get services_subtitle => 'Fuatilia huduma zote ulizowapa wateja wako';

  @override
  String get services_recordVisit => 'Rekodi Ziara';

  @override
  String get services_archive => 'Kumbukumbu';

  @override
  String get services_searchHint => 'Tafuta huduma kwa mteja, aina, maelezo...';

  @override
  String get services_colServiceCategory => 'Huduma / Aina';

  @override
  String get services_colProvider => 'Mtoa Huduma';

  @override
  String get services_none => 'Hakuna huduma';

  @override
  String get services_movedToTrash => 'Huduma imehamishiwa Tupio';

  @override
  String get services_deleteFailed => 'Imeshindikana kufuta huduma';

  @override
  String get services_detailsTitle => 'Maelezo ya Huduma';

  @override
  String get services_paymentInfo => 'Taarifa za Malipo';

  @override
  String get services_transactionId => 'Namba ya Muamala';

  @override
  String get services_paidOn => 'Imelipwa Tarehe';

  @override
  String get services_providedBy => 'Imetolewa Na';

  @override
  String get services_serviceDate => 'Tarehe ya Huduma';

  @override
  String get services_createdOn => 'Imeundwa Tarehe';

  @override
  String get services_fallbackName => 'Huduma';

  @override
  String get services_archiveTitle => 'Kumbukumbu za Huduma';

  @override
  String services_archiveSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Huduma huhifadhiwa kwenye kumbukumbu baada ya siku $days',
      one: 'Huduma huhifadhiwa kwenye kumbukumbu baada ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String get services_archiveEmpty =>
      'Hakuna huduma zilizohifadhiwa zilizopatikana';

  @override
  String get services_archiveEmptyHint =>
      'Jaribu utafutaji, aina au kipindi kingine';

  @override
  String services_archivePeriod(String start, String end) {
    return 'Kipindi: $start – $end';
  }

  @override
  String get services_archivedServices => 'Huduma zilizohifadhiwa';

  @override
  String services_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zimepatikana',
      one: '1 imepatikana',
    );
    return '$_temp0';
  }

  @override
  String services_archiveShowing(int start, int end, int total, String more) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya huduma $total$more',
      one: 'Inaonyesha $start hadi $end kati ya huduma 1$more',
    );
    return '$_temp0';
  }

  @override
  String services_pageOf(int page, int total) {
    return 'Ukurasa $page kati ya $total';
  }

  @override
  String services_notesValue(String notes) {
    return 'Maelezo: $notes';
  }

  @override
  String get services_searchArchiveTitle => 'Tafuta Huduma Zilizohifadhiwa';

  @override
  String get services_searchBy => 'Tafuta Kwa:';

  @override
  String get services_specificMonth => 'Mwezi Maalum';

  @override
  String services_archiveCutoffNote(String date) {
    return 'Huduma za kabla ya $date pekee ndizo zimefika kwenye kumbukumbu.';
  }

  @override
  String get services_selectMonth => 'Chagua Mwezi:';

  @override
  String get services_editVisit => 'Hariri Ziara';

  @override
  String get services_selectClientRequired => 'Chagua Mteja *';

  @override
  String get services_clientSearchHint => 'Tafuta au chagua mteja...';

  @override
  String get services_errSelectClient => 'Tafadhali chagua mteja';

  @override
  String get services_addNewClient => 'Ongeza Mteja Mpya';

  @override
  String get services_visitDetails => 'Maelezo ya Ziara';

  @override
  String get services_serviceName => 'Jina la Huduma';

  @override
  String get services_errServiceName => 'Weka jina la huduma';

  @override
  String get services_errProvider => 'Weka mtoa huduma';

  @override
  String get services_itemsUsed => 'Gharama (Vitu Vilivyotumika)';

  @override
  String get services_addItem => 'Ongeza Kitu';

  @override
  String get services_itemName => 'Jina la Kitu';

  @override
  String get services_errItemName => 'Weka jina';

  @override
  String get services_noMatchingProduct =>
      'Hakuna bidhaa inayolingana - itarekodiwa kama gharama ya kawaida.';

  @override
  String services_sellableQty(String quantity, String unit) {
    return 'Inauzika: $quantity $unit';
  }

  @override
  String get services_inStockDeduct =>
      'Ipo stoo - itapunguzwa, hakuna gharama itakayorekodiwa';

  @override
  String get services_errPrice => 'Weka bei';

  @override
  String services_totalItemsCost(String amount) {
    return 'Jumla ya Gharama za Vitu: $amount';
  }

  @override
  String get services_visitSummary => 'Muhtasari wa Ziara';

  @override
  String services_totalAmountRequired(String currency) {
    return 'Jumla ya Kiasi ($currency) *';
  }

  @override
  String get services_errTotalAmount => 'Weka jumla ya kiasi';

  @override
  String services_totalPaidRequired(String currency) {
    return 'Jumla Iliyolipwa ($currency) *';
  }

  @override
  String get services_errPaidAmount => 'Weka kiasi kilicholipwa';

  @override
  String get services_transactionIdOptional => 'Namba ya Muamala (si lazima)';

  @override
  String get services_errPaidOverTotal =>
      'Jumla iliyolipwa haiwezi kuzidi jumla ya kiasi';

  @override
  String get services_updated => 'Huduma imesasishwa';

  @override
  String get services_added => 'Huduma imeongezwa';

  @override
  String get services_saveFailed => 'Imeshindikana kuhifadhi huduma';

  @override
  String get services_updateVisit => 'Sasisha Ziara';

  @override
  String get services_noClientFound => 'Hakuna mteja aliyepatikana';

  @override
  String get receipt_shareFailed => 'Imeshindikana kushiriki risiti';

  @override
  String get receipt_pdfFailed => 'Imeshindikana kutengeneza PDF';

  @override
  String get receipt_previewTitle => 'Hakiki ya Risiti';

  @override
  String get receipt_formatThermal => 'Risiti (Thermal)';

  @override
  String get receipt_formatA4 => 'Muundo wa A4';

  @override
  String get receipt_shareSave => 'Shiriki / Hifadhi';

  @override
  String get receipt_details => 'Maelezo ya Risiti';

  @override
  String get receipt_number => 'Namba ya Risiti';

  @override
  String get receipt_customer => 'Mteja';

  @override
  String get receipt_quickActions => 'Vitendo vya Haraka';

  @override
  String get receipt_infoNote =>
      'Risiti hii inaonyesha kiasi cha mwisho kilicholipwa kwa muamala uliochaguliwa. Unaweza kuichapisha au kuishiriki kwa kumbukumbu zako.';

  @override
  String get receipt_statusPartiallyPaid => 'Imelipwa Sehemu';

  @override
  String get receipt_statusBalanceDue => 'Salio Linadaiwa';

  @override
  String get receipt_statusPaidInFull => 'Imelipwa Yote';

  @override
  String get common_notApplicable => 'Haipo';

  @override
  String get reports_thisYear => 'Mwaka huu';

  @override
  String get reports_pastTitle => 'Ripoti Zilizopita';

  @override
  String get reports_pastSubtitle =>
      'Kila ripoti ya kufunga siku ya kituo hiki';

  @override
  String get reports_noneYet => 'Bado hakuna ripoti iliyotengenezwa.';

  @override
  String get reports_noMatch =>
      'Hakuna ripoti zinazolingana na utafutaji wako.';

  @override
  String get reports_loadMore => 'Pakia zaidi';

  @override
  String get reports_searchHint => 'Tafuta ripoti...';

  @override
  String get reports_generatedCount => 'Ripoti zilizotengenezwa';

  @override
  String get reports_loadedPeriod => 'Kipindi kilichopakiwa';

  @override
  String get reports_latest => 'Ya hivi karibuni';

  @override
  String reports_rowSummary(String amount, String name) {
    return 'Mapato ya jumla $amount - imetengenezwa na $name';
  }

  @override
  String get reports_notSubmitted => 'Haijawasilishwa';

  @override
  String get reports_completed => 'Imekamilika';

  @override
  String reports_submittedBy(String name) {
    return 'Imewasilishwa na $name';
  }

  @override
  String get reports_draftNotSubmitted => 'Rasimu - bado haijawasilishwa';

  @override
  String get reports_pdf => 'PDF';

  @override
  String get reports_fullReport => 'Ripoti Kamili';

  @override
  String get reports_dailyClosingReport => 'Ripoti ya Kufunga Siku';

  @override
  String get reports_dailySummary => 'Muhtasari wa Siku';

  @override
  String get reports_totalSales => 'Jumla ya Mauzo';

  @override
  String get reports_serviceRevenue => 'Mapato ya Huduma';

  @override
  String get reports_totalRevenue => 'Jumla ya Mapato';

  @override
  String get reports_newDebtToday => 'Deni Jipya Leo';

  @override
  String get reports_noSalesToday => 'Hakuna mauzo yaliyorekodiwa leo.';

  @override
  String get reports_vetServices => 'Huduma za Mifugo';

  @override
  String get reports_noServicesToday => 'Hakuna huduma zilizotolewa leo.';

  @override
  String get reports_productMovement => 'Mwenendo wa Bidhaa';

  @override
  String get reports_noMovementToday => 'Hakuna mwenendo wa bidhaa leo.';

  @override
  String reports_movementLine(int sold, int closing, String unit) {
    return 'Imeuzwa: $sold $unit  |  Kufunga: $closing $unit';
  }

  @override
  String reports_movementLineAdjusted(
    int sold,
    String adjustment,
    int closing,
    String unit,
  ) {
    return 'Imeuzwa: $sold $unit  |  Imerekebishwa: $adjustment $unit  |  Kufunga: $closing $unit';
  }

  @override
  String get reports_expectedVsPhysical => 'Stoo Inayotarajiwa dhidi ya Halisi';

  @override
  String get reports_noWatchlisted =>
      'Hakuna bidhaa zinazofuatiliwa kwa kituo hiki.';

  @override
  String get reports_countsNotSubmitted =>
      'Hesabu halisi bado hazijawasilishwa.';

  @override
  String reports_expectedPhysical(int expected, String physical) {
    return 'Inatarajiwa: $expected  |  Halisi: $physical';
  }

  @override
  String get reports_debtActivity => 'Mwenendo wa Madeni';

  @override
  String get reports_noDebtActivity => 'Hakuna mwenendo wa madeni leo.';

  @override
  String get reports_expensesRecorded => 'Gharama Zilizorekodiwa';

  @override
  String get reports_noExpensesToday => 'Hakuna gharama zilizorekodiwa leo.';

  @override
  String get reports_paymentReconciliation => 'Ulinganisho wa Malipo';

  @override
  String get reports_noPaymentsToday => 'Hakuna malipo yaliyorekodiwa leo.';

  @override
  String get reports_expectedBalance => 'Salio linalotarajiwa';

  @override
  String get reports_physicalBalance => 'Salio halisi lililohesabiwa';

  @override
  String get reports_variance => 'Tofauti';

  @override
  String reports_varianceValue(String amount) {
    return '$amount - TOFAUTI';
  }

  @override
  String reports_matchValue(String amount) {
    return '$amount - Inalingana';
  }

  @override
  String get reports_reason => 'Sababu';

  @override
  String reports_outflowOnly(String method) {
    return 'Hakuna mapato kupitia $method leo - matumizi tu, hakuna haja ya kuhesabu.';
  }

  @override
  String get reports_notYetSubmitted => 'Bado haijawasilishwa.';

  @override
  String get reports_paymentMethods => 'Njia za Malipo';

  @override
  String get reports_noSalesShort => 'Hakuna mauzo leo.';

  @override
  String get reports_noServicesShort => 'Hakuna huduma leo.';

  @override
  String get reports_noRepaymentsShort => 'Hakuna marejesho leo.';

  @override
  String get reports_noOtherIncomeShort => 'Hakuna mapato mengine leo.';

  @override
  String get reports_declaration => 'Tamko la Kufunga Siku';

  @override
  String get reports_declarationConfirmed =>
      'Imethibitishwa - Nimepitia miamala ya leo na kwamba takwimu za fedha na stoo zilizowekwa ni takwimu za kufunga zamu yangu.';

  @override
  String get reports_notConfirmed => 'Bado haijathibitishwa.';

  @override
  String get reports_submitFailed => 'Imeshindikana kuwasilisha ripoti';

  @override
  String get reports_reviewSubmit => 'Pitia na Uwasilishe';

  @override
  String get reports_reviewIntro =>
      'Mauzo, huduma, miamala na mwenendo wa madeni tayari vimekokotolewa. Hesabu vitu vilivyo hapa chini na uweke ulichokipata kabla ya kuwasilisha.';

  @override
  String get reports_physicalStockCount => 'Hesabu ya Stoo Halisi';

  @override
  String get reports_watchlistedHint =>
      'Bidhaa zinazofuatiliwa pekee - zihesabu kabla ya kuwasilisha.';

  @override
  String reports_expectedValue(int count) {
    return 'Inatarajiwa: $count';
  }

  @override
  String get reports_physicalCount => 'Hesabu halisi';

  @override
  String reports_varianceCount(String variance) {
    return 'Tofauti $variance';
  }

  @override
  String get reports_match => 'Inalingana';

  @override
  String get reports_varianceReasonHint =>
      'Sababu ya tofauti (mf. imeharibika, haipatikani)';

  @override
  String get reports_errVarianceReason => 'Tafadhali eleza sababu ya tofauti.';

  @override
  String get reports_countEachMethod =>
      'Hesabu ulicho nacho kwa kila njia iliyotumika leo - salio la pesa za simu, salio la benki na fedha taslimu kwenye droo.';

  @override
  String get reports_amountPaidOut => 'Kiasi kilicholipwa nje';

  @override
  String reports_noIncomeVia(String method) {
    return 'Hakuna mapato yaliyoingia kupitia $method leo - ni matumizi tu. Hakuna haja ya hesabu halisi hapa.';
  }

  @override
  String get reports_physicalBalanceRequired => 'Salio halisi lililohesabiwa *';

  @override
  String reports_methodVariance(String method, String amount) {
    return 'Tofauti ya $method: $amount';
  }

  @override
  String reports_methodVarianceReason(String method) {
    return 'Sababu ya tofauti ya $method';
  }

  @override
  String reports_methodMatches(String method) {
    return '$method inalingana';
  }

  @override
  String get reports_confirmDeclaration =>
      'Nathibitisha kwamba nimepitia miamala ya leo na kwamba takwimu za fedha na stoo zilizowekwa hapo juu ni takwimu za kufunga zamu yangu.';

  @override
  String get reports_blockedCounts =>
      'Weka hesabu halisi kwa kila bidhaa inayofuatiliwa';

  @override
  String get reports_blockedBalances =>
      'Weka salio halisi kwa kila njia ya malipo';

  @override
  String get reports_blockedReason =>
      'Tafadhali eleza sababu ya tofauti iliyopatikana';

  @override
  String get reports_blockedDeclaration =>
      'Thibitisha tamko la kufunga ili kuwasilisha';

  @override
  String get reports_submitDailyClosing => 'Wasilisha Kufunga Siku';

  @override
  String get reports_tabStock => 'Ulinganisho wa Stoo';

  @override
  String get reports_tabDebt => 'Deni';

  @override
  String get reports_tabProducts => 'Bidhaa';

  @override
  String get reports_outstandingNewDebt => 'Deni Jipya Linalodaiwa';

  @override
  String get reports_servicesPerformed => 'Huduma Zilizotolewa';

  @override
  String get reports_productsSold => 'Bidhaa Zilizouzwa';

  @override
  String reports_unitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vipimo $count',
      one: 'Kipimo 1',
    );
    return '$_temp0';
  }

  @override
  String get reports_totalRevenueToday => 'Jumla ya Mapato Leo';

  @override
  String reports_generatedAtBy(String time, String name) {
    return 'Imetengenezwa saa $time na $name';
  }

  @override
  String reports_submittedAt(String time) {
    return 'Imewasilishwa saa $time';
  }

  @override
  String reports_soldCount(int count) {
    return 'Imeuzwa: $count';
  }

  @override
  String get reports_colTime => 'Muda';

  @override
  String get reports_colReceipt => 'Risiti';

  @override
  String get reports_colItems => 'Vitu';

  @override
  String get reports_colPayment => 'Malipo';

  @override
  String get reports_colService => 'Huduma';

  @override
  String get reports_colNumber => 'Idadi';

  @override
  String get reports_colRevenue => 'Mapato';

  @override
  String get reports_totalServiceRevenue => 'Jumla ya Mapato ya Huduma';

  @override
  String get reports_colProduct => 'Bidhaa';

  @override
  String get reports_colUnit => 'Kipimo';

  @override
  String get reports_colOpening => 'Mwanzo';

  @override
  String get reports_colAdded => 'Imeongezwa';

  @override
  String get reports_colAdjusted => 'Imerekebishwa';

  @override
  String get reports_colSold => 'Imeuzwa';

  @override
  String get reports_colExpectedClosing => 'Kufunga Kunakotarajiwa';

  @override
  String get reports_totalUnitsSold => 'Jumla ya Vipimo Vilivyouzwa';

  @override
  String get reports_systemTracked =>
      'Inafuatiliwa na mfumo - bidhaa zenye mwenendo leo, au zinazofuatiliwa, ndizo zinaonyeshwa.';

  @override
  String get reports_watchlistedOnly => 'Bidhaa zinazofuatiliwa pekee.';

  @override
  String get reports_colExpected => 'Inatarajiwa';

  @override
  String get reports_colPhysical => 'Halisi';

  @override
  String get reports_colDifference => 'Tofauti';

  @override
  String reports_reasonValue(String reason) {
    return 'Sababu: $reason';
  }

  @override
  String get reports_newDebtTodayLower => 'Deni jipya leo';

  @override
  String get reports_repaymentsCollected => 'Marejesho yaliyokusanywa';

  @override
  String get reports_outstandingChange => 'Mabadiliko ya deni';

  @override
  String get reports_byCustomer => 'Kwa Mteja';

  @override
  String get reports_colNewDebt => 'Deni Jipya';

  @override
  String get reports_colRepayment => 'Marejesho';

  @override
  String get reports_colClosing => 'Kufunga';

  @override
  String get reports_totalExpenses => 'Jumla ya Gharama';

  @override
  String get reports_allTransactions => 'Miamala Yote';

  @override
  String get reports_transactionsNote =>
      'Mapato na gharama zilizorekodiwa moja kwa moja, tofauti na mapato ya mauzo na huduma.';

  @override
  String get reports_noTransactionsToday => 'Hakuna miamala iliyorekodiwa leo.';

  @override
  String get reports_everythingToday =>
      'Kila kitu kilichorekodiwa leo, kwa mpangilio.';

  @override
  String get reports_activityNotIncluded =>
      'Haijajumuishwa - rasimu hii ilitengenezwa na msaidizi, anayeona shughuli zake tu. Futa rasimu na uitengeneze tena upate kumbukumbu kamili.';

  @override
  String get reports_noActivityToday => 'Hakuna shughuli iliyorekodiwa leo.';

  @override
  String get reports_activityLogNotSaved =>
      'Hakuna kumbukumbu ya shughuli iliyohifadhiwa pamoja na ripoti hii.';

  @override
  String get reports_colBy => 'Na';

  @override
  String get reports_combinedAll => 'Kwa Pamoja - Njia Zote za Malipo';

  @override
  String get reports_combinedNote =>
      'Mauzo, huduma, marejesho ya madeni na mapato mengine kwa pamoja, kulingana na jinsi yalivyopokelewa.';

  @override
  String get reports_generateFailed => 'Imeshindikana kutengeneza ripoti';

  @override
  String get reports_deleteDraftTitle => 'Futa Rasimu?';

  @override
  String get reports_deleteDraftBody =>
      'Hii inafuta rasimu ya ripoti ya leo ili iweze kutengenezwa upya. Haiathiri mauzo, huduma au miamala yoyote - ni nakala hii ya kazi pekee.';

  @override
  String get reports_deleteDraft => 'Futa Rasimu';

  @override
  String get reports_deleteDraftFailed => 'Imeshindikana kufuta rasimu';

  @override
  String get reports_shareFailed => 'Imeshindikana kushiriki ripoti';

  @override
  String get reports_viewTitle => 'Tazama Ripoti';

  @override
  String get reports_viewSubtitle => 'Ripoti ya kufunga siku ya kituo hiki';

  @override
  String get reports_todaySubmitted => 'Ripoti ya Leo - Imewasilishwa';

  @override
  String get reports_continueClosing => 'Endelea Kufunga';

  @override
  String get reports_generateToday => 'Tengeneza Ripoti ya Leo';

  @override
  String get reports_generateClosedToday =>
      'Tengeneza Ripoti ya Leo (imefungwa leo)';

  @override
  String reports_generateAt(String time) {
    return 'Tengeneza Ripoti ya Leo (saa $time)';
  }

  @override
  String get reports_generateAfterClosing =>
      'Tengeneza Ripoti ya Leo (baada ya muda wa kufunga)';

  @override
  String get reports_tapGenerate =>
      'Gusa \"Tengeneza Ripoti ya Leo\" hapo juu kuanza.';

  @override
  String get reports_closedToday => 'Kituo hiki kimewekwa kuwa kimefungwa leo.';

  @override
  String reports_availableAt(String time) {
    return 'Inapatikana saa $time.';
  }

  @override
  String get reports_availableOnceClosing =>
      'Inapatikana muda wa kufunga wa leo ukifika.';

  @override
  String get reports_noneToday => 'Bado hakuna ripoti iliyotengenezwa leo';

  @override
  String get reports_todayHeading => 'Ripoti ya Kufunga Siku - Ripoti ya Leo';

  @override
  String get reports_viewFull => 'Tazama Ripoti Kamili';

  @override
  String get reports_viewFullHint => 'Ona sehemu zote kwa kina';

  @override
  String get reports_downloadPdf => 'Pakua PDF';

  @override
  String get reports_downloadPdfHint => 'Pata ripoti ya kuchapisha';

  @override
  String get reports_deleteDraftHint => 'Futa rasimu ya leo uanze upya';

  @override
  String get reports_shareWithAdmin => 'Shiriki na Msimamizi';

  @override
  String get reports_shareWithAdminHint => 'Tuma ripoti kwa msimamizi wako';

  @override
  String get reports_accountability => 'Uwajibikaji';

  @override
  String get reports_submittedByLabel => 'Imewasilishwa na';

  @override
  String get reports_declarationPending =>
      'Tamko hili huthibitishwa wakati wa Kuwasilisha Kufunga Siku, baada ya hesabu za stoo na fedha kuwekwa.';

  @override
  String get reports_savedNote =>
      'Ripoti itahifadhiwa kwenye mfumo na itapatikana kwako na kwa msimamizi kuitazama au kuipakua wakati wowote.';

  @override
  String get batch_mergedIntoExisting =>
      'Imeongezwa kwenye batch iliyopo yenye namba na tarehe hii ya kuisha';

  @override
  String get batch_added => 'Batch mpya imeongezwa';

  @override
  String get batch_addFailed => 'Imeshindikana kuongeza batch';

  @override
  String get batch_addIntro =>
      'Chagua mzigo huu uende wapi - unarekodiwa kama batch yake, tofauti na akiba iliyopo.';

  @override
  String get batch_batchNoOptional => 'Namba ya Batch (si lazima)';

  @override
  String get batch_expiryDate => 'Tarehe ya Kuisha';

  @override
  String get batch_addStockTo => 'Weka Bidhaa Hizi';

  @override
  String get batch_storeHint => 'Inahitaji hatua ya \"Toa\" kabla ya kuuzwa';

  @override
  String get batch_sellableOption => 'Za Kuuza (moja kwa moja rafuni)';

  @override
  String get batch_sellableHint => 'Tayari kuuzwa sasa hivi';

  @override
  String get batch_quantityReceived => 'Idadi Iliyopokelewa';

  @override
  String get batch_validQuantity => 'Weka idadi sahihi';

  @override
  String batch_buyPriceLabel(String currency) {
    return 'Bei ya Kununua ($currency)';
  }

  @override
  String get batch_addBatch => 'Ongeza Batch';

  @override
  String get batch_moveToStock => 'Rudisha Stoo';

  @override
  String get batch_removeFromSellable => 'Ondoa Kwenye za Kuuza';

  @override
  String batch_moveIntro(
    String product,
    String batchPart,
    String expiryPart,
    int quantity,
    String unit,
  ) {
    return '$product$batchPart$expiryPart. Hadi $quantity $unit zinaweza kurudi Stoo.';
  }

  @override
  String batch_moveBatchPart(String batchNo) {
    return ' - Batch $batchNo';
  }

  @override
  String batch_moveExpiredPart(String date) {
    return ' (iliisha $date)';
  }

  @override
  String batch_moveExpiresPart(String date) {
    return ' (inaisha $date)';
  }

  @override
  String batch_quantityToMove(String unit) {
    return 'Idadi ya kuhamisha ($unit)';
  }

  @override
  String get batch_noteRequiredOther => 'Maelezo (lazima kwa Nyingine)';

  @override
  String get batch_noteOptional => 'Maelezo (si lazima)';

  @override
  String batch_quantityUpTo(int max) {
    return 'Weka idadi isiyozidi $max';
  }

  @override
  String get batch_selectReason => 'Chagua sababu';

  @override
  String get batch_describeReason => 'Eleza sababu kwenye maelezo hapa chini';

  @override
  String batch_movedBack(int quantity, String unit) {
    return '$quantity $unit zimerudishwa Stoo';
  }

  @override
  String batch_removedFromSellable(int quantity, String unit) {
    return '$quantity $unit zimeondolewa kwenye za Kuuza';
  }

  @override
  String get batch_moveFailed => 'Imeshindikana kuhamisha bidhaa';

  @override
  String get batch_unlabeledTitle => 'Batch Isiyo na Namba';

  @override
  String batch_currently(int stock, int sellable) {
    return 'Sasa: $stock stoo · $sellable za kuuza';
  }

  @override
  String get batch_modeAdd => 'Ongeza juu yake';

  @override
  String get batch_modeSet => 'Rekebisha iwe';

  @override
  String get batch_modeAddHint =>
      'Inaongeza kiasi hiki juu ya kilichopo (mzigo wa nyongeza).';

  @override
  String get batch_modeSetHint =>
      'Inaweka kiasi kamili kilichopo sasa (kurekebisha hesabu iliyokosewa).';

  @override
  String get batch_addStoreQty => 'Ongeza Idadi ya Stoo';

  @override
  String get batch_setStoreQty => 'Rekebisha Idadi ya Stoo iwe';

  @override
  String get batch_addSellableQty => 'Ongeza Idadi ya Kuuza';

  @override
  String get batch_setSellableQty => 'Rekebisha Idadi ya Kuuza iwe';

  @override
  String batch_saveFailed(String error) {
    return 'Imeshindwa kuhifadhi: $error';
  }

  @override
  String get batch_deleteExpiredTitle => 'Futa Batch Iliyoisha Muda?';

  @override
  String get batch_deleteTitle => 'Futa Batch Hii?';

  @override
  String get batch_notExpiredWarning =>
      'Batch hii bado haijaisha muda - bado ina bidhaa nzuri za kuuza.';

  @override
  String batch_deleteBody(String batch, int stock, int sellable) {
    return 'Hii inaondoa $batch kabisa na kutoa vipimo vyake $stock vya stoo na $sellable vya kuuza kwenye jumla ya bidhaa hii. Haiwezi kurudishwa.';
  }

  @override
  String get batch_thisUnlabeled => 'batch hii isiyo na namba';

  @override
  String batch_deleteFailed(String error) {
    return 'Imeshindwa kufuta: $error';
  }

  @override
  String get batch_editDetails => 'Hariri Taarifa';

  @override
  String get batch_batches => 'Batch';

  @override
  String batch_loadFailed(String error) {
    return 'Imeshindwa kupakia batch: $error';
  }

  @override
  String get batch_noneYet => 'Bado hakuna batch iliyorekodiwa.';

  @override
  String get batch_unlabeled => 'Batch isiyo na namba';

  @override
  String get batch_outOfStock => 'Imeisha - 0 zipo';

  @override
  String batch_rowQuantities(int stock, int sellable, String price) {
    return 'Stoo: $stock · Rafu: $sellable · $price';
  }

  @override
  String batch_expiredOn(String date) {
    return 'Iliisha $date';
  }

  @override
  String batch_expiresOn(String date) {
    return 'Inaisha $date';
  }

  @override
  String get batch_deleteExpiredTooltip => 'Futa batch iliyoisha muda';

  @override
  String get batch_deleteTooltip => 'Futa batch';

  @override
  String get batch_adjustQuantity => 'Rekebisha idadi';

  @override
  String get alerts_outOfStock => 'Imeisha';

  @override
  String alerts_messageStock(String product, int sellable, int stock) {
    return '$product - Rafu: $sellable · Stoo: $stock';
  }

  @override
  String alerts_messageExpired(
    String product,
    String date,
    int quantity,
    String unit,
  ) {
    return '$product - iliisha $date · $quantity $unit zipo';
  }

  @override
  String alerts_messageExpiring(
    String product,
    String when,
    String date,
    int quantity,
    String unit,
  ) {
    return '$product - inaisha $when ($date) · $quantity $unit zipo';
  }

  @override
  String get alerts_today => 'leo';

  @override
  String alerts_inDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'baada ya siku $days',
      one: 'baada ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String alerts_messageRestock(String product, int sellable, int stock) {
    return '$product - $sellable rafuni · $stock stoo';
  }

  @override
  String get alerts_title => 'Tahadhari za Bidhaa';

  @override
  String get alerts_subtitle =>
      'Matatizo ya akiba na muda wa kuisha yanayohitaji hatua';

  @override
  String alerts_viewAllCount(int count) {
    return 'Tazama tahadhari zote $count';
  }

  @override
  String get alerts_viewAll => 'Tazama tahadhari zote';

  @override
  String get alerts_allCaughtUp => 'Kila kitu kiko sawa!';

  @override
  String get alerts_noneNow => 'Hakuna tahadhari za akiba kwa sasa.';

  @override
  String get alerts_hintLowStock => 'Chini ya kiwango cha chini';

  @override
  String get alerts_hintDepleted => 'Hakuna kilichobaki';

  @override
  String get alerts_hintRestockShelf => 'Stoo ina akiba';

  @override
  String get alerts_hintExpiringSoon => 'Ndani ya siku 30';

  @override
  String get alerts_hintExpired => 'Bado zipo';

  @override
  String get alerts_restock => 'Ongeza Akiba';

  @override
  String get alerts_moveToShelf => 'Peleka rafuni';

  @override
  String get alerts_adminOnlyMove =>
      'Ni admin tu anayeweza kupeleka bidhaa rafuni';

  @override
  String get alerts_viewBatches => 'Tazama batch';

  @override
  String get alerts_removeExpired => 'Ondoa zilizoisha';

  @override
  String alerts_inStock(int count) {
    return '$count zipo';
  }

  @override
  String alerts_minRequired(int count) {
    return 'Kiwango cha chini: $count';
  }

  @override
  String alerts_onShelf(int count) {
    return '$count rafuni';
  }

  @override
  String alerts_shelfMinimum(int count) {
    return 'Kiwango cha chini rafuni: $count';
  }

  @override
  String get alerts_expiresToday => 'Inaisha leo';

  @override
  String alerts_expiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Inaisha baada ya siku $days',
      one: 'Inaisha baada ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String alerts_dateOnHand(String date, int quantity, String unit) {
    return '$date · $quantity $unit zipo';
  }

  @override
  String alerts_onHand(int quantity, String unit) {
    return '$quantity $unit zipo';
  }

  @override
  String get alerts_searchHint => 'Tafuta kwa bidhaa, aina au tahadhari...';

  @override
  String get alerts_noMatches => 'Hakuna tahadhari zinazolingana na vichujio';

  @override
  String get alerts_colAlert => 'Tahadhari';

  @override
  String get alerts_colStoreShelf => 'Stoo / Rafu';

  @override
  String get alerts_colAction => 'Hatua';

  @override
  String alerts_storeQty(int count) {
    return 'Stoo: $count';
  }

  @override
  String alerts_shelfQty(int count) {
    return 'Rafu: $count';
  }

  @override
  String alerts_storeShelfQty(int stock, int sellable) {
    return 'Stoo: $stock  ·  Rafu: $sellable';
  }

  @override
  String get alerts_none => 'Hakuna tahadhari';

  @override
  String alerts_showingRange(int start, int end, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya tahadhari $total',
      one: 'Inaonyesha $start hadi $end kati ya tahadhari 1',
    );
    return '$_temp0';
  }

  @override
  String get products_smartDefaultsRunning =>
      'Inakokotoa upya viwango vya kujitegemea…';

  @override
  String products_smartDefaultsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Viwango vya kujitegemea vimesasishwa kwa bidhaa $count zenye historia ya kutosha ya matumizi',
      one:
          'Viwango vya kujitegemea vimesasishwa kwa bidhaa 1 yenye historia ya kutosha ya matumizi',
    );
    return '$_temp0';
  }

  @override
  String get products_smartDefaultsNone =>
      'Bado hakuna bidhaa yenye historia ya kutosha ya mauzo/huduma kukokotoa viwango vya kujitegemea';

  @override
  String get products_smartDefaultsFailed =>
      'Imeshindikana kukokotoa upya viwango vya kujitegemea';

  @override
  String get products_shelfStockValue => 'Thamani ya Bidhaa Rafuni';

  @override
  String get products_watchlistFailed =>
      'Imeshindikana kusasisha orodha ya ufuatiliaji';

  @override
  String products_confirmDeleteNamed(String name) {
    return 'Una uhakika unataka kufuta \"$name\"?';
  }

  @override
  String get products_noSellable => 'Hakuna bidhaa za kuuza';

  @override
  String get products_releaseFromStore => 'Toa bidhaa kutoka Stoo';

  @override
  String get products_sellable => 'Za Kuuza';

  @override
  String get products_nothingSellable => 'Imeisha - hakuna cha kuuza';

  @override
  String get products_sell => 'Uza';

  @override
  String get products_removeFromWatchlist => 'Ondoa kwenye Ufuatiliaji';

  @override
  String get products_addToWatchlist => 'Ongeza kwenye Ufuatiliaji';

  @override
  String get products_sellableTitle => 'Bidhaa za Kuuza';

  @override
  String get products_sellableSubtitle => 'Bidhaa zilizo tayari kuuzwa';

  @override
  String get products_recalculateTooltip =>
      'Kokotoa upya viwango vya kujitegemea kutoka historia ya matumizi';

  @override
  String get products_searchHint => 'Tafuta bidhaa, chapa au batch...';

  @override
  String products_stockBatch(int quantity, String unit, String batch) {
    return 'Stoo: $quantity $unit • Batch: $batch';
  }

  @override
  String get products_watchlisted => 'Inafuatiliwa kwenye ripoti za kila siku';

  @override
  String get products_selectFacilityFirst => 'Chagua kituo kwanza';

  @override
  String get products_imageUploadFailed => 'Imeshindikana kupakia picha';

  @override
  String get products_addPhoto => 'Ongeza picha';

  @override
  String get products_batchNo => 'Namba ya Batch';

  @override
  String get products_expiry => 'Tarehe ya Kuisha';

  @override
  String get products_selectType => 'Chagua Aina';

  @override
  String get products_selectCategoryError => 'Tafadhali chagua kundi';

  @override
  String get products_supplier => 'Msambazaji';

  @override
  String products_buyingPriceLabel(String currency) {
    return 'Bei ya Kununua ($currency)';
  }

  @override
  String products_sellingPriceLabel(String currency) {
    return 'Bei ya Kuuza ($currency)';
  }

  @override
  String get products_greaterThanZero => 'Lazima iwe zaidi ya 0';

  @override
  String get products_quantity => 'Idadi';

  @override
  String get products_cannotBeNegative => 'Haiwezi kuwa hasi';

  @override
  String get products_destinationTitle => 'Bidhaa hii iende wapi?';

  @override
  String get products_destinationCatalog => 'Orodha ya Bidhaa za Kuuza';

  @override
  String get products_destinationCatalogHint =>
      'Inapatikana kwa mauzo na miamala';

  @override
  String get products_destinationStoreHint =>
      'Imehifadhiwa lakini bado haiuzwi';

  @override
  String get products_continue => 'Endelea';

  @override
  String get products_nameExists => 'Jina la bidhaa tayari lipo';

  @override
  String get products_addedToCatalog =>
      'Bidhaa imeongezwa kwenye Orodha ya Kuuza';

  @override
  String get products_addedToStore => 'Bidhaa imeongezwa Stoo';

  @override
  String get products_updated => 'Bidhaa imesasishwa';

  @override
  String get products_saveFailed => 'Imeshindikana kuhifadhi bidhaa';

  @override
  String get products_editProduct => 'Hariri Bidhaa';

  @override
  String get products_updateProduct => 'Sasisha Bidhaa';

  @override
  String get products_saveProduct => 'Hifadhi Bidhaa';

  @override
  String get products_basicInfo => 'Taarifa za Msingi';

  @override
  String get products_productName => 'Jina la Bidhaa';

  @override
  String get products_nameRequired => 'Jina la bidhaa linahitajika';

  @override
  String products_alreadyExistsNamed(String name) {
    return '\"$name\" tayari ipo';
  }

  @override
  String get products_openBelowHint =>
      'Unaongeza mzigo mpya au kusasisha idadi yake? Ifungue hapa chini - unaweza kuhariri taarifa na idadi yake hapo hapo.';

  @override
  String get products_openThisProduct => 'Fungua Bidhaa Hii';

  @override
  String get products_similarExist => 'Bidhaa zinazofanana tayari zipo';

  @override
  String get products_open => 'Fungua';

  @override
  String get products_details => 'Taarifa za Bidhaa';

  @override
  String get products_currentQuantity => 'Idadi ya Sasa';

  @override
  String get products_storeQty => 'Idadi Stoo';

  @override
  String get products_invalid => 'Si sahihi';

  @override
  String get products_shelfQty => 'Idadi Rafuni';

  @override
  String get products_quantityEditHint =>
      'Kuhariri hizi kunarekebisha idadi halisi iliyopo sasa.';

  @override
  String products_manyBatchesHint(int count) {
    return 'Bidhaa hii ina batch $count tofauti - zisimamie moja moja kwa usahihi.';
  }

  @override
  String get products_manageBatches => 'Simamia Batch';

  @override
  String get products_addNewBatchLong =>
      'Ongeza Batch Mpya (mzigo mpya, tarehe tofauti ya kuisha)';

  @override
  String get products_pricingStock => 'Bei na Akiba';

  @override
  String get products_additionalInfo => 'Taarifa za Ziada';

  @override
  String get products_minStockLevel => 'Kiwango cha Chini cha Akiba';

  @override
  String products_minStockHint(int count) {
    return 'mf. 5 (itakuwa $count ikiachwa wazi)';
  }

  @override
  String get products_trackInReports => 'Fuatilia kwenye Ripoti za Kila Siku';

  @override
  String get products_trackInReportsHint =>
      'Bidhaa zinazofuatiliwa zinahitaji kuhesabiwa kabla ripoti ya kufunga siku haijawasilishwa.';

  @override
  String sales_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mauzo $count mapya yanapatikana',
      one: 'Mauzo 1 mapya yanapatikana',
    );
    return '$_temp0';
  }

  @override
  String get sales_empty => 'Bado hakuna mauzo';

  @override
  String get sales_emptyFiltered => 'Hakuna mauzo yanayolingana na vichujio';

  @override
  String get sales_collected => 'Yaliyokusanywa';

  @override
  String get sales_pending => 'Yanayodaiwa';

  @override
  String get sales_searchHint => 'Tafuta mauzo kwa bidhaa, mteja, ankara...';

  @override
  String get sales_paymentStatus => 'Hali ya Malipo';

  @override
  String get sales_seller => 'Muuzaji';

  @override
  String get sales_title => 'Kumbukumbu za Mauzo';

  @override
  String get sales_subtitle => 'Fuatilia na simamia miamala yote ya mauzo';

  @override
  String get sales_recordSale => 'Rekodi Mauzo';

  @override
  String get sales_invoiceNo => 'Namba ya Ankara';

  @override
  String sales_firstItem(String name, String quantity) {
    return '$name × $quantity';
  }

  @override
  String sales_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bidhaa $count',
      one: 'Bidhaa 1',
    );
    return '$_temp0';
  }

  @override
  String get sales_none => 'Hakuna mauzo';

  @override
  String get sales_deleteFailed => 'Imeshindikana kufuta mauzo';

  @override
  String get sales_details => 'Taarifa za Mauzo';

  @override
  String sales_quantityTimes(String quantity) {
    return '× $quantity';
  }

  @override
  String get sales_subtotal => 'Jumla Ndogo';

  @override
  String get sales_discount => 'Punguzo';

  @override
  String get sales_totalAmount => 'Jumla Kuu';

  @override
  String get sales_paid => 'Kilicholipwa';

  @override
  String get sales_balance => 'Salio';

  @override
  String get sales_archiveEmpty =>
      'Hakuna mauzo yaliyohifadhiwa yaliyopatikana';

  @override
  String get sales_archiveEmptyHint => 'Jaribu utafutaji au kipindi tofauti';

  @override
  String get sales_archiveTitle => 'Hifadhi ya Mauzo';

  @override
  String sales_archiveSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Mauzo huhifadhiwa baada ya siku $days',
      one: 'Mauzo huhifadhiwa baada ya siku 1',
    );
    return '$_temp0';
  }

  @override
  String get sales_archivedSales => 'Mauzo yaliyohifadhiwa';

  @override
  String sales_archiveShowing(int start, int end, int total, String more) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Inaonyesha $start hadi $end kati ya $total$more ya mauzo',
      one: 'Inaonyesha $start hadi $end kati ya 1$more ya mauzo',
    );
    return '$_temp0';
  }

  @override
  String get sales_item => 'Bidhaa';

  @override
  String get sales_searchArchiveTitle => 'Tafuta Mauzo Yaliyohifadhiwa';

  @override
  String get sales_archiveFullyPaidNote =>
      'Mauzo yaliyohifadhiwa huwa yamelipwa yote - mauzo yanayodaiwa hubaki kwenye kichupo cha Mauzo bila kujali umri.';

  @override
  String sales_archiveCutoffNote(String date) {
    return 'Mauzo ya kabla ya $date tu ndiyo yamefika kwenye hifadhi - mapya zaidi bado yako kwenye orodha ya Mauzo.';
  }

  @override
  String sales_noShelfStock(String product) {
    return '$product haina bidhaa rafuni';
  }

  @override
  String get sales_saleDiscount => 'Punguzo la Mauzo';

  @override
  String sales_discountAmountLabel(String currency) {
    return 'Kiasi cha Punguzo ($currency)';
  }

  @override
  String get sales_browseProducts => 'Vinjari Bidhaa';

  @override
  String get sales_browseFilterHint =>
      'Chuja kwa jina, namba ya batch au kundi...';

  @override
  String get sales_filterByCategory => 'Chuja kwa kundi';

  @override
  String get sales_allCategories => 'Makundi Yote';

  @override
  String get sales_noProductsFound => 'Hakuna bidhaa zilizopatikana';

  @override
  String get sales_outOfStock => 'Imeisha';

  @override
  String sales_availablePrice(int quantity, String unit, String price) {
    return '$quantity $unit zipo · $price';
  }

  @override
  String get sales_expiredSaleBody =>
      'Bidhaa hii imeisha muda. Bado unataka kuiuza?';

  @override
  String sales_expiredPortionLine(int quantity, String unit, String product) {
    return '• $quantity $unit za $product';
  }

  @override
  String get sales_sellAnyway => 'Uza Hata Hivyo';

  @override
  String get sales_addItemFirst =>
      'Ongeza angalau bidhaa moja kabla ya kuhifadhi';

  @override
  String get sales_partialNeedsRegistered =>
      'Chagua mteja aliyesajiliwa kuruhusu malipo ya sehemu';

  @override
  String get sales_walkInPayInFull =>
      'Mauzo ya mteja wa papo hapo lazima yalipwe yote';

  @override
  String get sales_partialNeedsClient =>
      'Chagua mteja kurekodi malipo ya sehemu';

  @override
  String get sales_orChooseWalkIn =>
      'Au chagua Mteja wa Papo Hapo na pokea malipo yote';

  @override
  String get sales_selectPaymentMethod =>
      'Chagua njia ya malipo kabla ya kuhifadhi';

  @override
  String get sales_savedWithDebt => 'Mauzo yamehifadhiwa na deni limerekodiwa';

  @override
  String get sales_saved => 'Mauzo yamehifadhiwa';

  @override
  String get sales_saveFailed => 'Imeshindikana kuhifadhi mauzo';

  @override
  String get sales_summary => 'Muhtasari wa Mauzo';

  @override
  String get sales_totalItems => 'Jumla ya Bidhaa';

  @override
  String get sales_selectMethod => 'Chagua Njia';

  @override
  String sales_amountReceivedLabel(String currency) {
    return 'Kiasi Kilichopokelewa ($currency) *';
  }

  @override
  String sales_changeLabel(String currency) {
    return 'Chenji ($currency)';
  }

  @override
  String get sales_walkInCustomer => 'Mteja wa Papo Hapo';

  @override
  String get sales_noClientSelected => 'Hakuna mteja aliyechaguliwa';

  @override
  String get sales_productSearchHint =>
      'Tafuta bidhaa kwa jina, namba ya batch au kundi...';

  @override
  String get sales_noProductsYet => 'Bado hakuna bidhaa zilizoongezwa';

  @override
  String get sales_addProductsHint =>
      'Tafuta na ongeza bidhaa kwenye mauzo haya';

  @override
  String get sales_colBatchNo => 'Namba ya Batch';

  @override
  String sales_colUnitPrice(String currency) {
    return 'Bei ya Kipimo ($currency)';
  }

  @override
  String get sales_colQty => 'Idadi';

  @override
  String sales_colTotal(String currency) {
    return 'Jumla ($currency)';
  }

  @override
  String sales_batchShort(String batch) {
    return 'Batch: $batch';
  }

  @override
  String sales_expShort(String date) {
    return 'Inaisha: $date';
  }

  @override
  String get sales_notesHint => 'Ongeza maelezo mengine (si lazima)...';

  @override
  String get common_dismiss => 'Funga';

  @override
  String get common_privacyPolicy => 'Sera ya Faragha';

  @override
  String get common_termsOfService => 'Masharti ya Huduma';

  @override
  String get common_logout => 'Toka';

  @override
  String get common_logIn => 'Ingia';

  @override
  String get common_inviteCode => 'Msimbo wa mwaliko';

  @override
  String get common_facilityName => 'Jina la kituo';

  @override
  String get common_facilityNameHint => 'mf. Ukuli';

  @override
  String get common_passwordsDoNotMatch => 'Nenosiri hazilingani';

  @override
  String get common_editProfile => 'Hariri Wasifu';

  @override
  String get auth_switchToDarkMode => 'Badilisha kwenda Hali ya Giza';

  @override
  String get auth_switchToLightMode => 'Badilisha kwenda Hali ya Mwanga';

  @override
  String login_copyright(String appName) {
    return '© 2026 $appName. Haki zote zimehifadhiwa.';
  }

  @override
  String get login_announcements => 'Matangazo';

  @override
  String get login_urgent => 'DHARURA';

  @override
  String get login_announcementFallbackTitle => 'Taarifa';

  @override
  String get login_noAnnouncements => 'Hakuna matangazo';

  @override
  String get login_allCaughtUp => 'Umeshaona yote!';

  @override
  String get login_welcomeBack => 'Karibu tena';

  @override
  String get login_emailHint => 'Weka barua pepe yako';

  @override
  String get login_passwordHint => 'Weka nenosiri lako';

  @override
  String get login_rememberMe => 'Nikumbuke';

  @override
  String get login_forgotPassword => 'Umesahau Nenosiri?';

  @override
  String get login_noAccount => 'Huna akaunti? ';

  @override
  String get login_register => 'Jisajili';

  @override
  String get login_loginButton => 'Ingia';

  @override
  String get login_newBadge => 'MPYA';

  @override
  String get login_credentialsTooShort => 'Weka barua pepe yako na nenosiri.';

  @override
  String get login_slowSignIn =>
      'Kuingia kunachukua muda mrefu kuliko kawaida. Angalia intaneti yako kisha ujaribu tena.';

  @override
  String get login_resetNeedsEmail =>
      'Weka barua pepe yako ili kubadilisha nenosiri.';

  @override
  String get login_resetSent =>
      'Kama akaunti ipo kwa barua pepe hii, kiungo cha kubadilisha nenosiri kimetumwa. Angalia sanduku la barua (na folda ya spam).';

  @override
  String login_resetFailed(String reason) {
    return 'Imeshindwa kutuma barua pepe ya kubadilisha nenosiri. $reason';
  }

  @override
  String get register_inviteInvalid =>
      'Msimbo wa mwaliko si sahihi, umeisha muda, au umeshatumika';

  @override
  String get register_inviteCheckFailed =>
      'Imeshindwa kukagua msimbo huu - jaribu tena';

  @override
  String get register_enterFacilityNameFirst => 'Weka jina la kituo kwanza';

  @override
  String get register_chooseFacilityTypeFirst => 'Chagua aina ya kituo kwanza';

  @override
  String register_facilityLimit(int max) {
    return 'Umefikia kikomo cha vituo $max kwa kila akaunti';
  }

  @override
  String get register_addFacilityFailed => 'Imeshindwa kuongeza kituo hiki';

  @override
  String get register_pwMin8 => 'Angalau herufi 8';

  @override
  String get register_pwNeedsLetter => 'Ongeza angalau herufi moja';

  @override
  String get register_pwNeedsNumber => 'Ongeza angalau namba moja';

  @override
  String get register_pwTooCommon =>
      'Nenosiri hili ni la kawaida mno - chagua jingine';

  @override
  String get register_addAtLeastOneFacility =>
      'Tafadhali ongeza angalau kituo kimoja';

  @override
  String get register_enterValidInvite => 'Weka msimbo sahihi wa mwaliko';

  @override
  String get register_profileUpdated => 'Wasifu umesasishwa';

  @override
  String get register_accountRegistered => 'Akaunti imesajiliwa';

  @override
  String get register_verifyEmailSent =>
      'Tumetuma kiungo cha uthibitisho kwenye barua pepe yako. Angalia folda ya Spam kama hakitaonekana ndani ya dakika chache.';

  @override
  String get register_enterValidInviteFirst =>
      'Weka msimbo sahihi wa mwaliko kwanza';

  @override
  String get register_assistantRegistered =>
      'Msaidizi amesajiliwa, anasubiri idhini ya msimamizi';

  @override
  String get register_verifyEmailAlsoSent =>
      'Pia tumetuma kiungo cha uthibitisho kwenye barua pepe yako. Angalia folda ya Spam kama hakitaonekana.';

  @override
  String get register_emailAlreadyRegistered => 'Barua pepe hii imeshasajiliwa';

  @override
  String get register_emailExists =>
      'Tayari kuna akaunti yenye barua pepe hii. Kama unahamia kituo kingine, barua pepe hii haiwezi kusajiliwa mara ya pili - muombe Msimamizi wa Mfumo akuongeze kwenye kituo kipya badala yake.';

  @override
  String get register_validEmailExample =>
      'Weka barua pepe sahihi, kama name@example.com';

  @override
  String get register_validEmail => 'Weka barua pepe sahihi.';

  @override
  String get register_strongerPasswordField => 'Chagua nenosiri imara zaidi';

  @override
  String get register_strongerPassword => 'Chagua nenosiri imara zaidi.';

  @override
  String register_createFailed(String reason) {
    return 'Imeshindwa kufungua akaunti. $reason';
  }

  @override
  String get register_createYourAccount => 'Fungua akaunti yako';

  @override
  String register_setUpApp(String appName) {
    return 'Andaa $appName kwa agrovet au kituo chako cha mifugo kwa dakika chache.';
  }

  @override
  String get register_setUpCentre =>
      'Andaa agrovet au kituo chako cha mifugo kwa dakika chache.';

  @override
  String get register_benefitAllInOne =>
      'Mauzo, stoo, wateja na madeni sehemu moja';

  @override
  String get register_benefitInvite =>
      'Alika timu yako kwa misimbo salama ya kutumika mara moja';

  @override
  String get register_benefitTrial =>
      'Kila kituo kipya kinaanza na kipindi cha majaribio';

  @override
  String get register_alreadyHaveAccount => 'Una akaunti tayari?';

  @override
  String get register_createAccount => 'Fungua akaunti';

  @override
  String get register_termsPrefix => 'Kwa kufungua akaunti unakubali ';

  @override
  String get register_termsAnd => ' na ';

  @override
  String get register_saveChanges => 'Hifadhi mabadiliko';

  @override
  String get register_fieldFullName => 'Jina kamili';

  @override
  String get register_fieldPhone => 'Namba ya simu';

  @override
  String get register_fieldConfirmPassword => 'Thibitisha nenosiri';

  @override
  String get register_enterFullName => 'Weka jina lako kamili';

  @override
  String get register_nameTooShort =>
      'Jina lako linaonekana fupi mno - weka jina lako kamili';

  @override
  String get register_enterEmail => 'Weka barua pepe yako';

  @override
  String get register_enterPhone => 'Weka namba yako ya simu';

  @override
  String get register_validPhone =>
      'Weka namba sahihi ya simu, kama 0712 345 678';

  @override
  String register_pressAddToInclude(String name) {
    return 'Bonyeza Ongeza ili kujumuisha \"$name\" kabla ya kujisajili';
  }

  @override
  String get register_chooseTypeThenAdd =>
      'Chagua aina ya kituo, kisha bonyeza Ongeza';

  @override
  String get register_addOneFacilityHow =>
      'Ongeza angalau kituo kimoja: weka jina lake, chagua aina yake, kisha bonyeza Ongeza';

  @override
  String get register_enterInviteCode => 'Weka msimbo wako wa mwaliko';

  @override
  String get register_stillChecking =>
      'Bado tunakagua msimbo wako wa mwaliko - jaribu tena baada ya muda mfupi';

  @override
  String get register_createPassword => 'Tengeneza nenosiri';

  @override
  String get register_reenterToConfirm =>
      'Andika nenosiri tena ili kulithibitisha';

  @override
  String register_fixFields(int count, String fields) {
    return 'Tafadhali rekebisha sehemu $count: $fields.';
  }

  @override
  String register_fixFieldsMore(int count, String fields, int more) {
    return 'Tafadhali rekebisha sehemu $count: $fields na nyingine $more.';
  }

  @override
  String get register_saving => 'Inahifadhi...';

  @override
  String get register_creating => 'Inafungua akaunti yako...';

  @override
  String get register_personalDetails => 'Taarifa binafsi';

  @override
  String get register_requiredNote => '* Lazima';

  @override
  String get register_title => 'Cheo';

  @override
  String get register_emailHint => 'name@example.com';

  @override
  String get register_phoneHint => '07XX XXX XXX';

  @override
  String get register_profilePhoto => 'Picha ya wasifu';

  @override
  String get profile_changePhoto => 'Badilisha picha';

  @override
  String get profile_removePhoto => 'Ondoa picha';

  @override
  String get profile_removePhotoTitle => 'Uondoe picha yako?';

  @override
  String get profile_removePhotoBody =>
      'Herufi za kwanza za jina lako zitaonekana badala yake.';

  @override
  String get profile_photoRemoved => 'Picha imeondolewa';

  @override
  String get profile_photoRemoveFailed => 'Imeshindikana kuondoa picha';

  @override
  String get register_tapToChangePhoto => 'Gusa ili kubadilisha picha yako';

  @override
  String get register_tapToAddPhoto => 'Si lazima - gusa ili kuongeza picha';

  @override
  String get register_yourRole => 'Nafasi yako';

  @override
  String get register_roleCoAdminSubtitle => 'Ninasaidia kusimamia kituo';

  @override
  String get register_roleAdminSubtitle => 'Ninamiliki au ninasimamia kituo';

  @override
  String get register_roleAssistantSubtitle => 'Nina msimbo wa mwaliko';

  @override
  String get register_roleLocked => 'Nafasi yako haiwezi kubadilishwa hapa.';

  @override
  String get register_yourFacilities => 'Vituo vyako';

  @override
  String get register_askAdminForInvite =>
      'Muombe msimamizi wa kituo chako msimbo wa mwaliko ili ujiunge na timu yake.';

  @override
  String register_joining(String facility) {
    return 'Unajiunga na: $facility';
  }

  @override
  String register_facilityTypeAndCode(String type, String code) {
    return '$type  ·  Msimbo: $code';
  }

  @override
  String get register_addOneToContinue =>
      'Ongeza angalau kituo kimoja ili kuendelea.';

  @override
  String get register_useViewFacilities =>
      'Kuongeza au kubadilisha vituo, tumia View Facilities.';

  @override
  String register_facilitiesAdded(int count, int max) {
    return 'Vituo $count kati ya $max vimeongezwa';
  }

  @override
  String get register_selectType => 'Chagua aina';

  @override
  String register_maxFacilitiesReached(int max) {
    return 'Umefikia kikomo cha vituo $max';
  }

  @override
  String get register_accountSecurity => 'Usalama wa akaunti';

  @override
  String get register_passwordRule =>
      'Angalau herufi 8, zikiwemo herufi na namba';

  @override
  String get register_looksGood => 'Liko sawa';

  @override
  String get register_reenterPassword => 'Andika nenosiri tena';

  @override
  String get register_passwordsMatch => 'Nenosiri zinalingana';

  @override
  String get entry_noProfile =>
      'Hatukupata wasifu wa akaunti hii. Kama umejisajili sasa hivi, usajili haukukamilika - tafadhali jisajili tena. Hili likiendelea kutokea, wasiliana na msaada.';

  @override
  String get entry_deactivated =>
      'Akaunti hii imezimwa. Muombe msimamizi wa kituo chako (au Msimamizi wa Mfumo) aiwashe tena kabla ya kuingia tena.';

  @override
  String get entry_notActiveYet =>
      'Akaunti yako bado haijawashwa. Tafadhali subiri idhini ya msimamizi.';

  @override
  String get entry_requestNotApproved =>
      'Ombi lako la kujiunga halikuidhinishwa.';

  @override
  String entry_requestNotApprovedFrom(String facility) {
    return 'Ombi lako la kujiunga na $facility halikuidhinishwa.';
  }

  @override
  String get entry_slowLoad => 'Inachukua muda mrefu kuliko kawaida kufunguka.';

  @override
  String get entry_timeoutExplanation =>
      'Hili linachukua muda mrefu kuliko kawaida. Angalia intaneti yako kisha ujaribu tena.';

  @override
  String get entry_unreachable =>
      'Hatukuweza kufikia seva. Angalia intaneti yako kisha ujaribu tena.';

  @override
  String get entry_accessRefused =>
      'Akaunti yako haikuweza kufunguliwa kwa sababu ruhusa ilikataliwa. Jaribu tena, na hili likiendelea, wasiliana na msaada.';

  @override
  String get entry_loadFailed =>
      'Hitilafu imetokea wakati wa kupakia taarifa za akaunti yako. Angalia mtandao wako kisha ujaribu tena.';

  @override
  String get entry_couldNotLoadTitle => 'Imeshindwa kufungua akaunti yako';

  @override
  String get noFacility_enterName => 'Weka jina la kituo.';

  @override
  String get noFacility_chooseType => 'Chagua aina ya kituo.';

  @override
  String get noFacility_wrongPassword => 'Nenosiri hilo si sahihi.';

  @override
  String get noFacility_tooManyAttempts =>
      'Majaribio mengi mno. Subiri dakika chache kisha ujaribu tena.';

  @override
  String get noFacility_unreachable =>
      'Hatukuweza kufikia seva. Angalia mtandao wako kisha ujaribu tena.';

  @override
  String get noFacility_deleteFailed => 'Imeshindwa kufuta akaunti.';

  @override
  String noFacility_deleteFailedWith(String error) {
    return 'Imeshindwa kufuta akaunti: $error';
  }

  @override
  String get noFacility_aFacility => 'kituo';

  @override
  String get noFacility_cantDeleteTitle => 'Akaunti haiwezi kufutwa bado';

  @override
  String noFacility_stillOwns(String name) {
    return 'Akaunti hii bado inamiliki \"$name\", ambacho hakiko kwenye wasifu wako. Wasiliana na msaada ili lishughulikiwe kwanza.';
  }

  @override
  String get noFacility_deleteTitle => 'Ufute akaunti yako?';

  @override
  String get noFacility_deleteWarning =>
      'Hili ni la kudumu na haliwezi kutenduliwa. Akaunti na wasifu wako vitafutwa, na hutaweza kuingia tena kwa barua pepe hii.';

  @override
  String get noFacility_enterPasswordToConfirm =>
      'Weka nenosiri lako ili kuthibitisha.';

  @override
  String get noFacility_accountDeleted => 'Akaunti yako imefutwa.';

  @override
  String get noFacility_deleteAccount => 'Futa akaunti';

  @override
  String get noFacility_adding => 'Inaongeza kituo...';

  @override
  String get noFacility_addFacility => 'Ongeza kituo';

  @override
  String get noFacility_deleteInstead => 'Futa akaunti yangu badala yake';

  @override
  String get noFacility_codeInvalid =>
      'Msimbo huo si sahihi, umeisha muda, au umeshatumika.';

  @override
  String noFacility_requestSent(String facility) {
    return 'Ombi limetumwa kwa $facility. Utaweza kuingia msimamizi wake akishakuidhinisha.';
  }

  @override
  String get noFacility_titleAssistant =>
      'Kwa sasa hauko kwenye kituo chochote';

  @override
  String get noFacility_titleAdmin => 'Kwa sasa huna kituo';

  @override
  String noFacility_noticeMistake(String notice) {
    return '$notice Kama unadhani hilo ni kosa, omba msimbo mpya wa mwaliko.';
  }

  @override
  String get noFacility_bodyAssistant =>
      'Huenda umeondolewa kwenye kituo chako, au bado hujaongezwa kwenye kituo. Akaunti, jina, namba ya simu na picha yako vimehifadhiwa. Ili ujiunge na kituo, weka msimbo wa mwaliko kutoka kwa msimamizi wake.';

  @override
  String get noFacility_bodyAdmin =>
      'Akaunti yako imehifadhiwa. Ongeza kituo ili uendelee, au futa akaunti yako kama huihitaji tena.';

  @override
  String get noFacility_inviteHint => 'mf. JK7-2P4';

  @override
  String noFacility_askingToJoin(String facility) {
    return 'Utaomba kujiunga na: $facility';
  }

  @override
  String noFacility_askingToJoinWithType(String facility, String type) {
    return 'Utaomba kujiunga na: $facility ($type)';
  }

  @override
  String get noFacility_sending => 'Inatuma ombi lako...';

  @override
  String get noFacility_requestToJoin => 'Omba kujiunga';

  @override
  String get noFacility_approvalNote =>
      'Msimamizi wa kituo lazima akuidhinishe, kama ilivyo kwa msaidizi yeyote mpya. Au muombe msimamizi wako wa awali akurudishe.';

  @override
  String get subscription_freeTrialTitle => 'Majaribio Bure';

  @override
  String get subscription_onFreeTrial => 'Uko kwenye majaribio bure.';

  @override
  String subscription_trialDaysLeftEnding(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siku $count',
      one: 'siku 1',
    );
    return 'Umebakiwa na $_temp0 za majaribio bure, yanayoisha $date.';
  }

  @override
  String get subscription_trialEndedTitle => 'Majaribio Yamekwisha';

  @override
  String get subscription_trialEndedReadOnly =>
      'Majaribio yako yamekwisha. Programu iko katika hali ya kusoma tu.';

  @override
  String get subscription_expiredReadOnly =>
      'Usajili wako umekwisha. Programu iko katika hali ya kusoma tu.';

  @override
  String get subscription_trialEndedGrace =>
      'Majaribio yako yamekwisha. Una siku chache za neema kabla hali ya kusoma tu haijaanza.';

  @override
  String get subscription_expiredGrace =>
      'Usajili wako umekwisha. Una siku chache za neema kabla hali ya kusoma tu haijaanza.';

  @override
  String get subscription_trialExpiringSoonTitle =>
      'Majaribio Yanakaribia Kwisha';

  @override
  String get subscription_expiringSoonTitle => 'Usajili Unakaribia Kwisha';

  @override
  String subscription_trialExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siku $count',
      one: 'siku 1',
    );
    return 'Majaribio yako yanakwisha baada ya $_temp0.';
  }

  @override
  String subscription_expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siku $count',
      one: 'siku 1',
    );
    return 'Usajili wako unakwisha baada ya $_temp0.';
  }

  @override
  String subscription_freeTrialDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'zimebaki siku $count',
      one: 'imebaki siku 1',
    );
    return 'Uko kwenye majaribio bure - $_temp0.';
  }

  @override
  String get subscription_trialActive => 'Majaribio yako yanaendelea.';

  @override
  String get subscription_active => 'Usajili wako uko hai.';

  @override
  String get subscription_viewPlans => 'Tazama Vifurushi';

  @override
  String get subscription_renew => 'Huisha';

  @override
  String get subscription_askYourAdmin => '· Muulize msimamizi wako';

  @override
  String get dashboard_reassigned =>
      'Umehamishiwa kituo kingine. Tafadhali ingia tena.';

  @override
  String get dashboard_vsYesterday => 'dhidi ya Jana';

  @override
  String get dashboard_vsLastWeek => 'dhidi ya Wiki Iliyopita';

  @override
  String get dashboard_vsLastMonth => 'dhidi ya Mwezi Uliopita';

  @override
  String get dashboard_vsLastYear => 'dhidi ya Mwaka Uliopita';

  @override
  String get dashboard_goodMorning => 'Habari za asubuhi';

  @override
  String get dashboard_goodAfternoon => 'Habari za mchana';

  @override
  String get dashboard_goodEvening => 'Habari za jioni';

  @override
  String dashboard_greeting(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String dashboard_howFacilityIsDoing(String facility) {
    return 'Hivi ndivyo $facility inavyoendelea leo.';
  }

  @override
  String get dashboard_avatarUpdated => 'Picha ya wasifu imesasishwa';

  @override
  String get dashboard_avatarSaveFailed =>
      'Imeshindwa kuhifadhi picha ya wasifu';

  @override
  String get dashboard_resetPasswordTitle => 'Weka Upya Nenosiri';

  @override
  String dashboard_resetPasswordPrompt(String email) {
    return 'Tuma barua pepe ya kuweka upya nenosiri kwa $email?';
  }

  @override
  String get dashboard_sendLink => 'Tuma Kiungo';

  @override
  String dashboard_resetLinkSent(String email) {
    return 'Kiungo cha kuweka upya kimetumwa kwa $email';
  }

  @override
  String get dashboard_resetLinkFailed =>
      'Imeshindwa kutuma kiungo cha kuweka upya';

  @override
  String get dashboard_expandMenu => 'Panua menyu';

  @override
  String get dashboard_collapseMenu => 'Kunja menyu';

  @override
  String get dashboard_searchAnything => 'Tafuta chochote...';

  @override
  String get dashboard_searchShortcut => 'Ctrl+K';

  @override
  String get dashboard_help => 'Msaada';

  @override
  String get dashboard_account => 'Akaunti';

  @override
  String get dashboard_changePeriod => 'Badilisha kipindi';

  @override
  String get dashboard_totalProductValue => 'Thamani ya Bidhaa Zote';

  @override
  String get dashboard_asOfNow => 'hadi sasa';

  @override
  String dashboard_totalSales(String period) {
    return 'Jumla ya Mauzo ($period)';
  }

  @override
  String dashboard_totalCollected(String period) {
    return 'Jumla Iliyokusanywa ($period)';
  }

  @override
  String dashboard_netProfit(String period) {
    return 'Faida Halisi ($period)';
  }

  @override
  String dashboard_totalExpenses(String period) {
    return 'Jumla ya Matumizi ($period)';
  }

  @override
  String get dashboard_outstandingPayment => 'Malipo Yanayodaiwa';

  @override
  String dashboard_completedServices(String period) {
    return 'Huduma Zilizokamilika ($period)';
  }

  @override
  String get dashboard_recentActivity => 'Shughuli za Karibuni';

  @override
  String get dashboard_viewAll => 'Tazama Zote';

  @override
  String get dashboard_noActivityYet => 'Bado hakuna shughuli.';

  @override
  String get dashboard_recentActivityLoadFailed =>
      'Imeshindwa kupakia shughuli za karibuni.';

  @override
  String get dashboard_salesRevenueOverview => 'Muhtasari wa Mauzo na Mapato';

  @override
  String dashboard_vsLastPeriod(String percent) {
    return '$percent% dhidi ya kipindi kilichopita';
  }

  @override
  String get dashboard_noActivityInPeriod =>
      'Hakuna shughuli katika kipindi hiki.';

  @override
  String get dashboard_sales => 'Mauzo';

  @override
  String get dashboard_collections => 'Makusanyo';

  @override
  String get dashboard_services => 'Huduma';

  @override
  String dashboard_seriesWithCurrency(String label, String currency) {
    return '$label ($currency)';
  }

  @override
  String get dashboard_searchProductsOrClients => 'Tafuta bidhaa au wateja...';

  @override
  String dashboard_searchClient(String phone) {
    return 'Mteja • $phone';
  }

  @override
  String get dashboard_todayAtAGlance => 'Leo kwa Ufupi';

  @override
  String dashboard_outstandingDebts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Madeni Yanayodaiwa',
      one: 'Deni Linalodaiwa',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_profitEarned => 'Imepatikana';

  @override
  String get dashboard_profitPending => 'Inasubiri';

  @override
  String get dashboard_profitHelp =>
      'Imepatikana: tayari imekusanywa kwa fedha taslimu.\nInasubiri: imeuzwa kwa mkopo, bado haijalipwa.';

  @override
  String get dashboard_createNewSale => 'Unda mauzo mapya';

  @override
  String get dashboard_addServiceRecord => 'Ongeza rekodi mpya ya huduma';

  @override
  String get dashboard_addProductToStore => 'Ongeza bidhaa mpya stoo';

  @override
  String get dashboard_emailAppFailed =>
      'Imeshindwa kufungua programu yako ya barua pepe';

  @override
  String get dashboard_contactSupport => 'Wasiliana na Msaada';

  @override
  String dashboard_supportIntro(String appName) {
    return 'Kwa msaada tafadhali wasiliana na msimamizi wa jukwaa la $appName.';
  }

  @override
  String dashboard_facilityNameType(String name, String type) {
    return '$name $type';
  }

  @override
  String get dashboard_fullNameLabel => 'Jina Kamili: ';

  @override
  String get dashboard_emailLabel => 'Barua pepe: ';

  @override
  String get dashboard_phoneLabel => 'Simu: ';

  @override
  String get dashboard_roleLabel => 'Nafasi: ';

  @override
  String get dashboard_viewFacilities => 'Tazama Vituo';

  @override
  String get dashboard_changePassword => 'Badilisha Nenosiri';

  @override
  String get dashboard_logoutConfirm => 'Una uhakika unataka kutoka?';

  @override
  String get nav_stock => 'Stoo';

  @override
  String get nav_products => 'Bidhaa';

  @override
  String get nav_sales => 'Mauzo';

  @override
  String get nav_services => 'Huduma';

  @override
  String get nav_debtors => 'Wadaiwa';

  @override
  String get nav_reports => 'Ripoti';

  @override
  String get nav_platformAdmin => 'Msimamizi wa Jukwaa';

  @override
  String get insights_title => 'Maarifa';

  @override
  String get insights_serviceRevenue => 'Mapato ya huduma';

  @override
  String get insights_outstandingPayments => 'Malipo yanayodaiwa';

  @override
  String get insights_watchSales => 'Fuatilia mauzo wiki hii.';

  @override
  String get insights_noActivity => 'Bado hakuna shughuli iliyorekodiwa.';

  @override
  String get insights_salesTrendingUp => 'Mauzo yanapanda.';

  @override
  String get insights_servicesGaining => 'Huduma zinashika kasi.';

  @override
  String get insights_strongActivity => 'Biashara imechangamka leo.';

  @override
  String get insights_pickingUp => 'Biashara inaimarika.';

  @override
  String get insights_steady => 'Biashara iko imara.';

  @override
  String get insights_quieter => 'Siku tulivu kwa sasa.';

  @override
  String get insights_slowing => 'Shughuli za wateja zinapungua.';

  @override
  String get insights_noOutstanding => 'Hakuna malipo yanayodaiwa.';

  @override
  String get insights_outstandingRising =>
      'Malipo yanayodaiwa yanaongezeka - inafaa kufuatilia.';

  @override
  String get insights_outstandingStable => 'Malipo yanayodaiwa hayabadiliki.';

  @override
  String get insights_outstandingImproving => 'Malipo yanayodaiwa yanapungua.';

  @override
  String get insights_businessPulse => 'Mapigo ya Biashara';

  @override
  String insights_loadFailed(String error) {
    return 'Imeshindwa kupakia maarifa. $error';
  }

  @override
  String get insights_salesLast14 => 'Mauzo - Siku 14 Zilizopita';

  @override
  String get insights_topProductsLast30 => 'Bidhaa 5 Bora - Siku 30 Zilizopita';

  @override
  String get insights_servicesByTypeLast30 =>
      'Huduma kwa Aina - Siku 30 Zilizopita';

  @override
  String insights_totalOver14(String amount) {
    return 'Jumla: $amount kwa siku 14';
  }

  @override
  String insights_topSeller(String name, String amount) {
    return 'Inayouzwa zaidi: $name · $amount';
  }

  @override
  String insights_mostRequested(String name, String amount) {
    return 'Inayoombwa zaidi: $name - $amount';
  }

  @override
  String get insights_noSales14 => 'Hakuna mauzo katika siku 14 zilizopita.';

  @override
  String get insights_noSales30 => 'Hakuna mauzo katika siku 30 zilizopita.';

  @override
  String get insights_noServices30 =>
      'Hakuna huduma katika siku 30 zilizopita.';

  @override
  String get notifications_subtitle =>
      'Taarifa na tahadhari zote kutoka kituo chako';

  @override
  String notifications_loadFailed(String error) {
    return 'Imeshindwa kupakia arifa: $error';
  }

  @override
  String get notifications_catCritical => 'Muhimu Sana';

  @override
  String get notifications_catStock => 'Stoo';

  @override
  String get notifications_catPayments => 'Malipo';

  @override
  String get notifications_catDebts => 'Madeni';

  @override
  String get notifications_catSystem => 'Mfumo';

  @override
  String get notifications_catUpdates => 'Taarifa';

  @override
  String notifications_unreadCount(int count) {
    return '$count hazijasomwa';
  }

  @override
  String get notifications_allRead => 'Zote zimesomwa';

  @override
  String get notifications_searchHint => 'Tafuta arifa...';

  @override
  String get notifications_markAllRead => 'Weka zote zimesomwa';

  @override
  String get notifications_markAllAsRead => 'Weka zote kama zimesomwa';

  @override
  String get notifications_unread => 'Hazijasomwa';

  @override
  String get notifications_read => 'Zimesomwa';

  @override
  String get notifications_statusNew => 'Mpya';

  @override
  String get notifications_clearDateRange => 'Futa kipindi cha tarehe';

  @override
  String get notifications_empty => 'Hakuna arifa';

  @override
  String get notifications_emptyHint =>
      'Taarifa mpya kutoka kituo chako zitaonekana hapa.';

  @override
  String get notifications_noMatches =>
      'Hakuna arifa zinazolingana na vichujio vyako';

  @override
  String get notifications_colNotification => 'Arifa';

  @override
  String notifications_showingRange(int start, int end, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'arifa $total',
      one: 'arifa 1',
    );
    return 'Inaonyesha $start hadi $end kati ya $_temp0';
  }

  @override
  String get notifications_yourPlan => 'Kifurushi Chako';

  @override
  String get notifications_needsAttention => 'Inahitaji Uangalizi';

  @override
  String get notifications_earlier => 'Awali';

  @override
  String get notifications_urgentAnnouncements => 'Matangazo ya Dharura';

  @override
  String get notifications_viewAll => 'Tazama arifa zote';

  @override
  String get notifications_allCaughtUpHint =>
      'Hakuna matangazo ya dharura, matatizo ya usajili, wala tahadhari za stoo kwa sasa.';

  @override
  String get notifications_catPayment => 'Malipo';

  @override
  String get notifications_catDebt => 'Deni';

  @override
  String get notifications_catUpdate => 'Taarifa';

  @override
  String get notifications_markAsRead => 'Weka kama imesomwa';

  @override
  String get notifications_markAsUnread => 'Weka kama haijasomwa';

  @override
  String get notifications_removeReadOnes => 'Ondoa zilizosomwa';

  @override
  String get notifications_removeSelected => 'Ondoa zilizochaguliwa';

  @override
  String get notifications_select => 'Chagua';

  @override
  String get notifications_removedOne => 'Arifa imeondolewa';

  @override
  String notifications_removedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Arifa $count zimeondolewa',
      one: 'Arifa 1 imeondolewa',
    );
    return '$_temp0';
  }

  @override
  String notifications_removeReadConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ondoa arifa $count zilizosomwa? Ni wewe tu utaacha kuziona.',
      one: 'Ondoa arifa 1 iliyosomwa? Ni wewe tu utaacha kuiona.',
    );
    return '$_temp0';
  }

  @override
  String get notifications_reasonUntilRenewed =>
      'Inabaki hadi usajili utakaposasishwa';

  @override
  String get notifications_reasonUntilTrialEnds =>
      'Inabaki hadi majaribio bure yaishe';

  @override
  String get notifications_reasonUntilDecided =>
      'Inabaki hadi ombi likubaliwe au likataliwe';

  @override
  String get notifications_reasonUntilNewClaim =>
      'Inabaki hadi malipo mapya yatumwe';

  @override
  String get notifications_loadOlder => 'Pakia za zamani zaidi';

  @override
  String get notifications_updateFailed => 'Imeshindikana kusasisha arifa';

  @override
  String get selectFacility_slowLoad =>
      'Hii inachukua muda mrefu kuliko kawaida. Angalia muunganisho wako kisha ujaribu tena.';

  @override
  String selectFacility_loadFailed(String error) {
    return 'Imeshindwa kupakia vituo vyako. $error';
  }

  @override
  String get selectFacility_title => 'Chagua Kituo';

  @override
  String get selectFacility_proceed => 'Endelea';

  @override
  String get selectFacility_unnamed => 'Bila jina';

  @override
  String get selectFacility_selected => 'Imechaguliwa';

  @override
  String get selectFacility_clickToSelect => 'Bofya kuchagua';

  @override
  String get facilities_noneFound => 'Hakuna vituo vilivyopatikana.';

  @override
  String get facilityPicker_tagline => 'Simamia. Hudumia. Kua.';

  @override
  String get facilityPicker_logOut => 'Toka';

  @override
  String get facilityPicker_title => 'Chagua Kituo Chako';

  @override
  String get facilityPicker_intro =>
      'Chagua kituo unachotaka kusimamia. Unaweza kuhamia kituo kingine wakati wowote kupitia menyu ya juu.';

  @override
  String get facilityPicker_searchHint =>
      'Tafuta kituo kwa jina, mahali au aina...';

  @override
  String get facilityPicker_allTypes => 'Aina Zote';

  @override
  String get facilityPicker_filter => 'Chuja';

  @override
  String get facilityPicker_unnamedFacility => 'Kituo Bila Jina';

  @override
  String get facilityPicker_typeNotSet => 'Aina haijawekwa';

  @override
  String get facilityPicker_locationNotSet => 'Mahali hapajawekwa';

  @override
  String facilityPicker_staffCount(int count) {
    return 'Wafanyakazi $count';
  }

  @override
  String get facilityPicker_openFacility => 'Fungua Kituo';

  @override
  String get facilityPicker_setAsDefault => 'Weka kama Chaguo-msingi';

  @override
  String get facilityPicker_default => 'Chaguo-msingi';

  @override
  String get facilityPicker_footer =>
      'Salama  •  Inaaminika  •  Imejengwa kwa Biashara za Mifugo';

  @override
  String get facilityOwnership_owned => 'Inamilikiwa';

  @override
  String get facilityOwnership_rented => 'Imekodiwa';

  @override
  String get facilities_loadFailed => 'Imeshindwa kupakia vituo';

  @override
  String get facilities_limitTitle => 'Kikomo cha Vituo Kimefikiwa';

  @override
  String facilities_limitMessage(int max) {
    return 'Umefikia kikomo cha vituo $max kwa kila akaunti. Wasiliana na huduma kwa wateja ukihitaji zaidi.';
  }

  @override
  String get facilities_addTitle => 'Ongeza Kituo';

  @override
  String get facilities_logoOptional => 'Nembo (si lazima)';

  @override
  String get facilities_nameLabel => 'Jina la Kituo';

  @override
  String get facilities_nameAndTypeRequired => 'Weka jina na uchague aina';

  @override
  String get facilities_adding => 'Inaongeza...';

  @override
  String get facilities_added => 'Kituo kimeongezwa';

  @override
  String get facilities_editTitle => 'Hariri Kituo';

  @override
  String get facilities_tapToChangeLogo => 'Gusa kubadilisha nembo';

  @override
  String get facilities_removeLogo => 'Ondoa nembo';

  @override
  String get facilities_businessEmailOptional =>
      'Barua pepe ya Biashara (si lazima)';

  @override
  String get facilities_businessPhoneOptional => 'Simu ya Biashara (si lazima)';

  @override
  String get facilities_addressOptional => 'Anwani (si lazima)';

  @override
  String get facilities_descriptionOptional => 'Maelezo (si lazima)';

  @override
  String get facilities_taglineOptional => 'Kauli mbiu (si lazima)';

  @override
  String get facilities_taglineHint => 'mf. Agrovet na Huduma kwa Wanyama';

  @override
  String get facilities_licenseOptional => 'Namba ya Leseni (si lazima)';

  @override
  String get facilities_tinOptional => 'TIN (si lazima)';

  @override
  String get facilities_tinHint => 'Namba ya Utambulisho wa Mlipakodi';

  @override
  String get facilities_ownershipOptional => 'Umiliki (si lazima)';

  @override
  String get facilities_restockQuestion =>
      'Kwa kawaida unaongeza mzigo mara ngapi?';

  @override
  String get facilities_restockHelper =>
      'Hutumika kupendekeza viwango vya akiba kutokana na historia ya mauzo yako';

  @override
  String facilities_saveFailed(String error) {
    return 'Imeshindwa kuhifadhi mabadiliko. $error';
  }

  @override
  String get facilities_updated => 'Kituo kimesasishwa';

  @override
  String get facilities_checkingAssistants =>
      'Inahakikisha hakuna msaidizi aliyebaki…';

  @override
  String get facilities_cannotDeleteTitle => 'Haiwezekani Kufuta Kituo';

  @override
  String facilities_cannotDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Kituo hiki bado kina wasaidizi $count. Waondoe au wahamishe wote kwanza, kisha ujaribu tena.',
      one:
          'Kituo hiki bado kina msaidizi 1. Mwondoe au mhamishe kwanza, kisha ujaribu tena.',
    );
    return '$_temp0';
  }

  @override
  String get facilities_deleteTitle => 'Futa Kituo';

  @override
  String facilities_deleteWarning(String name) {
    return 'Hii inafuta kabisa \"$name\" na kila kitu ndani yake - bidhaa, mauzo, wateja, madeni, malipo na historia. Hili haliwezi kutenduliwa.';
  }

  @override
  String get facilities_onlyFacilityWarning =>
      'Hiki ndicho kituo chako pekee. Ukikifuta, akaunti yako itabaki bila kituo - utaendelea kuwa umeingia, na kisha unaweza kuongeza kipya au kufuta akaunti yako.';

  @override
  String facilities_typeToConfirm(String name) {
    return 'Andika \"$name\" kuthibitisha:';
  }

  @override
  String facilities_deleteFailed(String error) {
    return 'Imeshindwa kufuta kituo. $error';
  }

  @override
  String get facilities_deleted => 'Kituo kimefutwa';

  @override
  String get facilities_title => 'Vituo';

  @override
  String get facilities_subtitle =>
      'Simamia vituo vyako vyote vya mifugo na matawi';

  @override
  String get facilities_noMatchFilters =>
      'Hakuna kituo kinacholingana na vichujio vyako. Jaribu utafutaji au hali nyingine.';

  @override
  String get facilities_searchHint => 'Tafuta vituo...';

  @override
  String get facilities_noMatchFilter =>
      'Hakuna kituo kinacholingana na kichujio hiki.';

  @override
  String facilities_nameWithType(String name, String type) {
    return '$name $type';
  }

  @override
  String get facilities_moreActionsTooltip => 'Vitendo zaidi';

  @override
  String get facilities_moreActions => 'Vitendo Zaidi';

  @override
  String get facilities_switchToThis => 'Hamia Kituo Hiki';

  @override
  String facilities_managerLine(String name) {
    return '$name (Meneja)';
  }

  @override
  String facilities_joinedOn(String date) {
    return 'Kimejiunga tarehe $date';
  }

  @override
  String get facilities_code => 'Msimbo wa Kituo';

  @override
  String get facilities_licenseNo => 'Namba ya Leseni';

  @override
  String get facilities_notSet => 'Haijawekwa';

  @override
  String get facilities_activityFallback => 'Shughuli';

  @override
  String get facilities_viewProducts => 'Angalia Bidhaa';

  @override
  String get facilities_viewAll => 'Angalia Zote';

  @override
  String get facilities_lowStockItems => 'Bidhaa Zenye Stoo Chache';

  @override
  String get facilities_viewItems => 'Angalia Vitu';

  @override
  String get facilities_expiredItems => 'Bidhaa Zilizopitwa na Muda';

  @override
  String get facilities_totalSalesThisMonth => 'Jumla ya Mauzo (Mwezi Huu)';

  @override
  String get facilities_viewReport => 'Angalia Ripoti';

  @override
  String get facilities_tabOverview => 'Muhtasari';

  @override
  String get facilities_tabInventory => 'Muhtasari wa Bidhaa';

  @override
  String get facilities_tabSales => 'Muhtasari wa Mauzo';

  @override
  String get facilities_teamTabMessage =>
      'Simamia wafanyakazi wa kituo hiki kupitia skrini ya Wafanyakazi.';

  @override
  String get facilities_openTeamMembers => 'Fungua Wafanyakazi';

  @override
  String get facilities_noProducts => 'Bado hakuna bidhaa katika kituo hiki.';

  @override
  String get facilities_byCategory => 'Kwa Kundi';

  @override
  String get facilities_nothingNeedsAttention =>
      'Hakuna bidhaa yenye stoo chache au iliyopitwa na muda kwa sasa.';

  @override
  String get facilities_recentSales => 'Mauzo ya Karibuni';

  @override
  String get facilities_noSalesYet => 'Bado hakuna mauzo yaliyorekodiwa.';

  @override
  String get facilities_walkInSale => 'Mauzo ya papo hapo';

  @override
  String facilities_saleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mauzo $count',
      one: 'mauzo 1',
    );
    return '$_temp0';
  }

  @override
  String get facilities_actionsTitle => 'Vitendo vya Kituo';

  @override
  String get facilities_actionsIntro =>
      'Mipangilio ya kituo hiki pekee. Kwa akaunti yako, arifa, printa, sarafu na mapendeleo ya programu nzima, tumia skrini kuu ya Mipangilio.';

  @override
  String get facilities_editDetails => 'Hariri Taarifa za Kituo';

  @override
  String get facilities_editDetailsHint =>
      'Jina, aina, nembo, mawasiliano, leseni na zaidi.';

  @override
  String get facilities_deactivateThis => 'Simamisha Kituo Hiki';

  @override
  String get facilities_reactivateThis => 'Rejesha Kituo Hiki';

  @override
  String get facilities_deactivateHint =>
      'Huweka kituo hiki kama hakifanyi kazi. Kinabaki kwenye orodha yako lakini kinaonyeshwa kuwa hakifanyi kazi.';

  @override
  String get facilities_reactivateHint =>
      'Huweka kituo hiki kama kinachofanya kazi tena.';

  @override
  String get facilities_deleteThis => 'Futa Kituo Hiki';

  @override
  String get facilities_deleteThisHint =>
      'Huondoa kabisa kituo hiki na data yake. Hili haliwezi kutenduliwa.';

  @override
  String get facilities_retentionTitle =>
      'Muda wa Kuhifadhi Kumbukumbu za Shughuli';

  @override
  String facilities_retentionText(int count) {
    return 'Kumbukumbu zilizozidi muda huu hufutwa kiotomatiki kwa kituo hiki. Kwa sasa: siku $count.';
  }

  @override
  String get facilities_overdueTitle => 'Kikomo cha Deni Kuchelewa';

  @override
  String facilities_overdueText(int count) {
    return 'Deni lisilolipwa huhesabiwa kuwa limechelewa likipita idadi hii ya siku. Kwa sasa: siku $count.';
  }

  @override
  String get facilities_deactivateConfirmTitle => 'Simamisha Kituo?';

  @override
  String get facilities_reactivateConfirmTitle => 'Rejesha Kituo?';

  @override
  String facilities_deactivateConfirm(String name) {
    return '$name kitawekwa kama Hakifanyi Kazi. Kinabaki kwenye orodha ya vituo vyako lakini kinaonyeshwa kuwa hakifanyi kazi.';
  }

  @override
  String facilities_reactivateConfirm(String name) {
    return '$name kitawekwa kama Kinafanya Kazi tena.';
  }

  @override
  String facilities_markedStatus(String status) {
    return 'Kituo sasa: $status';
  }

  @override
  String get facilities_keepLogsFor => 'Hifadhi Kumbukumbu Kwa';

  @override
  String get facilities_deleteOlderLogsTitle =>
      'Futa Kumbukumbu za Zamani Sasa?';

  @override
  String facilities_deleteOlderLogsMessage(int current, int selected) {
    return 'Kwa sasa kumbukumbu zinahifadhiwa kwa siku $current. Ukibadilisha kuwa siku $selected, kila kumbukumbu iliyozidi siku $selected itafutwa kabisa sasa hivi - si kuanzia sasa tu. Hili haliwezi kutenduliwa.';
  }

  @override
  String facilities_deleteAndSwitch(int count) {
    return 'Futa na ubadilishe kuwa siku $count';
  }

  @override
  String facilities_retentionSavedNotDeleted(int count) {
    return 'Imehifadhiwa. Kumbukumbu zilizozidi siku $count zitafichwa, lakini bado hazijaweza kufutwa';
  }

  @override
  String facilities_retentionSavedDeleted(int days, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kumbukumbu $count za zamani zimefutwa',
      one: 'kumbukumbu 1 ya zamani imefutwa',
    );
    return 'Kumbukumbu sasa zitahifadhiwa kwa siku $days, $_temp0';
  }

  @override
  String facilities_retentionSaved(int count) {
    return 'Kumbukumbu sasa zitahifadhiwa kwa siku $count';
  }

  @override
  String get facilities_saveSettingFailed => 'Imeshindwa kuhifadhi mpangilio';

  @override
  String get facilities_overdueAfterTitle => 'Imechelewa Baada ya';

  @override
  String facilities_overdueSaved(int count) {
    return 'Madeni sasa yanachelewa baada ya siku $count';
  }

  @override
  String get facilities_aboutTitle => 'Kuhusu kituo hiki';

  @override
  String get facilities_facilityType => 'Aina ya Kituo';

  @override
  String get facilities_ownership => 'Umiliki';

  @override
  String get facilities_createdBy => 'Kimeundwa na';

  @override
  String get facilities_lastUpdated => 'Kilisasishwa Mwisho';

  @override
  String get facilities_viewAllActivity => 'Angalia shughuli zote';

  @override
  String get activity_subtitle => 'Kila tendo lililorekodiwa kwa kituo hiki';

  @override
  String get activity_searchHint => 'Tafuta kumbukumbu...';

  @override
  String activity_keepingLogsFor(int count) {
    return 'Kumbukumbu zinahifadhiwa kwa siku $count';
  }

  @override
  String get activity_empty => 'Hakuna kumbukumbu za shughuli';

  @override
  String activity_autoDeleteAfter(int count) {
    return 'Kumbukumbu hufutwa zenyewe baada ya siku $count';
  }

  @override
  String get activity_noMatch =>
      'Hakuna kumbukumbu zinazolingana na vichujio ulivyochagua.';

  @override
  String get activity_scopeNote =>
      'Unaona shughuli zako mwenyewe, na chochote kinachokuhusu. Mambo mengine ya timu yanaonekana kwa wasimamizi tu.';

  @override
  String activity_filterChip(String label, int count) {
    return '$label · $count';
  }

  @override
  String activity_retentionSavedHidden(int count) {
    return 'Imehifadhiwa - kumbukumbu zilizozidi siku $count sasa zimefichwa';
  }

  @override
  String activity_retentionNotDeletedDetail(String problem) {
    return 'Bado hazijaweza kufutwa: $problem';
  }

  @override
  String activity_olderLogsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kumbukumbu $count za zamani zimefutwa',
      one: 'Kumbukumbu 1 ya zamani imefutwa',
    );
    return '$_temp0';
  }

  @override
  String get activity_saveRetentionFailed =>
      'Imeshindwa kuhifadhi muda wa kuhifadhi kumbukumbu';

  @override
  String get activity_retentionNoPermission =>
      'Kanuni za usalama kwa sasa haziruhusu kufuta kumbukumbu';

  @override
  String get products_sortNameAsc => 'Jina (A-Z)';

  @override
  String get products_sortNameDesc => 'Jina (Z-A)';

  @override
  String get products_sortPriceLowHigh => 'Bei (Chini-Juu)';

  @override
  String get products_sortPriceHighLow => 'Bei (Juu-Chini)';

  @override
  String get products_sortStockLowHigh => 'Akiba (Chini-Juu)';

  @override
  String get products_sortStockHighLow => 'Akiba (Juu-Chini)';

  @override
  String get products_sortExpirySoonest => 'Kuisha Muda (Za Karibu Kwanza)';

  @override
  String get payments_sourceSale => 'Malipo ya mauzo';

  @override
  String get payments_sourceService => 'Malipo ya huduma';

  @override
  String get payments_sourceDebtRepayment => 'Malipo ya deni';

  @override
  String get membership_unreachable =>
      'Imeshindwa kufikia seva - angalia mtandao wako kisha ujaribu tena.';

  @override
  String get membership_signInAgain =>
      'Tafadhali ingia tena kisha ujaribu tena.';

  @override
  String get membership_generic =>
      'Kuna tatizo limetokea. Tafadhali jaribu tena.';

  @override
  String get session_deactivatedByAdmin =>
      'Akaunti yako imezimwa na msimamizi.';

  @override
  String get session_signedOutElsewhere =>
      'Umetolewa kwa sababu akaunti yako ilitolewa kutoka kifaa kingine.';

  @override
  String get sales_deleteThisTitle => 'Futa mauzo haya?';

  @override
  String sales_deleteToTrashBody(String invoice) {
    return '$invoice inahamishiwa Tupio na bidhaa zake zinarudi rafuni. Kama yaliuzwa kwa mkopo, deni la mteja linaondolewa pia. Unaweza kutendua sasa au kuyarejesha kutoka Tupio ndani ya siku 30.';
  }

  @override
  String sales_deleteToTrashBodyPaid(String invoice, String paid) {
    return '$invoice inahamishiwa Tupio na bidhaa zake zinarudi rafuni. Kama yaliuzwa kwa mkopo, deni la mteja linaondolewa pia. Pesa iliyokwisha pokelewa ($paid) inabaki kwenye malipo yako. Unaweza kutendua sasa au kuyarejesha kutoka Tupio ndani ya siku 30.';
  }

  @override
  String get sales_movedToTrash => 'Mauzo yamehamishiwa Tupio';

  @override
  String get sales_restored => 'Mauzo yamerejeshwa';

  @override
  String get sales_restoredDetail =>
      'Akiba, deni na salio la mteja vimesasishwa.';

  @override
  String get sales_cantRestore => 'Haiwezekani kurejesha mauzo haya';

  @override
  String get services_deleteThisTitle => 'Futa huduma hii?';

  @override
  String services_deleteToTrashBody(String invoice) {
    return '$invoice inahamishiwa Tupio, bidhaa zake zinarudi stoo, na deni lake na gharama yake vinaondolewa hadi utakapoirejesha. Unaweza kutendua sasa au kuirejesha kutoka Tupio ndani ya siku 30.';
  }

  @override
  String services_deleteToTrashBodyPaid(String invoice, String paid) {
    return '$invoice inahamishiwa Tupio, bidhaa zake zinarudi stoo, na deni lake na gharama yake vinaondolewa hadi utakapoirejesha. Pesa iliyokwisha pokelewa ($paid) inabaki kwenye malipo yako. Unaweza kutendua sasa au kuirejesha kutoka Tupio ndani ya siku 30.';
  }

  @override
  String get services_restored => 'Huduma imerejeshwa';

  @override
  String get services_restoredDetail =>
      'Akiba, deni, gharama na salio la mteja vimesasishwa.';

  @override
  String get services_cantRestore => 'Haiwezekani kurejesha huduma hii';

  @override
  String get trash_restoredOldCopy =>
      'Kipengee hiki kilifutwa kabla ya sasisho. Kagua akiba yake baadaye.';

  @override
  String trash_restoreNotEnoughStock(
    String product,
    int needed,
    int available,
  ) {
    return 'Hakuna $product ya kutosha stoo: zinahitajika $needed, zimebaki $available. Ongeza akiba kwanza.';
  }

  @override
  String get trash_restoreClientGone => 'Mteja hayupo tena.';

  @override
  String trash_restoreProductGone(String product) {
    return '$product haipo tena.';
  }

  @override
  String get register_accountCreatedSignIn =>
      'Akaunti yako imefunguliwa, lakini hatukuweza kukuingiza moja kwa moja. Tafadhali ingia kwa barua pepe na nenosiri lako.';

  @override
  String membership_tooManyInviteAttempts(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'dakika $minutes',
      one: 'dakika 1',
    );
    return 'Misimbo mingi ya mwaliko si sahihi. Subiri $_temp0 kisha ujaribu tena.';
  }

  @override
  String get update_title => 'Unahitaji kusasisha';

  @override
  String update_body(String appName, String current, String minimum) {
    return 'Toleo hili la $appName ($current) haliwezi kutumika tena. Tafadhali sasisha hadi toleo $minimum au jipya zaidi.';
  }

  @override
  String update_howTo(String appName) {
    return 'Kwenye kompyuta, pakia upya ukurasa huu. Kwenye simu, sakinisha toleo jipya zaidi la $appName.';
  }

  @override
  String wizard_stepOf(int current, int total) {
    return 'Hatua $current kati ya $total';
  }

  @override
  String get wizard_back => 'Rudi';

  @override
  String register_stepAccountType(String appName) {
    return 'Utatumiaje $appName?';
  }

  @override
  String get register_stepAccountTypeHint => 'Chagua kinachokufaa.';

  @override
  String get register_stepAboutYou => 'Kuhusu wewe';

  @override
  String get register_stepAboutYouHint =>
      'Tuambie wewe ni nani na jinsi ya kukupata.';

  @override
  String get register_stepFacilityHint =>
      'Ongeza kila kituo unachosimamia na uchague aina yake.';

  @override
  String get register_stepInvite => 'Msimbo wako wa mwaliko';

  @override
  String get register_stepSignIn => 'Taarifa za kuingia';

  @override
  String get register_stepSignInHint =>
      'Barua pepe na nenosiri utakalotumia kuingia.';

  @override
  String get register_stepReview => 'Kagua na ufungue';

  @override
  String get register_stepReviewHint =>
      'Kagua taarifa zako, kisha fungua akaunti yako.';

  @override
  String register_consent(String terms, String privacy) {
    return 'Ninakubali $terms na $privacy.';
  }

  @override
  String get register_consentRequired =>
      'Weka alama kwenye kisanduku ili ukubali kabla ya kufungua akaunti yako.';

  @override
  String get authFooter_tagline =>
      'Mauzo, stoo, wateja na madeni kwa agrovet na kliniki za mifugo.';

  @override
  String get authFooter_support => 'Msaada';

  @override
  String get authFooter_legal => 'Kisheria';

  @override
  String get authFooter_helpContact => 'Msaada na mawasiliano';

  @override
  String get social_facebook => 'Facebook';

  @override
  String get social_instagram => 'Instagram';

  @override
  String get social_x => 'X';

  @override
  String get social_linkedin => 'LinkedIn';

  @override
  String get social_youtube => 'YouTube';

  @override
  String get social_tiktok => 'TikTok';

  @override
  String get authFooter_platform => 'Jukwaa';

  @override
  String authFooter_about(String appName) {
    return 'Kuhusu $appName';
  }

  @override
  String get authFooter_howToUse => 'Jinsi ya kuitumia';

  @override
  String get authFooter_faq => 'Maswali ya mara kwa mara';

  @override
  String about_intro(String appName) {
    return '$appName ni programu ya kuendesha agrovet au kituo cha mifugo nchini Tanzania.';
  }

  @override
  String get about_whoFor =>
      'Ni kwa ajili ya agrovet, kliniki za mifugo, hospitali za mifugo na madaktari wa mifugo wanaotembelea wateja, na kwa watu wanaofanya kazi humo.';

  @override
  String get about_coversTitle => 'Inashughulikia nini';

  @override
  String get about_coverSales => 'Mauzo, pamoja na risiti.';

  @override
  String get about_coverStock =>
      'Bidhaa na akiba, kutoka Stoo hadi kwenye rafu.';

  @override
  String get about_coverServices => 'Huduma na ziara.';

  @override
  String get about_coverClients => 'Wateja na madeni wanayodaiwa.';

  @override
  String get about_coverPayments => 'Malipo na miamala mingine.';

  @override
  String get about_coverReports => 'Ripoti za kila siku.';

  @override
  String get about_coverTeam =>
      'Wafanyakazi wako: wasaidizi hujiunga kwa msimbo wa mwaliko na wewe unawaidhinisha.';

  @override
  String about_whoBuilds(String appName) {
    return '$appName imetengenezwa na inaendeshwa na $appName, yaani \"sisi\" katika Masharti ya Huduma na Sera ya Faragha.';
  }

  @override
  String get about_yourData =>
      'Kumbukumbu ambazo timu yako inaingiza ni mali ya kituo chako, kama Masharti ya Huduma yanavyosema.';

  @override
  String get about_questions => 'Una maswali?';

  @override
  String get howToUse_ownerTitle => 'Kama unaendesha kituo (Msimamizi)';

  @override
  String get howToUse_owner1 =>
      'Kwenye ukurasa wa kuingia bonyeza Jisajili, chagua \"Ninamiliki au ninasimamia kituo\", ongeza jina na aina ya kituo chako, kisha bonyeza Fungua akaunti.';

  @override
  String get howToUse_owner2 =>
      'Kituo chako kipya kinaanza na kipindi cha majaribio. Mipangilio, chini ya Usajili, inaonyesha muda wake na mipango inayofuata.';

  @override
  String get howToUse_owner3 =>
      'Fungua Bidhaa na bonyeza Ongeza Bidhaa. Chagua Orodha ya Bidhaa za Kuuza ili uiuze sasa, au Stoo ili uihifadhi kwanza.';

  @override
  String get howToUse_owner4 =>
      'Kuhamisha akiba kwenda rafuni, fungua Stoo na bonyeza Toa kwenye bidhaa.';

  @override
  String get howToUse_owner5 =>
      'Fungua Mauzo na bonyeza Rekodi Mauzo. Mteja akilipa chini ya jumla, kiasi kilichobaki kinahifadhiwa kama deni lake.';

  @override
  String get howToUse_owner6 =>
      'Fungua Huduma na bonyeza Rekodi Ziara ili kurekodi huduma.';

  @override
  String get howToUse_owner7 =>
      'Mteja anapolipa deni, fungua Wadaiwa, tafuta deni hilo na bonyeza Rekodi Malipo.';

  @override
  String get howToUse_owner8 =>
      'Kuongeza msaidizi, gusa jina lako kwenye upau wa juu, fungua Wafanyakazi na bonyeza Mwalike Msaidizi. Msimbo unafanya kazi kwa saa 48 au hadi utumike mara moja.';

  @override
  String get howToUse_owner9 =>
      'Akishajisajili, fungua Wafanyakazi na bonyeza Idhinisha.';

  @override
  String get howToUse_owner10 =>
      'Fungua Ripoti na bonyeza Tengeneza Ripoti ya Leo kupata ripoti ya siku.';

  @override
  String get howToUse_assistantTitle =>
      'Kama unafanya kazi katika kituo (Msaidizi)';

  @override
  String get howToUse_assistant1 =>
      'Muombe msimamizi wa kituo msimbo wa mwaliko.';

  @override
  String get howToUse_assistant2 =>
      'Kwenye ukurasa wa kuingia bonyeza Jisajili, chagua \"Nina msimbo wa mwaliko\" na andika msimbo. Jina la kituo linaonekana msimbo ukiwa sahihi.';

  @override
  String get howToUse_assistant3 =>
      'Jaza taarifa zako na bonyeza Fungua akaunti. Kisha akaunti yako inasubiri idhini ya msimamizi.';

  @override
  String get howToUse_assistant4 =>
      'Hadi hapo, ukiingia utaona \"Akaunti yako bado haijawashwa.\"';

  @override
  String get howToUse_assistant5 =>
      'Ukishaidhinishwa, unatumia skrini zilizo kwenye menyu ya pembeni kwa kituo hicho: rekodi mauzo na huduma, ongeza wateja na rekodi malipo.';

  @override
  String get howToUse_assistant6 =>
      'Msimamizi pekee ndiye anaweza kufuta mauzo, huduma na bidhaa, au kufungua Wafanyakazi, Usajili, Takataka, Hamisha Data na Saa za Biashara.';

  @override
  String get faq_startQ => 'Ninaanzaje?';

  @override
  String get faq_startA =>
      'Bonyeza Jisajili kwenye ukurasa wa kuingia na uchague \"Ninamiliki au ninasimamia kituo\". Kituo chako kinaanza na kipindi cha majaribio; Mipangilio, chini ya Usajili, inaonyesha muda wake.';

  @override
  String get faq_trialQ => 'Nini kinatokea kipindi cha majaribio kikiisha?';

  @override
  String get faq_trialA =>
      'Unahitaji usajili ili kuendelea kutumia kila kipengele. Usajili ukiisha, kuna muda mfupi wa nyongeza; kisha kumbukumbu zako zinaendelea kuonekana, lakini mauzo mapya, huduma na maingizo kama hayo yanasimamishwa hadi utakapolipia tena.';

  @override
  String get faq_teamQ => 'Ninaongezaje wafanyakazi wangu?';

  @override
  String get faq_teamA =>
      'Katika Wafanyakazi bonyeza Mwalike Msaidizi na mpe mtu huyo msimbo. Anajisajili kwa msimbo huo, na wewe unamwidhinisha katika Wafanyakazi.';

  @override
  String get faq_assistantQ => 'Msaidizi anaweza kuona na kufanya nini?';

  @override
  String get faq_assistantA =>
      'Msaidizi anatumia skrini zilizo kwenye menyu ya pembeni kwa kituo chake. Msimamizi pekee ndiye anaweza kufuta mauzo, huduma na bidhaa, au kufungua Wafanyakazi, Usajili, Takataka, Hamisha Data na Saa za Biashara.';

  @override
  String get faq_saleQ => 'Ninarekodije mauzo?';

  @override
  String get faq_saleA =>
      'Fungua Mauzo na bonyeza Rekodi Mauzo. Mteja akilipa chini ya jumla, kiasi kilichobaki kinahifadhiwa kama deni lake chini ya Wadaiwa.';

  @override
  String get faq_serviceQ => 'Ninarekodije huduma?';

  @override
  String get faq_serviceA => 'Fungua Huduma na bonyeza Rekodi Ziara.';
}
