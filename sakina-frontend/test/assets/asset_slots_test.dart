import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/assets/asset_slots.dart';

void main() {
  test('asset slot registry is typed and complete', () {
    expect(
      SakinaAssetSlots.all.map((slot) => slot.id).toSet(),
      SakinaAssetSlotId.values.toSet(),
    );

    for (final slot in SakinaAssetSlots.all) {
      expect(slot.label, isNotEmpty);
      expect(slot.aspectRatio, greaterThan(0));
      expect(slot.minWidth, greaterThan(0));
      expect(slot.minHeight, greaterThan(0));
      expect(SakinaAssetSlots.get(slot.id), same(slot));
    }
  });
}
