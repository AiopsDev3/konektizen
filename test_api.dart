import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final url = "https://portal.georisk.gov.ph/arcgis/rest/services/PSA/Barangay/MapServer/4/query?where=city_name%20LIKE%20%27%25Laoag%25%27&outFields=brgy_name,city_name,prov_name,brgy_code&returnGeometry=true&outSR=4326&f=geojson";
  final res = await http.get(Uri.parse(url));
  print("Status: \${res.statusCode}");
  if (res.statusCode == 200) {
    final geoJson = jsonDecode(res.body);
    final features = geoJson['features'];
    print("Features count: \${features.length}");
    if (features.length > 0) {
      print("First feature properties: \${features[0]['properties']}");
      print("First feature geometry type: \${features[0]['geometry']['type']}");
      print("First feature coords length: \${features[0]['geometry']['coordinates'].length}");
    }
  }
}
