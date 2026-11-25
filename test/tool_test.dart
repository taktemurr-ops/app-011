import 'package:flutter_test/flutter_test.dart';
import 'package:uyg_birikim_hedefi/uyg_birikim_hedefi.dart';

void main() {
  test('33 dilde ad ve açıklama, doğru kimlik', () {
    expect(birikimHedefiTool.id, birikimHedefiId);
    expect(birikimHedefiTool.title.length, 33);
    expect(birikimHedefiTool.tagline.length, 33);
  });
}
