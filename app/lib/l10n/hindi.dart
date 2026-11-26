// Hindi for the customer screens, keyed by the English text in the code (core/i18n.dart's tr). Everyday Hindi:
// the words customers already use stay (ऑर्डर, कार्ट, डिलीवरी, ऑफर, कूपन). One file per area, one translator each.
import 'hi_account.dart';
import 'hi_catalog.dart';
import 'hi_core.dart';
import 'hi_services.dart';
import 'hi_shop.dart';

// final, not const: the same English line may appear in two areas (the later one wins)
final hindi = <String, String>{...hiCore, ...hiCatalog, ...hiAccount, ...hiShop, ...hiServices};
