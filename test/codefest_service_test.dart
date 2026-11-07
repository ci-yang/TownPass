import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/city_service/model/my_service_model.dart';

void main() {
  test('Codefest entry uses the requested deployment URL', () {
    const expectedUrl = String.fromEnvironment(
      'EXPECTED_CODEFEST_SERVICE_URL',
      defaultValue: 'https://codefest.ciyang.dev',
    );
    expect(MyServiceItemId.codefest.item.destinationUrl, expectedUrl);
  });

  test('Codefest configuration preserves official service entries', () {
    expect(
      MyServiceItemId.districtOffice.item.destinationUrl,
      'https://taipei-pass-service.vercel.app/',
    );
    expect(
      MyServiceItemId.locationSearch.item.destinationUrl,
      'https://taipei-pass-service.vercel.app/surrounding-service/',
    );
    expect(
      MyServiceItemId.dashboard.item.destinationUrl,
      'https://dashboard.gov.taipei/',
    );
  });
}
