import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/weather_forecast.dart';
import '../../services/weather_service.dart';
import '../../data/egypt_data.dart';
import '../../services/weather_push_service.dart';
import '../../services/egypt_locations_service.dart';
import '../../services/calculator_service.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';
import '../admin/admin_panel_screen.dart';
import '../calculators/calculator_hub_screen.dart';
import '../farm/my_farm_screen.dart';
import '../irrigation/irrigation_designer_screen.dart';
import '../satellite/satellite_access_gate_screen.dart';
import './profile_screen.dart';
import './statistics_screen.dart';
import './home_dashboard_widgets.dart';


// ---------------- HomeDashboard ----------------
class HomeDashboard extends StatefulWidget {
  final String userName;
  final String userPhone;
  const HomeDashboard({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String weatherTemp = "--";
  String weatherHumidity = "--";
  String weatherStatusText = "جاري تحديد موقعك وجلب الطقس...";
  String locationName = "";
  bool isWeatherLoaded = false;
  bool _refreshing = false;
  String _selectedGovernorate = "";
  List<GovernorateInfo> _governorates = [];
  WeatherSnapshot? _weatherSnapshot;
  double? _weatherLatitude;
  double? _weatherLongitude;
  WeatherLocationSelection? _selectedWeatherLocation;
  bool _weatherPushEnabled = false;
  bool _weatherPushBusy = false;
  List<MyFarmProgram> _activePrograms = const [];
  StreamSubscription<List<MyFarmProgram>>? _farmProgramsSubscription;
  late Future<bool> _adminAccess;

  @override
  void initState() {
    super.initState();
    _adminAccess = CalculatorService.isCurrentUserAdmin();
    _loadCachedWeather();
    _loadWeatherPushPreference();
    _listenToFarmPrograms();
  }

  void _listenToFarmPrograms() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _farmProgramsSubscription = MyFarmService.getUserPrograms(uid).listen(
      (programs) {
        _safeSet(() => _activePrograms = programs
            .where((program) => program.status == 'active' && !program.isCompleted)
            .toList(growable: false));
      },
      onError: (Object error) {
        debugPrint('تعذر تحميل البرامج النشطة للإنذار المبكر');
      },
    );
  }

  void _loadGovernorates() {
    if (_governorates.isNotEmpty) return;
    setState(() {
      _governorates = EgyptData.governorates;
    });
  }

  Future<void> _showGovernoratePicker() async {
    _loadGovernorates();
    if (!mounted) return;

    final selectedGovernorate = await showModalBottomSheet<GovernorateInfo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.location_city, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Text('اختر المحافظة',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.my_location,
                      color: Color(0xFF047857)),
                  title: const Text('تحديد تلقائي (GPS)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استخدام موقعك الحالي',
                      style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _fetchWeatherByLocation();
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _governorates.length,
                  itemBuilder: (context, index) {
                    final gov = _governorates[index];
                    final name = gov.name;
                    final isSelected = name == _selectedGovernorate;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: isSelected
                            ? const Color(0xFF047857)
                            : Colors.grey,
                      ),
                      title: Text(name),
                      trailing: isSelected
                          ? const Icon(Icons.check,
                              color: Color(0xFF047857))
                          : null,
                      onTap: () async {
                        Navigator.pop(context, gov);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedGovernorate == null || !mounted) return;

    try {
      final catalog = await EgyptLocationCatalog.load();
      final governorate = catalog.findGovernorate(selectedGovernorate.name);
      if (governorate == null) {
        throw const FormatException('لم تتوفر بيانات لهذه المحافظة.');
      }
      final area = await _pickAdministrativeArea(governorate, catalog);
      if (area == null || !mounted) return;
      final location = await _pickWeatherLocationInArea(
        governorate,
        area,
        catalog.coverageNote,
      );
      if (location != null && mounted) {
        await _fetchWeatherForAdministrativeLocation(location);
      }
    } catch (error) {
      debugPrint('تعذر تحميل بيانات المراكز والقرى');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل قائمة المراكز والقرى. حاول مرة أخرى.'),
          ),
        );
      }
    }
  }

  Future<EgyptAdministrativeArea?> _pickAdministrativeArea(
    EgyptAdministrativeGovernorate governorate,
    EgyptLocationCatalog catalog,
  ) {
    return showModalBottomSheet<EgyptAdministrativeArea>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city,
                          color: Color(0xFF047857)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اختر المركز أو المنطقة في ${governorate.name}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Text(
                    'اختر المركز أولاً، ثم اختر قريتك إن كانت مدرجة.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: governorate.areas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final area = governorate.areas[index];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined,
                            color: Color(0xFF047857)),
                        title: Text(area.name),
                        subtitle: Text(area.villages.isEmpty
                            ? 'استخدام موقع المركز أو المنطقة'
                            : '${area.villages.length} قرية/وحدة محلية متاحة'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.pop(sheetContext, area),
                      );
                    },
                  ),
                ),
                _buildLocationDataAttribution(catalog.coverageNote),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<WeatherLocationSelection?> _pickWeatherLocationInArea(
    EgyptAdministrativeGovernorate governorate,
    EgyptAdministrativeArea area,
    String coverageNote,
  ) {
    return showModalBottomSheet<WeatherLocationSelection>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.holiday_village_outlined,
                          color: Color(0xFF047857)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اختر القرية في ${area.name}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.location_city,
                      color: Color(0xFF047857)),
                  title: Text('استخدام موقع ${area.name}'),
                  subtitle: const Text('طقس تقريبي على مستوى المركز/المنطقة'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    WeatherLocationSelection.forArea(governorate, area),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: area.villages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final village = area.villages[index];
                      return ListTile(
                        leading: const Icon(Icons.holiday_village_outlined),
                        title: Text(village.name),
                        onTap: () => Navigator.pop(
                          sheetContext,
                          WeatherLocationSelection.forVillage(
                            governorate,
                            area,
                            village,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildLocationDataAttribution(coverageNote),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDataAttribution(String coverageNote) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        'البيانات: CAPMAS عبر OCHA/HDX · CC BY-IGO. $coverageNote',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      ),
    );
  }

  void _safeSet(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _loadWeatherPushPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final enabled = await WeatherPushService.isEnabled(uid);
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    _safeSet(() => _weatherPushEnabled = enabled);
    if (enabled) {
      try {
        await WeatherPushService.syncStoredLocation(uid);
      } catch (error) {
        debugPrint('تعذر مزامنة اشتراك الطقس المحفوظ');
      }
    }
  }

  Future<void> _syncWeatherPushLocation(double latitude, double longitude) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await WeatherPushService.syncLocation(
        uid: uid,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      debugPrint('تعذر تحديث موقع تنبيهات الطقس');
    }
  }

  Future<void> _setWeatherPushEnabled(bool enabled) async {
    if (_weatherPushBusy) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً لتفعيل التنبيهات.')),
      );
      return;
    }
    if (enabled && (_weatherLatitude == null || _weatherLongitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد موقع المزرعة أولاً من بطاقة الطقس.')),
      );
      return;
    }

    _safeSet(() => _weatherPushBusy = true);
    try {
      if (enabled) {
        await WeatherPushService.enable(
          uid: uid,
          latitude: _weatherLatitude!,
          longitude: _weatherLongitude!,
        );
      } else {
        await WeatherPushService.disable(uid);
      }
      _safeSet(() => _weatherPushEnabled = enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? 'تم تفعيل إشعارات الطقس لهذا الجهاز.'
                : 'تم إيقاف إشعارات الطقس لهذا الجهاز.'),
          ),
        );
      }
    } on WeatherPushPermissionDenied {
      _safeSet(() => _weatherPushEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسمح بالإشعارات من إعدادات الهاتف لتفعيلها.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث اشتراك الطقس. تحقق من الاتصال ثم أعد المحاولة.'),
          ),
        );
      }
    } finally {
      _safeSet(() => _weatherPushBusy = false);
    }
  }

  String _weatherSummary(WeatherSnapshot snapshot) {
    final temperature = snapshot.currentTemperatureC;
    final formattedTemperature = temperature == temperature.roundToDouble()
        ? temperature.toStringAsFixed(0)
        : temperature.toStringAsFixed(1);
    return '${snapshot.currentCondition} · درجة الحرارة: $formattedTemperature°م | الرطوبة: ${snapshot.currentHumidityPercent}%';
  }

  Future<void> _fetchWeatherForAdministrativeLocation(
    WeatherLocationSelection location,
  ) async {
    _safeSet(() {
      _refreshing = true;
      _selectedGovernorate = location.governorateName;
      _selectedWeatherLocation = location;
      _weatherLatitude = location.latitude;
      _weatherLongitude = location.longitude;
      _weatherSnapshot = null;
      isWeatherLoaded = false;
      weatherTemp = '--';
      weatherHumidity = '--';
      weatherStatusText = 'جاري جلب الطقس للموقع المختار...';
      locationName = location.displayName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_gov', location.governorateName);
      await prefs.setString(
        'selected_weather_location',
        json.encode(location.toJson()),
      );
      await prefs.remove('weather_data');
      unawaited(_syncWeatherPushLocation(location.latitude, location.longitude));

      final snapshot = await WeatherService.fetch(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _safeSet(() {
        _weatherSnapshot = snapshot;
        _weatherLatitude = location.latitude;
        _weatherLongitude = location.longitude;
        weatherTemp = snapshot.currentTemperatureC.toString();
        weatherHumidity = snapshot.currentHumidityPercent.toString();
        weatherStatusText = _weatherSummary(snapshot);
        isWeatherLoaded = true;
      });

      await _saveWeatherCache();
    } catch (e) {
      debugPrint("خطأ في توقعات الطقس");
      _safeSet(() => weatherStatusText = "⚠️ تعذر الاتصال بالخدمة");
    } finally {
      _safeSet(() => _refreshing = false);
    }
  }

  Future<void> _refreshWeather() async {
    final selectedLocation = _selectedWeatherLocation;
    if (selectedLocation != null) {
      await _fetchWeatherForAdministrativeLocation(selectedLocation);
      return;
    }
    await _fetchWeatherByLocation();
  }

  Future<void> _loadCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedGovernorate = prefs.getString('selected_gov') ?? "";
    final savedLocation = prefs.getString('selected_weather_location');
    if (savedLocation != null) {
      try {
        _selectedWeatherLocation = WeatherLocationSelection.fromJson(
          Map<String, dynamic>.from(json.decode(savedLocation) as Map),
        );
      } catch (_) {
        await prefs.remove('selected_weather_location');
      }
    }
    final cached = prefs.getString('weather_data');
    bool stale = true;
    if (cached != null) {
      try {
        final data = json.decode(cached) as Map<String, dynamic>;
        final savedAt = int.tryParse('${data['saved_at'] ?? ''}');
        if (savedAt != null) {
          final age = DateTime.now().millisecondsSinceEpoch - savedAt;
          stale = age > const Duration(minutes: 30).inMilliseconds;
        }
        WeatherSnapshot? snapshot;
        final cachedForecast = data['forecast'];
        if (cachedForecast is Map) {
          try {
            snapshot = WeatherSnapshot.fromJson(
              Map<String, dynamic>.from(cachedForecast),
            );
          } catch (_) {}
        }
        _safeSet(() {
          _weatherSnapshot = snapshot;
          _weatherLatitude = (data['latitude'] as num?)?.toDouble() ??
              _selectedWeatherLocation?.latitude;
          _weatherLongitude = (data['longitude'] as num?)?.toDouble() ??
              _selectedWeatherLocation?.longitude;
          weatherTemp = snapshot?.currentTemperatureC.toString() ??
              (data['temp'] ?? "--").toString();
          weatherHumidity = snapshot?.currentHumidityPercent.toString() ??
              (data['humidity'] ?? "--").toString();
          weatherStatusText = snapshot == null
              ? (data['status'] ?? "").toString()
              : _weatherSummary(snapshot);
          locationName = _selectedWeatherLocation?.displayName ??
              (data['location'] ?? "").toString();
          isWeatherLoaded = snapshot != null || data['loaded'] == true;
        });
      } catch (_) {}
    }
    if (!mounted) return;
    if (!isWeatherLoaded || stale || _weatherSnapshot == null) {
      final selectedLocation = _selectedWeatherLocation;
      if (selectedLocation != null) {
        unawaited(_fetchWeatherForAdministrativeLocation(selectedLocation));
      } else {
        // لا نفترض أن مركز المحافظة هو موقع المزرعة؛ نستخدم GPS ما لم يحدد
        // المستخدم مركزًا أو قرية بنفسه.
        unawaited(_fetchWeatherByLocation());
      }
    }
  }

  Future<void> _saveWeatherCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'weather_data',
        json.encode({
          'temp': weatherTemp,
          'humidity': weatherHumidity,
          'status': weatherStatusText,
          'location': locationName,
          'loaded': isWeatherLoaded,
          'latitude': _weatherLatitude,
          'longitude': _weatherLongitude,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
          'forecast': _weatherSnapshot?.toJson(),
        }));
  }

  Future<String> _getCityName(
    double lat,
    double lon, {
    String fallback = "",
  }) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1&accept-language=ar&zoom=18');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Nabati-App/1.0',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final rawAddress = data['address'];
        final address = rawAddress is Map
            ? Map<String, dynamic>.from(rawAddress)
            : <String, dynamic>{};
        final governorate = address['state'] ??
            address['governorate'] ??
            address['region'];
        final locality = address['village'] ??
            address['town'] ??
            address['city'] ??
            address['municipality'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['city_district'] ??
            address['county'] ??
            address['state_district'];
        if (governorate != null && governorate.toString().trim().isNotEmpty) {
          final governorateName = governorate.toString().trim();
          if (locality != null && locality.toString().trim().isNotEmpty) {
            final localityName = locality.toString().trim();
            if (localityName != governorateName) {
              return '$localityName، $governorateName';
            }
          }
          return governorateName;
        }
        final city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['city_district'] ??
            address['county'] ??
            address['state_district'];
        if (city != null && city.toString().trim().isNotEmpty) {
          return city.toString();
        }
      }
    } catch (e) {
      debugPrint("Nominatim error");
    }
    if (fallback.isNotEmpty) return fallback;
    return '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
  }

  Future<void> _fetchWeatherByLocation() async {
    _safeSet(() {
      _refreshing = true;
      _selectedWeatherLocation = null;
      _selectedGovernorate = '';
      _weatherSnapshot = null;
      _weatherLatitude = null;
      _weatherLongitude = null;
      weatherTemp = '--';
      weatherHumidity = '--';
      locationName = 'جار تحديد موقعك الحالي...';
      weatherStatusText = 'جار طلب قراءة GPS حديثة ودقيقة...';
      isWeatherLoaded = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_gov');
      await prefs.remove('selected_weather_location');
      await prefs.remove('weather_data');

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSet(() {
          locationName = 'تعذر تحديد الموقع';
          weatherStatusText = 'شغّل GPS في الهاتف ثم أعد المحاولة.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _safeSet(() {
            locationName = 'تعذر تحديد الموقع';
            weatherStatusText = 'اسمح للتطبيق باستخدام الموقع ثم أعد المحاولة.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _safeSet(() {
          locationName = 'تعذر تحديد الموقع';
          weatherStatusText =
              'فعّل صلاحية الموقع من إعدادات الهاتف ثم أعد المحاولة.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 45),
        ),
      );
      final now = DateTime.now();
      final fixAge = now.difference(position.timestamp);
      if (fixAge > const Duration(minutes: 3) ||
          fixAge < const Duration(minutes: -1)) {
        _safeSet(() {
          locationName = 'قراءة GPS قديمة';
          weatherStatusText =
              'لم يصل موقع حديث. تحرك إلى مكان مفتوح وتأكد من تشغيل GPS.';
        });
        return;
      }
      if (!position.accuracy.isFinite || position.accuracy > 10000) {
        _safeSet(() {
          locationName = 'إشارة GPS غير دقيقة';
          weatherStatusText =
              'دقة الموقع ضعيفة؛ فعّل الموقع الدقيق في إعدادات الهاتف ثم أعد المحاولة.';
        });
        return;
      }

      String cityName = await _getCityName(
        position.latitude,
        position.longitude,
        fallback: 'موقعك الحالي',
      );

      final snapshot = await WeatherService.fetch(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _safeSet(() {
        _weatherSnapshot = snapshot;
        _weatherLatitude = position.latitude;
        _weatherLongitude = position.longitude;
        _selectedWeatherLocation = null;
        weatherTemp = snapshot.currentTemperatureC.toString();
        weatherHumidity = snapshot.currentHumidityPercent.toString();
        locationName = cityName;
        _selectedGovernorate = "";
        weatherStatusText = _weatherSummary(snapshot);
        isWeatherLoaded = true;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_gov');
        await prefs.remove('selected_weather_location');
      } catch (_) {}
      await _saveWeatherCache();
      unawaited(
        _syncWeatherPushLocation(position.latitude, position.longitude),
      );
    } catch (e) {
      debugPrint('تعذر الحصول على موقع GPS حديث ودقيق');
      _safeSet(() {
        _weatherSnapshot = null;
        isWeatherLoaded = false;
        locationName = 'تعذر تحديد الموقع';
        weatherStatusText =
            'تحقق من تشغيل GPS وصلاحية الموقع الدقيق، ثم أعد المحاولة.';
      });
    } finally {
      _safeSet(() => _refreshing = false);
    }
  }

  @override
  void dispose() {
    _farmProgramsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مرحباً بك، ${widget.userName}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Text('نباتي - مستشارك الزراعي الذكي',
                style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11)),
          ],
        ),
        actions: [
          FutureBuilder<bool>(
            future: _adminAccess,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.admin_panel_settings,
                    color: Colors.amber),
                tooltip: 'لوحة الأدمن',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminPanelScreen()),
                  );
                },
              );
            },
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    userName: widget.userName,
                    userPhone: widget.userPhone,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            EarlyWarningCard(forecast: _weatherSnapshot?.days, programs: _activePrograms),
            if (_activePrograms.isNotEmpty) const SizedBox(height: 8),
            HomeWeatherCard(
              snapshot: _weatherSnapshot,
              locationName: locationName,
              statusText: weatherStatusText,
              refreshing: _refreshing,
              signedIn: FirebaseAuth.instance.currentUser != null,
              pushEnabled: _weatherPushEnabled,
              pushBusy: _weatherPushBusy,
              onPickLocation: _showGovernoratePicker,
              onRefresh: _refreshWeather,
              onTogglePush: _setWeatherPushEnabled,
            ),
            const SizedBox(height: 16),
            const HomeTipCard(),
            const SizedBox(height: 20),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                HomeQuickActionCard(
                  icon: Icons.calculate,
                  color: const Color(0xFF047857),
                  title: 'الحاسبات',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CalculatorHubScreen(),
                  )),
                ),
                HomeQuickActionCard(
                  icon: Icons.agriculture,
                  color: const Color(0xFF10B981),
                  title: 'مزرعتي',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MyFarmScreen(),
                  )),
                ),
                HomeQuickActionCard(
                  icon: Icons.water_drop,
                  color: const Color(0xFF0E7490),
                  title: 'اللاندسكيب والري',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const IrrigationDesignerScreen(),
                  )),
                ),
                HomeQuickActionCard(
                  icon: Icons.satellite_alt,
                  color: const Color(0xFF0F766E),
                  title: 'رصد الأقمار',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SatelliteMonitoringScreen(),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
