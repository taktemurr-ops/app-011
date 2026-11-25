/// Birikim Hedefi · Savings Goals
///
/// Hedefe ne kadar kaldı, ayda ne ayırmalı. Finans ve Hesaplama merkez uygulamasında yer alır; gerçek
/// uygulama ortak motordadır (finans_motoru), çatı studio_core/apps.
library;

import 'package:finans_motoru/finans_motoru.dart';
import 'package:studio_core/apps/apps.dart';

const String birikimHedefiId = 'uyg-birikim-hedefi';

/// Merkezin kullandığı araç tanımı (33 dilde ad ve açıklama).
final AppTool birikimHedefiTool = finansTool(birikimHedefiId);
