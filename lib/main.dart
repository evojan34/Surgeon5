import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF08203E),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SurgicalRegistryApp());
}

// ==========================================
// الهوية اللونية المطابقة للتصميم (Exact Color Palette)
// ==========================================
class AppColors {
  static const Color navyDark = Color(0xFF08203E);
  static const Color navyPrimary = Color(0xFF0D3562);
  static const Color navyAccent = Color(0xFF154C88);
  static const Color bgLight = Color(0xFFF3F6FA);

  // ألوان البطاقات الإحصائية الأربع
  static const Color statPurpleBg = Color(0xFFF1EAFF);
  static const Color statPurpleBorder = Color(0xFF6C3CE9);

  static const Color statBlueBg = Color(0xFFE5F2FF);
  static const Color statBlueBorder = Color(0xFF1976D2);

  static const Color statMintBg = Color(0xFFDFF7EE);
  static const Color statMintBorder = Color(0xFF00A86B);

  static const Color statAmberBg = Color(0xFFFFF3DC);
  static const Color statAmberBorder = Color(0xFFF59E0B);

  // ألوان الأوسمة داخل بطاقة المريض
  static const Color pillGreenBg = Color(0xFFD7F5E8);
  static const Color pillGreenText = Color(0xFF0D6832);

  static const Color pillOrangeBg = Color(0xFFFDECC8);
  static const Color pillOrangeText = Color(0xFF7A4100);

  static const Color pillPurpleBg = Color(0xFFEDE7FB);
  static const Color pillPurpleText = Color(0xFF4A2574);

  static const Color roleBadgeBg = Color(0xFFDCE8F8);
}

class SurgicalRegistryApp extends StatelessWidget {
  const SurgicalRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجل البورد الجراحي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.navyPrimary,
        scaffoldBackgroundColor: AppColors.bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navyDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainShellScreen(),
    );
  }
}

// ==========================================
// رسام خط نبض القلب (ECG Wave Painter) تحت العنوان
// ==========================================
class EcgWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64B5F6).withOpacity(0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final midY = size.height / 2;
    final w = size.width;

    path.moveTo(0, midY);
    path.lineTo(w * 0.35, midY);
    path.lineTo(w * 0.40, midY - 4);
    path.lineTo(w * 0.44, midY + 4);
    path.lineTo(w * 0.48, midY - 14);
    path.lineTo(w * 0.52, midY + 12);
    path.lineTo(w * 0.56, midY - 6);
    path.lineTo(w * 0.60, midY);
    path.lineTo(w, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 1. نموذج بيانات المريض واللوكبوك (Patient Model)
// ==========================================
class PatientRecord {
  final int? id;
  final String mrn;
  final String name;
  final String age;
  final String gender;
  final String phone;
  final String bloodGroup;
  final String admissionDate;

  final String rotation;
  final String consultantName;
  final String surgeonRole;
  final String operationMagnitude;

  final String chronicDiseases;
  final String allergies;
  final String currentMedications;
  final String smokingStatus;
  final String pastSurgeries;
  final String pastComplications;

  final String chiefComplaint;
  final String clinicalExam;
  final String labRadiologyNotes;
  final String diagnosis;

  final String plannedOperation;
  final String operationUrgency;
  final String asaScore;
  final String anesthesiaType;
  final String operationDate;
  final String operationStatus;
  final String operativeNotes;

  final String drainsInfo;
  final String dvtProphylaxis;
  final String antibioticProphylaxis;

  final String biopsyStatus;
  final String histopathologyResult;
  final String tnmStaging;

  final bool isStarred;
  final String surgicalPearls;

  final String finalOutcome;
  final String clavienDindoGrade;
  final String dischargeTreatment;
  final String followUpDate;

  final List<String> radiologyImages;
  final List<String> labImages;
  final List<String> woundImages;
  final List<String> biopsyImages;

  PatientRecord({
    this.id,
    required this.mrn,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.bloodGroup,
    required this.admissionDate,
    required this.rotation,
    required this.consultantName,
    required this.surgeonRole,
    required this.operationMagnitude,
    required this.chronicDiseases,
    required this.allergies,
    required this.currentMedications,
    required this.smokingStatus,
    required this.pastSurgeries,
    required this.pastComplications,
    required this.chiefComplaint,
    required this.clinicalExam,
    required this.labRadiologyNotes,
    required this.diagnosis,
    required this.plannedOperation,
    required this.operationUrgency,
    required this.asaScore,
    required this.anesthesiaType,
    required this.operationDate,
    required this.operationStatus,
    required this.operativeNotes,
    required this.drainsInfo,
    required this.dvtProphylaxis,
    required this.antibioticProphylaxis,
    required this.biopsyStatus,
    required this.histopathologyResult,
    required this.tnmStaging,
    required this.isStarred,
    required this.surgicalPearls,
    required this.finalOutcome,
    required this.clavienDindoGrade,
    required this.dischargeTreatment,
    required this.followUpDate,
    required this.radiologyImages,
    required this.labImages,
    required this.woundImages,
    required this.biopsyImages,
  });

  String displayName(bool anonymized) {
    if (!anonymized) return name;
    final code = mrn.isNotEmpty ? mrn : (id?.toString() ?? 'X');
    return 'مريض #$code ($gender، $age سنة)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mrn': mrn,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'admissionDate': admissionDate,
      'rotation': rotation,
      'consultantName': consultantName,
      'surgeonRole': surgeonRole,
      'operationMagnitude': operationMagnitude,
      'chronicDiseases': chronicDiseases,
      'allergies': allergies,
      'currentMedications': currentMedications,
      'smokingStatus': smokingStatus,
      'pastSurgeries': pastSurgeries,
      'pastComplications': pastComplications,
      'chiefComplaint': chiefComplaint,
      'clinicalExam': clinicalExam,
      'labRadiologyNotes': labRadiologyNotes,
      'diagnosis': diagnosis,
      'plannedOperation': plannedOperation,
      'operationUrgency': operationUrgency,
      'asaScore': asaScore,
      'anesthesiaType': anesthesiaType,
      'operationDate': operationDate,
      'operationStatus': operationStatus,
      'operativeNotes': operativeNotes,
      'drainsInfo': drainsInfo,
      'dvtProphylaxis': dvtProphylaxis,
      'antibioticProphylaxis': antibioticProphylaxis,
      'biopsyStatus': biopsyStatus,
      'histopathologyResult': histopathologyResult,
      'tnmStaging': tnmStaging,
      'isStarred': isStarred ? 1 : 0,
      'surgicalPearls': surgicalPearls,
      'finalOutcome': finalOutcome,
      'clavienDindoGrade': clavienDindoGrade,
      'dischargeTreatment': dischargeTreatment,
      'followUpDate': followUpDate,
      'radiologyImages': jsonEncode(radiologyImages),
      'labImages': jsonEncode(labImages),
      'woundImages': jsonEncode(woundImages),
      'biopsyImages': jsonEncode(biopsyImages),
    };
  }

  factory PatientRecord.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null || val.toString().isEmpty) return [];
      try {
        return List<String>.from(jsonDecode(val.toString()));
      } catch (_) {
        return [];
      }
    }

    return PatientRecord(
      id: map['id'] as int?,
      mrn: map['mrn'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'] ?? 'ذكر',
      phone: map['phone'] ?? '',
      bloodGroup: map['bloodGroup'] ?? 'O+',
      admissionDate: map['admissionDate'] ?? '',
      rotation: map['rotation'] ?? 'الجراحة العامة',
      consultantName: map['consultantName'] ?? '',
      surgeonRole: map['surgeonRole'] ?? 'P - جراح رئيسي (Performed)',
      operationMagnitude: map['operationMagnitude'] ?? 'Major',
      chronicDiseases: map['chronicDiseases'] ?? '',
      allergies: map['allergies'] ?? '',
      currentMedications: map['currentMedications'] ?? '',
      smokingStatus: map['smokingStatus'] ?? 'غير مدخن',
      pastSurgeries: map['pastSurgeries'] ?? '',
      pastComplications: map['pastComplications'] ?? '',
      chiefComplaint: map['chiefComplaint'] ?? '',
      clinicalExam: map['clinicalExam'] ?? '',
      labRadiologyNotes: map['labRadiologyNotes'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      plannedOperation: map['plannedOperation'] ?? '',
      operationUrgency: map['operationUrgency'] ?? 'مجدولة (باردة)',
      asaScore: map['asaScore'] ?? 'ASA I',
      anesthesiaType: map['anesthesiaType'] ?? 'تخدير عام (GA)',
      operationDate: map['operationDate'] ?? '',
      operationStatus: map['operationStatus'] ?? 'مقررة',
      operativeNotes: map['operativeNotes'] ?? '',
      drainsInfo: map['drainsInfo'] ?? '',
      dvtProphylaxis: map['dvtProphylaxis'] ?? 'ميكانيكي + دوائي (LMWH/Heparin)',
      antibioticProphylaxis: map['antibioticProphylaxis'] ?? '',
      biopsyStatus: map['biopsyStatus'] ?? 'لا يحتاج زرع',
      histopathologyResult: map['histopathologyResult'] ?? '',
      tnmStaging: map['tnmStaging'] ?? '',
      isStarred: (map['isStarred'] == 1 || map['isStarred'] == true),
      surgicalPearls: map['surgicalPearls'] ?? '',
      finalOutcome: map['finalOutcome'] ?? 'شفاء تام',
      clavienDindoGrade: map['clavienDindoGrade'] ?? 'لا يوجد (None)',
      dischargeTreatment: map['dischargeTreatment'] ?? '',
      followUpDate: map['followUpDate'] ?? '',
      radiologyImages: parseList(map['radiologyImages']),
      labImages: parseList(map['labImages']),
      woundImages: parseList(map['woundImages']),
      biopsyImages: parseList(map['biopsyImages']),
    );
  }
}

// ==========================================
// 2. إدارة قاعدة البيانات المحلية + المزامنة السحابية مع Firebase
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surgical_board_logbook_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mrn TEXT,
        name TEXT NOT NULL,
        age TEXT,
        gender TEXT,
        phone TEXT,
        bloodGroup TEXT,
        admissionDate TEXT,
        rotation TEXT,
        consultantName TEXT,
        surgeonRole TEXT,
        operationMagnitude TEXT,
        chronicDiseases TEXT,
        allergies TEXT,
        currentMedications TEXT,
        smokingStatus TEXT,
        pastSurgeries TEXT,
        pastComplications TEXT,
        chiefComplaint TEXT,
        clinicalExam TEXT,
        labRadiologyNotes TEXT,
        diagnosis TEXT,
        plannedOperation TEXT,
        operationUrgency TEXT,
        asaScore TEXT,
        anesthesiaType TEXT,
        operationDate TEXT,
        operationStatus TEXT,
        operativeNotes TEXT,
        drainsInfo TEXT,
        dvtProphylaxis TEXT,
        antibioticProphylaxis TEXT,
        biopsyStatus TEXT,
        histopathologyResult TEXT,
        tnmStaging TEXT,
        isStarred INTEGER DEFAULT 0,
        surgicalPearls TEXT,
        finalOutcome TEXT,
        clavienDindoGrade TEXT,
        dischargeTreatment TEXT,
        followUpDate TEXT,
        radiologyImages TEXT,
        labImages TEXT,
        woundImages TEXT,
        biopsyImages TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<int> insertPatient(PatientRecord patient) async {
    final db = await instance.database;
    return await db.insert('patients', patient.toMap());
  }

  Future<List<PatientRecord>> getAllPatients() async {
    final db = await instance.database;
    final result = await db.query('patients', orderBy: 'id DESC');
    return result.map((json) => PatientRecord.fromMap(json)).toList();
  }

  Future<int> updatePatient(PatientRecord patient) async {
    final db = await instance.database;
    return await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<int> deletePatient(int id) async {
    final db = await instance.database;
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> getSetting(String key, String defaultVal) async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isEmpty) return defaultVal;
    return (res.first['value'] as String?) ?? defaultVal;
  }

  static Future<String?> pickAndSaveMedicalImage(ImageSource source, String categoryPrefix) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'medical_images'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final fileName = '${categoryPrefix}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
    final savedImage = await File(pickedFile.path).copy(p.join(mediaDir.path, fileName));
    return savedImage.path;
  }
}

// ==========================================
// خدمة الخزن السحابي المباشر عبر Firebase REST API
// ==========================================
class FirebaseCloudService {
  static String _cleanUrl(String rawUrl) {
    String u = rawUrl.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  static Future<void> uploadToFirebase({
    required String dbUrl,
    required String userSecretKey,
    required List<PatientRecord> patients,
    required Map<String, String> doctorProfile,
  }) async {
    final baseUrl = _cleanUrl(dbUrl);
    final safeKey = userSecretKey.trim().isEmpty ? 'dr_evan_default' : userSecretKey.trim();
    final endpoint = Uri.parse('$baseUrl/surgical_board_registry/$safeKey.json');

    final payload = {
      'updatedAt': DateTime.now().toIso8601String(),
      'doctorProfile': doctorProfile,
      'patientsCount': patients.length,
      'patients': patients.map((e) => e.toMap()).toList(),
    };

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.putUrl(endpoint);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل الاتصال بـ Firebase (${response.statusCode}): $responseBody');
    }
  }

  static Future<int> restoreFromFirebase({
    required String dbUrl,
    required String userSecretKey,
    required bool replaceExisting,
  }) async {
    final baseUrl = _cleanUrl(dbUrl);
    final safeKey = userSecretKey.trim().isEmpty ? 'dr_evan_default' : userSecretKey.trim();
    final endpoint = Uri.parse('$baseUrl/surgical_board_registry/$safeKey.json');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(endpoint);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر الجلب من Firebase (${response.statusCode})');
    }

    if (responseBody == 'null' || responseBody.trim().isEmpty) {
      return 0;
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return 0;

    if (decoded['doctorProfile'] is Map) {
      final prof = Map<String, dynamic>.from(decoded['doctorProfile']);
      for (var entry in prof.entries) {
        await DatabaseHelper.instance.saveSetting(entry.key, entry.value.toString());
      }
    }

    final existingPatients = await DatabaseHelper.instance.getAllPatients();
    if (replaceExisting) {
      for (var old in existingPatients) {
        if (old.id != null) await DatabaseHelper.instance.deletePatient(old.id!);
      }
    }

    int importedCount = 0;
    final rawPatients = decoded['patients'];
    if (rawPatients is List) {
      for (var item in rawPatients) {
        if (item == null) continue;
        final map = Map<String, dynamic>.from(item);
        map.remove('id');
        await DatabaseHelper.instance.insertPatient(PatientRecord.fromMap(map));
        importedCount++;
      }
    }
    return importedCount;
  }
}

// ==========================================
// 3. الهيكل الرئيسي مع الشريط السفلي الرباعي (Main Shell)
// ==========================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentTabIndex = 0;
  List<PatientRecord> _allPatients = [];
  List<PatientRecord> _filteredPatients = [];
  String _searchQuery = '';
  String _selectedFilter = 'الكل';
  bool _isLoading = true;
  bool _isAnonymized = false;
  bool _isCloudSyncing = false;

  String _residentName = 'د. إيفان إحسان';
  String _residentLevel = 'البورد في الجراحة العامة';
  String _hospitalName = 'المستشفى التعليمي';
  int _boardTargetP = 100;

  String _firebaseDbUrl = 'https://games-242da-default-rtdb.firebaseio.com';
  String _firebaseSecretCode = 'dr_evan_board_logbook';
  String _lastCloudSync = 'لم تتم المزامنة بعد';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPatients();
    final rName = await DatabaseHelper.instance.getSetting('residentName', 'د. إيفان إحسان');
    final rLevel = await DatabaseHelper.instance.getSetting('residentLevel', 'البورد في الجراحة العامة');
    final hName = await DatabaseHelper.instance.getSetting('hospitalName', 'المستشفى التعليمي');
    final targetStr = await DatabaseHelper.instance.getSetting('boardTargetP', '100');
    final fbUrl = await DatabaseHelper.instance.getSetting(
      'firebaseDbUrl',
      'https://games-242da-default-rtdb.firebaseio.com',
    );
    final fbCode = await DatabaseHelper.instance.getSetting('firebaseSecretCode', 'dr_evan_board_logbook');
    final lastSync = await DatabaseHelper.instance.getSetting('lastCloudSync', 'لم تتم المزامنة بعد');

    setState(() {
      _allPatients = data;
      _residentName = rName;
      _residentLevel = rLevel;
      _hospitalName = hName;
      _boardTargetP = int.tryParse(targetStr) ?? 100;
      _firebaseDbUrl = fbUrl;
      _firebaseSecretCode = fbCode;
      _lastCloudSync = lastSync;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    _filteredPatients = _allPatients.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = p.name.toLowerCase().contains(q) ||
          p.mrn.toLowerCase().contains(q) ||
          p.diagnosis.toLowerCase().contains(q) ||
          p.plannedOperation.toLowerCase().contains(q) ||
          p.consultantName.toLowerCase().contains(q) ||
          p.rotation.toLowerCase().contains(q);

      if (!matchesSearch) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'مقررة') return p.operationStatus == 'مقررة';
      if (_selectedFilter == 'تمت العملية') return p.operationStatus == 'تمت العملية';
      if (_selectedFilter == 'بانتظار الزرع') return p.biopsyStatus.contains('بانتظار');
      if (_selectedFilter == 'امتحان') return p.isStarred;
      return true;
    }).toList();
  }

  Future<void> _performFirebaseUpload() async {
    setState(() => _isCloudSyncing = true);
    try {
      await FirebaseCloudService.uploadToFirebase(
        dbUrl: _firebaseDbUrl,
        userSecretKey: _firebaseSecretCode,
        patients: _allPatients,
        doctorProfile: {
          'residentName': _residentName,
          'residentLevel': _residentLevel,
          'hospitalName': _hospitalName,
          'boardTargetP': _boardTargetP.toString(),
        },
      );
      final nowStr = DateTime.now().toString().substring(0, 16);
      await DatabaseHelper.instance.saveSetting('lastCloudSync', nowStr);
      setState(() => _lastCloudSync = nowStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statMintBorder,
            content: Text('☁️ تم رفع ${_allPatients.length} حالة إلى سحابة Firebase بنجاح!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('خطأ أثناء الرفع السحابي: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCloudSyncing = false);
    }
  }

  Future<void> _performFirebaseRestore({required bool replaceExisting}) async {
    setState(() => _isCloudSyncing = true);
    try {
      final count = await FirebaseCloudService.restoreFromFirebase(
        dbUrl: _firebaseDbUrl,
        userSecretKey: _firebaseSecretCode,
        replaceExisting: replaceExisting,
      );
      final nowStr = DateTime.now().toString().substring(0, 16);
      await DatabaseHelper.instance.saveSetting('lastCloudSync', nowStr);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navyPrimary,
            content: Text(count > 0
                ? '☁️ تم استرجاع $count حالة من سحابة Firebase بنجاح!'
                : 'لا توجد بيانات محفوظة تحت هذا الرمز في Firebase حالياً.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('خطأ أثناء الاستعادة من Firebase: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCloudSyncing = false);
    }
  }

  void _showBackupMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '☁️ الخزن السحابي (Firebase) والنسخ الاحتياطي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark),
              ),
              const SizedBox(height: 4),
              Text(
                'آخر مزامنة سحابية: $_lastCloudSync',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const Divider(height: 18),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statBlueBg,
                  child: Icon(Icons.cloud_upload, color: AppColors.statBlueBorder),
                ),
                title: const Text('رفع البيانات إلى سحابة Firebase الآن',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('حفظ جميع حالاتك (${_allPatients.length} مريض) في حسابك السحابي'),
                onTap: () {
                  Navigator.pop(ctx);
                  _performFirebaseUpload();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statMintBg,
                  child: Icon(Icons.cloud_download, color: AppColors.statMintBorder),
                ),
                title: const Text('استعادة البيانات من سحابة Firebase',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('جلب بياناتك المحفوظة في Firebase إلى هاتفك'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCloudRestoreConfirmDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppColors.navyPrimary),
                title: const Text('تصدير ومشاركة ملف احتياطي محلي (JSON)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportBackupJson();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore, color: AppColors.statPurpleBorder),
                title: const Text('استعادة من نص كود (JSON) منسوخ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCloudRestoreConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة من سحابة Firebase'),
        content: const Text(
          'كيف ترغب باستعادة الحالات من حسابك في Firebase؟\n\n'
          '• استبدال الكل: يمسح الموجود حالياً ويضع النسخة السحابية المطابقة.\n'
          '• دمج الحالات: يضيف الحالات السحابية فوق الحالات الموجودة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performFirebaseRestore(replaceExisting: false);
            },
            child: const Text('دمج الحالات'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performFirebaseRestore(replaceExisting: true);
            },
            child: const Text('استبدال الكل (موصى به)'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupJson() async {
    final list = _allPatients.map((e) => e.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: jsonString));
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await Printing.sharePdf(bytes: bytes, filename: 'surgical_board_backup.json');
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'الصق محتوى ملف الـ JSON الاحتياطي هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final List<dynamic> decoded = jsonDecode(controller.text);
                for (var item in decoded) {
                  final map = Map<String, dynamic>.from(item);
                  map.remove('id');
                  await DatabaseHelper.instance.insertPatient(PatientRecord.fromMap(map));
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استيراد بيانات اللوكبوك والمرضى بنجاح')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خطأ في صيغة الكود المنسوخ')),
                );
              }
            },
            child: const Text('استعادة الآن'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateLogbookConsolidationPdf() async {
    if (_filteredPatients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حالات حالياً لتصدير سجل اللوكبوك')),
      );
      return;
    }

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final list = _filteredPatients;
    final total = list.length;
    final roleP = list.where((p) => p.surgeonRole.startsWith('P')).length;
    final roleSTS = list.where((p) => p.surgeonRole.startsWith('S-TS')).length;
    final roleSTU = list.where((p) => p.surgeonRole.startsWith('S-TU')).length;
    final roleA = list.where((p) => p.surgeonRole.startsWith('A')).length;
    final emergencyCount = list.where((p) => p.operationUrgency.contains('طارئة')).length;
    final electiveCount = total - emergencyCount;

    final Map<String, Map<String, int>> opSummary = {};
    for (var p in list) {
      final opName = p.plannedOperation.trim().isEmpty ? 'غير محدد' : p.plannedOperation.trim();
      opSummary.putIfAbsent(opName, () => {'total': 0, 'P': 0, 'S': 0, 'A': 0});
      opSummary[opName]!['total'] = opSummary[opName]!['total']! + 1;
      if (p.surgeonRole.startsWith('P')) {
        opSummary[opName]!['P'] = opSummary[opName]!['P']! + 1;
      } else if (p.surgeonRole.startsWith('S')) {
        opSummary[opName]!['S'] = opSummary[opName]!['S']! + 1;
      } else {
        opSummary[opName]!['A'] = opSummary[opName]!['A']! + 1;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF08203E), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('السجل الجراحي الرسمي والتقرير الإحصائي (Surgical Logbook Consolidation)',
                    style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 13)),
                pw.SizedBox(height: 4),
                pw.Text('الطبيب المقيم: $_residentName | $_residentLevel | $_hospitalName',
                    style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 10)),
                pw.Text('تاريخ التقرير: ${DateTime.now().toString().split(' ').first} | إجمالي الحالات: $total',
                    style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 9.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('أولاً: خلاصة الأدوار الجراحية والتصنيف (Summary by Role & Urgency)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('طارئة (Emergency)', arabicBold),
                  _pdfCell('باردة (Elective)', arabicBold),
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('إشراف غير مباشر (S-TU)', arabicBold),
                  _pdfCell('إشراف مباشر (S-TS)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('المجموع الكلي', arabicBold),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell('$emergencyCount', arabicFont),
                  _pdfCell('$electiveCount', arabicFont),
                  _pdfCell('$roleA', arabicFont),
                  _pdfCell('$roleSTU', arabicFont),
                  _pdfCell('$roleSTS', arabicFont),
                  _pdfCell('$roleP', arabicBold),
                  _pdfCell('$total', arabicBold),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('ثانياً: التجميع الإحصائي حسب نوع العملية (Consolidation by Procedure)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('بإشراف (S-TS/TU)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('العدد الكلي', arabicBold),
                  _pdfCell('اسم العملية الجراحية (Procedure)', arabicBold),
                ],
              ),
              ...opSummary.entries.map((entry) {
                return pw.TableRow(
                  children: [
                    _pdfCell('${entry.value['A']}', arabicFont),
                    _pdfCell('${entry.value['S']}', arabicFont),
                    _pdfCell('${entry.value['P']}', arabicFont),
                    _pdfCell('${entry.value['total']}', arabicBold),
                    _pdfCell(entry.key, arabicFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('ثالثاً: السجل التفصيلي للحالات (Detailed Case Log)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('النتيجة', arabicBold),
                  _pdfCell('المشرف', arabicBold),
                  _pdfCell('الدور / الحجم', arabicBold),
                  _pdfCell('العملية والتشخيص', arabicBold),
                  _pdfCell('المريض', arabicBold),
                  _pdfCell('التاريخ', arabicBold),
                ],
              ),
              ...list.map((p) {
                final shortRole = p.surgeonRole.split(' ').first;
                final shortMag = p.operationMagnitude.split(' ').first;
                return pw.TableRow(
                  children: [
                    _pdfCell(p.finalOutcome, arabicFont),
                    _pdfCell(p.consultantName.isEmpty ? '-' : p.consultantName, arabicFont),
                    _pdfCell('$shortRole / $shortMag', arabicFont),
                    _pdfCell('${p.plannedOperation}\n(${p.diagnosis})', arabicFont),
                    _pdfCell('${p.displayName(_isAnonymized)}\nMRN: ${p.mrn}', arabicFont),
                    _pdfCell(p.operationDate, arabicFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الاستشاري المشرف: ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
              pw.Text('توقيع الطبيب المقيم ($_residentName): ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Surgical_Board_Logbook.pdf');
  }

  pw.Widget _pdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSurgicalHeader(),
            if (_isCloudSyncing)
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppColors.statBlueBg,
                color: AppColors.statMintBorder,
              ),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildMainDashboardTab(),
                  _buildCasesByRotationTab(),
                  _buildStatisticsAnalyticsTab(),
                  _buildSettingsProfileTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildTopSurgicalHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF061A33),
            Color(0xFF0D325E),
            Color(0xFF164A84),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'سجل البورد الجراحي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  width: 170,
                  child: CustomPaint(painter: EcgWavePainter()),
                ),
              ],
            ),
          ),
          Container(
            height: 46,
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white38,
          ),
          _buildHeaderSquareButton(
            label: 'سيمينار',
            iconWidget: Icon(
              _isAnonymized ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white,
              size: 22,
            ),
            onTap: () {
              setState(() => _isAnonymized = !_isAnonymized);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isAnonymized
                      ? 'وضع السيمينار مفعّل: تم إخفاء أسماء المرضى'
                      : 'تم إظهار الأسماء الحقيقية للمرضى'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildHeaderSquareButton(
            label: 'لوكبوك PDF',
            iconWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            onTap: _generateLogbookConsolidationPdf,
          ),
          const SizedBox(width: 8),
          _buildHeaderSquareButton(
            label: 'نسخ',
            iconWidget: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 22),
            onTap: _showBackupMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSquareButton({
    required String label,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 64,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24, child: Center(child: iconWidget)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboardTab() {
    final totalCount = _allPatients.length;
    final primarySurgeonCount = _allPatients
        .where((p) => p.surgeonRole.startsWith('P') || p.surgeonRole.startsWith('S'))
        .length;
    final pendingBiopsyCount = _allPatients.where((p) => p.biopsyStatus.contains('بانتظار')).length;
    final starredCount = _allPatients.where((p) => p.isStarred).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              Row(
                children: [
                  _buildColoredStatCard(
                    count: totalCount.toString(),
                    label: 'الحالات',
                    bgColor: AppColors.statPurpleBg,
                    bottomBorderColor: AppColors.statPurpleBorder,
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.statPurpleBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'الكل';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: primarySurgeonCount.toString(),
                    label: 'جراح P/S',
                    bgColor: AppColors.statBlueBg,
                    bottomBorderColor: AppColors.statBlueBorder,
                    icon: Icons.colorize_rounded,
                    iconColor: AppColors.statBlueBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'الكل';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: pendingBiopsyCount.toString(),
                    label: 'الزرع',
                    bgColor: AppColors.statMintBg,
                    bottomBorderColor: AppColors.statMintBorder,
                    icon: Icons.biotech_rounded,
                    iconColor: const Color(0xFF1F4E5B),
                    onTap: () => setState(() {
                      _selectedFilter = 'بانتظار الزرع';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: starredCount.toString(),
                    label: 'امتحان',
                    bgColor: AppColors.statAmberBg,
                    bottomBorderColor: AppColors.statAmberBorder,
                    icon: Icons.star_rounded,
                    iconColor: AppColors.statAmberBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'امتحان';
                      _applyFilters();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blueGrey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، العملية، التشخيص، المشرف، الروتيشن ...',
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navyPrimary, size: 24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(
                      label: 'الكل',
                      icon: Icons.grid_view_rounded,
                      iconColor: _selectedFilter == 'الكل' ? Colors.white : AppColors.navyPrimary,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'مقررة',
                      icon: Icons.calendar_month_rounded,
                      iconColor: _selectedFilter == 'مقررة' ? Colors.white : AppColors.navyPrimary,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'تمت العملية',
                      icon: Icons.check_circle_rounded,
                      iconColor: _selectedFilter == 'تمت العملية' ? Colors.white : const Color(0xFF00A86B),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'بانتظار الزرع',
                      icon: Icons.biotech_rounded,
                      iconColor: _selectedFilter == 'بانتظار الزرع' ? Colors.white : AppColors.statPurpleBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: 'امتحان',
                      icon: Icons.star_rounded,
                      iconColor: _selectedFilter == 'امتحان' ? Colors.white : AppColors.statAmberBorder,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredPatients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.medical_services_outlined, size: 56, color: Colors.blueGrey.shade200),
                      const SizedBox(height: 10),
                      const Text(
                        'لا توجد حالات مسجلة ضمن هذا التصنيف حالياً\nاضغط على زر "إضافة حالة جديدة" بالأسفل للبدء',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blueGrey, fontSize: 14.5),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredPatients.map((patient) => _buildSurgicalPatientCard(patient)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(child: Container(height: 1.2, color: Colors.blueGrey.shade200)),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientFormScreen()),
                  );
                  _loadAllData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF072549), Color(0xFF104076)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navyPrimary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: AppColors.navyDark, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'إضافة حالة جديدة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1.2, color: Colors.blueGrey.shade200)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColoredStatCard({
    required String count,
    required String label,
    required Color bgColor,
    required Color bottomBorderColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(color: bottomBorderColor, width: 4.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 4),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navyDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyPrimary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.navyPrimary : Colors.blueGrey.shade100,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.navyPrimary.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.navyDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurgicalPatientCard(PatientRecord patient) {
    final totalPhotos = patient.radiologyImages.length +
        patient.labImages.length +
        patient.woundImages.length +
        patient.biopsyImages.length;
    final shortRole = patient.surgeonRole.split(' ').first;
    final shortMag = patient.operationMagnitude.split(' ').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          right: BorderSide(color: AppColors.navyPrimary, width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDetailsScreen(
                patientId: patient.id!,
                isAnonymized: _isAnonymized,
              ),
            ),
          );
          _loadAllData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusGreenBadge(patient.operationStatus),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            patient.displayName(_isAnonymized),
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navyDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (patient.isStarred) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.roleBadgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '( $shortRole )',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${patient.rotation}   |   د. ${patient.consultantName.isEmpty ? "غير محدد" : patient.consultantName}   |   دم: ${patient.bloodGroup}',
                  style: const TextStyle(
                    color: AppColors.navyDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Colors.blueGrey.shade100),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_information_outlined, size: 19, color: AppColors.navyAccent),
                  const SizedBox(width: 6),
                  const Text(
                    'التشخيص: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.navyAccent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${patient.diagnosis} (${patient.chiefComplaint})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.colorize_rounded, size: 19, color: AppColors.navyAccent),
                  const SizedBox(width: 6),
                  const Text(
                    'العملية: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.navyAccent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${patient.plannedOperation} [$shortMag]',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBottomCardPill(
                      text: patient.finalOutcome,
                      icon: Icons.monitor_heart_rounded,
                      bgColor: AppColors.pillGreenBg,
                      textColor: AppColors.pillGreenText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildBottomCardPill(
                      text: patient.biopsyStatus.contains('بانتظار')
                          ? 'بانتظار الزرع'
                          : (patient.biopsyStatus.contains('ظهرت') ? 'ظهرت النتيجة' : 'لا يحتاج زرع'),
                      icon: Icons.biotech_rounded,
                      bgColor: AppColors.pillOrangeBg,
                      textColor: AppColors.pillOrangeText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildBottomCardPill(
                      text: '$totalPhotos صور مرفقة',
                      icon: Icons.photo_library_outlined,
                      bgColor: AppColors.pillPurpleBg,
                      textColor: AppColors.pillPurpleText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusGreenBadge(String status) {
    Color bg = AppColors.pillGreenBg;
    Color fg = const Color(0xFF00875A);
    IconData ic = Icons.check_circle_rounded;

    if (status == 'مقررة') {
      bg = AppColors.statAmberBg;
      fg = const Color(0xFFB45309);
      ic = Icons.schedule_rounded;
    } else if (status == 'مؤجلة') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      ic = Icons.pause_circle_filled_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCardPill({
    required String text,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasesByRotationTab() {
    final Map<String, List<PatientRecord>> grouped = {};
    for (var p in _allPatients) {
      final rot = p.rotation.trim().isEmpty ? 'الجراحة العامة' : p.rotation.trim();
      grouped.putIfAbsent(rot, () => []);
      grouped[rot]!.add(p);
    }

    if (grouped.isEmpty) {
      return const Center(
        child: Text('لا توجد حالات مسجلة لتصنيفها حسب الروتيشن بعد', style: TextStyle(color: Colors.blueGrey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'أرشيف الحالات مقسماً حسب الروتيشن الجراحي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark),
        ),
        const SizedBox(height: 10),
        ...grouped.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.statBlueBg,
                child: Text('${entry.value.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyPrimary)),
              ),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'جراح رئيسي (P): ${entry.value.where((e) => e.surgeonRole.startsWith("P")).length} | بإشراف (S): ${entry.value.where((e) => e.surgeonRole.startsWith("S")).length}',
                style: const TextStyle(fontSize: 12),
              ),
              children: entry.value.map((p) {
                return ListTile(
                  title: Text(p.displayName(_isAnonymized), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.plannedOperation} — ${p.diagnosis}'),
                  trailing: Text(p.operationDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailsScreen(patientId: p.id!, isAnonymized: _isAnonymized),
                      ),
                    );
                    _loadAllData();
                  },
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatisticsAnalyticsTab() {
    final total = _allPatients.length;
    final pCount = _allPatients.where((p) => p.surgeonRole.startsWith('P')).length;
    final sCount = _allPatients.where((p) => p.surgeonRole.startsWith('S')).length;
    final aCount = _allPatients.where((p) => p.surgeonRole.startsWith('A')).length;

    final complexMajor = _allPatients.where((p) => p.operationMagnitude.contains('Complex')).length;
    final major = _allPatients.where((p) => p.operationMagnitude.startsWith('Major')).length;
    final intermediate = _allPatients.where((p) => p.operationMagnitude.contains('Intermediate')).length;
    final minor = _allPatients.where((p) => p.operationMagnitude.contains('Minor')).length;

    final progress = (_boardTargetP > 0) ? (pCount / _boardTargetP).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: const Border(right: BorderSide(color: AppColors.statBlueBorder, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مؤشر إنجاز متطلبات البورد (جراح رئيسي P)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المنجز: $pCount عملية من أصل $_boardTargetP',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statBlueBorder)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: AppColors.statBlueBg,
                  color: AppColors.statBlueBorder,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('توزيع العمليات حسب دورك الجراحي (Surgeon Role)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const Divider(),
              _buildStatRowItem('P - جراح رئيسي (Performed)', pCount, total, AppColors.statBlueBorder),
              _buildStatRowItem('S - بإشراف الاستشاري (Supervised)', sCount, total, AppColors.statMintBorder),
              _buildStatRowItem('A - مساعد جراح (Assisted)', aCount, total, AppColors.statAmberBorder),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('توزيع العمليات حسب الحجم (Magnitude)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const Divider(),
              _buildStatRowItem('Complex Major (كبرى معقدة)', complexMajor, total, AppColors.statPurpleBorder),
              _buildStatRowItem('Major (كبرى)', major, total, AppColors.navyPrimary),
              _buildStatRowItem('Intermediate (متوسطة)', intermediate, total, AppColors.statMintBorder),
              _buildStatRowItem('Minor (صغرى)', minor, total, Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _generateLogbookConsolidationPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('تصدير جدول اللوكبوك الإحصائي الرسمي (PDF)',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStatRowItem(String label, int count, int total, Color color) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('$count ($pct%)', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsProfileTab() {
    final nameCtrl = TextEditingController(text: _residentName);
    final levelCtrl = TextEditingController(text: _residentLevel);
    final hospCtrl = TextEditingController(text: _hospitalName);
    final targetCtrl = TextEditingController(text: _boardTargetP.toString());
    final fbUrlCtrl = TextEditingController(text: _firebaseDbUrl);
    final fbCodeCtrl = TextEditingController(text: _firebaseSecretCode);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: const Border(right: BorderSide(color: AppColors.statMintBorder, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_done, color: AppColors.statMintBorder),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إعدادات الخزن السحابي (Firebase Realtime DB)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'آخر مزامنة ناجحة: $_lastCloudSync',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const Divider(height: 20),
              TextField(
                controller: fbUrlCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رابط قاعدة بيانات Firebase (Realtime Database URL)',
                  hintText: 'https://your-project-default-rtdb.firebaseio.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fbCodeCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الرمز السري لحسابك (لمزامنة بياناتك بين أجهزتك)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statBlueBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance.saveSetting('firebaseDbUrl', fbUrlCtrl.text.trim());
                        await DatabaseHelper.instance.saveSetting('firebaseSecretCode', fbCodeCtrl.text.trim());
                        _firebaseDbUrl = fbUrlCtrl.text.trim();
                        _firebaseSecretCode = fbCodeCtrl.text.trim();
                        await _performFirebaseUpload();
                      },
                      icon: const Icon(Icons.cloud_upload, size: 19),
                      label: const Text('حفظ ورفع للسحابة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance.saveSetting('firebaseDbUrl', fbUrlCtrl.text.trim());
                        await DatabaseHelper.instance.saveSetting('firebaseSecretCode', fbCodeCtrl.text.trim());
                        _firebaseDbUrl = fbUrlCtrl.text.trim();
                        _firebaseSecretCode = fbCodeCtrl.text.trim();
                        _showCloudRestoreConfirmDialog();
                      },
                      icon: const Icon(Icons.cloud_download, size: 19),
                      label: const Text('استعادة من السحابة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بيانات الطبيب المقيم (تظهر في تقارير الـ PDF وشهادة الخروج)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const Divider(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الطبيب المقيم', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: levelCtrl,
                decoration: const InputDecoration(labelText: 'المرحلة / الاختصاص (مثال: بورد جراحة عامة - R3)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hospCtrl,
                decoration: const InputDecoration(labelText: 'المستشفى / المركز التدريبي', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'العدد المستهدف لعمليات الجراح الرئيسي (P)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    await DatabaseHelper.instance.saveSetting('residentName', nameCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('residentLevel', levelCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('hospitalName', hospCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('boardTargetP', targetCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('firebaseDbUrl', fbUrlCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('firebaseSecretCode', fbCodeCtrl.text.trim());
                    _loadAllData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ إعدادات الطبيب والسحابة بنجاح')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ بيانات الطبيب'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBottomNavBar() {
    final items = [
      {'label': 'الرئيسية', 'icon': Icons.home_rounded},
      {'label': 'الحالات', 'icon': Icons.folder_rounded},
      {'label': 'الإحصائيات', 'icon': Icons.bar_chart_rounded},
      {'label': 'الإعدادات', 'icon': Icons.settings_rounded},
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isSelected = _currentTabIndex == i;
          final color = isSelected ? const Color(0xFF0066CC) : const Color(0xFF475569);

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentTabIndex = i),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i]['icon'] as IconData, color: color, size: 26),
                    const SizedBox(height: 3),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: isSelected ? 48 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066CC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ==========================================
// 4. شاشة إضافة وتعديل ملف المريض (مع القوالب الجراحية السريعة)
// ==========================================
class PatientFormScreen extends StatefulWidget {
  final PatientRecord? existingPatient;
  const PatientFormScreen({super.key, this.existingPatient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mrnCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _admissionDateCtrl;
  late TextEditingController _rotationCtrl;
  late TextEditingController _consultantCtrl;
  late TextEditingController _chronicCtrl;
  late TextEditingController _allergiesCtrl;
  late TextEditingController _medsCtrl;
  late TextEditingController _pastSurgeriesCtrl;
  late TextEditingController _pastCompCtrl;
  late TextEditingController _complaintCtrl;
  late TextEditingController _examCtrl;
  late TextEditingController _labNotesCtrl;
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _operationCtrl;
  late TextEditingController _opDateCtrl;
  late TextEditingController _opNotesCtrl;
  late TextEditingController _drainsCtrl;
  late TextEditingController _antibioticCtrl;
  late TextEditingController _histoResultCtrl;
  late TextEditingController _tnmCtrl;
  late TextEditingController _pearlsCtrl;
  late TextEditingController _dischargeCtrl;
  late TextEditingController _followUpCtrl;

  String _gender = 'ذكر';
  String _bloodGroup = 'O+';
  String _surgeonRole = 'P - جراح رئيسي (Performed)';
  String _opMagnitude = 'Major';
  String _smokingStatus = 'غير مدخن';
  String _urgency = 'مجدولة (باردة)';
  String _asaScore = 'ASA I';
  String _anesthesia = 'تخدير عام (GA)';
  String _opStatus = 'تمت العملية';
  String _dvtProphylaxis = 'ميكانيكي + دوائي (LMWH/Heparin)';
  String _biopsyStatus = 'بانتظار الزرع (Pending)';
  bool _isStarred = false;
  String _finalOutcome = 'شفاء تام';
  String _clavienGrade = 'لا يوجد (None)';

  List<String> _radiologyImages = [];
  List<String> _labImages = [];
  List<String> _woundImages = [];
  List<String> _biopsyImages = [];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPatient;
    final today = DateTime.now().toString().split(' ').first;

    _mrnCtrl = TextEditingController(text: p?.mrn ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ageCtrl = TextEditingController(text: p?.age ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _admissionDateCtrl = TextEditingController(text: p?.admissionDate ?? today);
    _rotationCtrl = TextEditingController(text: p?.rotation ?? 'الجراحة العامة');
    _consultantCtrl = TextEditingController(text: p?.consultantName ?? '');
    _chronicCtrl = TextEditingController(text: p?.chronicDiseases ?? '');
    _allergiesCtrl = TextEditingController(text: p?.allergies ?? '');
    _medsCtrl = TextEditingController(text: p?.currentMedications ?? '');
    _pastSurgeriesCtrl = TextEditingController(text: p?.pastSurgeries ?? '');
    _pastCompCtrl = TextEditingController(text: p?.pastComplications ?? '');
    _complaintCtrl = TextEditingController(text: p?.chiefComplaint ?? '');
    _examCtrl = TextEditingController(text: p?.clinicalExam ?? '');
    _labNotesCtrl = TextEditingController(text: p?.labRadiologyNotes ?? '');
    _diagnosisCtrl = TextEditingController(text: p?.diagnosis ?? '');
    _operationCtrl = TextEditingController(text: p?.plannedOperation ?? '');
    _opDateCtrl = TextEditingController(text: p?.operationDate ?? today);
    _opNotesCtrl = TextEditingController(text: p?.operativeNotes ?? '');
    _drainsCtrl = TextEditingController(text: p?.drainsInfo ?? '');
    _antibioticCtrl = TextEditingController(text: p?.antibioticProphylaxis ?? '');
    _histoResultCtrl = TextEditingController(text: p?.histopathologyResult ?? '');
    _tnmCtrl = TextEditingController(text: p?.tnmStaging ?? '');
    _pearlsCtrl = TextEditingController(text: p?.surgicalPearls ?? '');
    _dischargeCtrl = TextEditingController(text: p?.dischargeTreatment ?? '');
    _followUpCtrl = TextEditingController(text: p?.followUpDate ?? '');

    if (p != null) {
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      _surgeonRole = p.surgeonRole;
      _opMagnitude = p.operationMagnitude;
      _smokingStatus = p.smokingStatus;
      _urgency = p.operationUrgency;
      _asaScore = p.asaScore;
      _anesthesia = p.anesthesiaType;
      _opStatus = p.operationStatus;
      _dvtProphylaxis = p.dvtProphylaxis;
      _biopsyStatus = p.biopsyStatus;
      _isStarred = p.isStarred;
      _finalOutcome = p.finalOutcome;
      _clavienGrade = p.clavienDindoGrade;
      _radiologyImages = List<String>.from(p.radiologyImages);
      _labImages = List<String>.from(p.labImages);
      _woundImages = List<String>.from(p.woundImages);
      _biopsyImages = List<String>.from(p.biopsyImages);
    }
  }

  void _applyQuickTemplate(String title, String diag, String op, String mag, String notes) {
    setState(() {
      _diagnosisCtrl.text = diag;
      _operationCtrl.text = op;
      _opMagnitude = mag;
      _opNotesCtrl.text = notes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إدراج قالب "$title" بنجاح')),
    );
  }

  Future<void> _addPhoto(List<String> targetList, String prefix) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.navyPrimary),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.statBlueBorder),
              title: const Text('اختيار صورة من استوديو الهاتف'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.gallery, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    final record = PatientRecord(
      id: widget.existingPatient?.id,
      mrn: _mrnCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      bloodGroup: _bloodGroup,
      admissionDate: _admissionDateCtrl.text.trim(),
      rotation: _rotationCtrl.text.trim(),
      consultantName: _consultantCtrl.text.trim(),
      surgeonRole: _surgeonRole,
      operationMagnitude: _opMagnitude,
      chronicDiseases: _chronicCtrl.text.trim(),
      allergies: _allergiesCtrl.text.trim(),
      currentMedications: _medsCtrl.text.trim(),
      smokingStatus: _smokingStatus,
      pastSurgeries: _pastSurgeriesCtrl.text.trim(),
      pastComplications: _pastCompCtrl.text.trim(),
      chiefComplaint: _complaintCtrl.text.trim(),
      clinicalExam: _examCtrl.text.trim(),
      labRadiologyNotes: _labNotesCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim(),
      plannedOperation: _operationCtrl.text.trim(),
      operationUrgency: _urgency,
      asaScore: _asaScore,
      anesthesiaType: _anesthesia,
      operationDate: _opDateCtrl.text.trim(),
      operationStatus: _opStatus,
      operativeNotes: _opNotesCtrl.text.trim(),
      drainsInfo: _drainsCtrl.text.trim(),
      dvtProphylaxis: _dvtProphylaxis,
      antibioticProphylaxis: _antibioticCtrl.text.trim(),
      biopsyStatus: _biopsyStatus,
      histopathologyResult: _histoResultCtrl.text.trim(),
      tnmStaging: _tnmCtrl.text.trim(),
      isStarred: _isStarred,
      surgicalPearls: _pearlsCtrl.text.trim(),
      finalOutcome: _finalOutcome,
      clavienDindoGrade: _clavienGrade,
      dischargeTreatment: _dischargeCtrl.text.trim(),
      followUpDate: _followUpCtrl.text.trim(),
      radiologyImages: _radiologyImages,
      labImages: _labImages,
      woundImages: _woundImages,
      biopsyImages: _biopsyImages,
    );

    if (widget.existingPatient == null) {
      await DatabaseHelper.instance.insertPatient(record);
    } else {
      await DatabaseHelper.instance.updatePatient(record);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPatient == null ? 'إضافة حالة جديدة' : 'تعديل ملف المريض'),
        actions: [
          IconButton(
            icon: Icon(_isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
            onPressed: () => setState(() => _isStarred = !_isStarred),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _savePatient),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              color: AppColors.statBlueBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚡ قوالب العمليات الجاهزة (تعبئة سريعة):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyDark)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _templateChip(
                            'Lap. Cholecystectomy',
                            'التهاب المرارة الحصوي',
                            'Lap. Cholecystectomy',
                            'Major',
                            '4-port laparoscopy, Calot triangle dissected, Critical View of Safety achieved, cystic duct & artery clipped and divided.',
                          ),
                          _templateChip(
                            'Lap. Appendectomy',
                            'التهاب الزائدة الدودية الحاد',
                            'Lap. Appendectomy',
                            'Intermediate',
                            '3-port laparoscopy, inflamed appendix identified, mesoappendix controlled, base ligated with endoloop.',
                          ),
                          _templateChip(
                            'Inguinal Hernia (Mesh)',
                            'فتق مغبني',
                            'Lichtenstein Mesh Hernioplasty',
                            'Intermediate',
                            'Inguinal canal opened, sac identified and reduced, polypropylene mesh fixed to inguinal ligament and conjoint tendon.',
                          ),
                          _templateChip(
                            'Total Thyroidectomy',
                            'تضخم الغدة الدرقية متعدد العقد',
                            'Total Thyroidectomy',
                            'Complex Major',
                            'Collar incision, superior & inferior thyroid vessels ligated, bilateral RLN and parathyroids identified and preserved.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSectionCard(
              title: '1. البيانات الشخصية للمريض',
              icon: Icons.person,
              children: [
                _buildTextField(_nameCtrl, 'اسم المريض الرباعي *', required: true),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_ageCtrl, 'العمر *', required: true, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_mrnCtrl, 'رقم الملف (MRN)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('الجنس', _gender, ['ذكر', 'أنثى'], (v) => setState(() => _gender = v!))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'فصيلة الدم',
                        _bloodGroup,
                        ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                        (v) => setState(() => _bloodGroup = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_phoneCtrl, 'رقم الهاتف')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_admissionDateCtrl, 'تاريخ الدخول')),
                  ],
                ),
              ],
            ),
            _buildSectionCard(
              title: '2. بيانات اللوكبوك الجراحي (Board Logbook)',
              icon: Icons.badge,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(_rotationCtrl, 'الروتيشن (الجراحة العامة، أطفال...)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_consultantCtrl, 'الاختصاصي المشرف (مثال: سامر)')),
                  ],
                ),
                _buildDropdown(
                  'دورك في العملية (Surgeon Role)',
                  _surgeonRole,
                  [
                    'P - جراح رئيسي (Performed)',
                    'S-TS - بإشراف مباشر (المشرف معقم)',
                    'S-TU - بإشراف غير مباشر (المشرف بالصالة)',
                    'A - مساعد جراح (Assisted)',
                  ],
                  (v) => setState(() => _surgeonRole = v!),
                ),
                _buildDropdown(
                  'حجم وتصنيف العملية (Magnitude)',
                  _opMagnitude,
                  ['Complex Major', 'Major', 'Intermediate', 'Minor'],
                  (v) => setState(() => _opMagnitude = v!),
                ),
              ],
            ),
            _buildSectionCard(
              title: '3. التاريخ المرضي والجراحات السابقة',
              icon: Icons.history_edu,
              children: [
                _buildTextField(_chronicCtrl, 'الأمراض المزمنة (سكري، ضغط، قلب، ربو...)', maxLines: 2),
                _buildTextField(_allergiesCtrl, 'الحساسية الدوائية'),
                _buildTextField(_medsCtrl, 'الأدوية المستمرة ومميعات الدم', maxLines: 2),
                _buildDropdown('التدخين', _smokingStatus, ['غير مدخن', 'مدخن حالي', 'مدخن سابق'], (v) => setState(() => _smokingStatus = v!)),
                _buildTextField(_pastSurgeriesCtrl, 'العمليات الجراحية السابقة', maxLines: 2),
                _buildTextField(_pastCompCtrl, 'مضاعفات جراحية أو تخديرية سابقة'),
              ],
            ),
            _buildSectionCard(
              title: '4. مما يعاني حالياً والتشخيص السريري',
              icon: Icons.medical_information,
              children: [
                _buildTextField(_complaintCtrl, 'الشكوى الرئيسية (مما يعاني حالياً) *', required: true, maxLines: 2),
                _buildTextField(_examCtrl, 'الفحص السريري والعلامات الحيوية', maxLines: 2),
                _buildTextField(_labNotesCtrl, 'نتائج التحاليل والأشعة والسونار/المفراس', maxLines: 2),
                _buildTextField(_diagnosisCtrl, 'التشخيص النهائي (Diagnosis) *', required: true),
              ],
            ),
            _buildSectionCard(
              title: '5. تفاصيل العملية الجراحية المقررة',
              icon: Icons.local_hospital,
              children: [
                _buildTextField(_operationCtrl, 'اسم ونوع العملية المقررة *', required: true),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'تصنيف العملية',
                        _urgency,
                        ['مجدولة (باردة)', 'طارئة (Emergency)', 'مستعجلة (Urgent)'],
                        (v) => setState(() => _urgency = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'حالة العملية',
                        _opStatus,
                        ['تمت العملية', 'مقررة', 'مؤجلة'],
                        (v) => setState(() => _opStatus = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'تصنيف ASA',
                        _asaScore,
                        ['ASA I', 'ASA II', 'ASA III', 'ASA IV', 'ASA V'],
                        (v) => setState(() => _asaScore = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'نوع التخدير',
                        _anesthesia,
                        ['تخدير عام (GA)', 'تخدير نصفي (Spinal)', 'تخدير موضعي (Local)'],
                        (v) => setState(() => _anesthesia = v!),
                      ),
                    ),
                  ],
                ),
                _buildTextField(_opDateCtrl, 'تاريخ العملية'),
                _buildTextField(_opNotesCtrl, 'تفاصيل وخطوات العملية (Operative Notes)', maxLines: 3),
              ],
            ),
            _buildSectionCard(
              title: '6. متابعة الردهة، الدرينات، والوقاية',
              icon: Icons.vaccines,
              children: [
                _buildTextField(_drainsCtrl, 'الدرينات والصوندات (النوع، العدد، المخرجات اليومية)', maxLines: 2),
                _buildDropdown(
                  'الوقاية الخثرية (DVT Prophylaxis)',
                  _dvtProphylaxis,
                  [
                    'ميكانيكي + دوائي (LMWH/Heparin)',
                    'دوائي فقط (Clexane / Heparin)',
                    'ميكانيكي فقط',
                    'لا يحتاج (خطورة منخفضة)',
                  ],
                  (v) => setState(() => _dvtProphylaxis = v!),
                ),
                _buildTextField(_antibioticCtrl, 'خطة الصادات الحيوية (Antibiotic Prophylaxis)'),
              ],
            ),
            _buildSectionCard(
              title: '7. متابعة الزرع النسيجي والأورام (Histopathology)',
              icon: Icons.biotech,
              children: [
                _buildDropdown(
                  'حالة الزرع النسيجي',
                  _biopsyStatus,
                  ['بانتظار الزرع (Pending)', 'ظهرت النتيجة (Completed)', 'لا يحتاج زرع'],
                  (v) => setState(() => _biopsyStatus = v!),
                ),
                _buildTextField(_histoResultCtrl, 'نتيجة الزرع النسيجي وحالة الحواف (Margins)', maxLines: 2),
                _buildTextField(_tnmCtrl, 'تصنيف الأورام (TNM Staging) وقرار الـ MDT'),
              ],
            ),
            _buildSectionCard(
              title: '8. ملاحظات البورد والامتحان (Surgical Pearls)',
              icon: Icons.school,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تمييز كحالة مهمة للامتحان (⭐ Starred Case)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: _isStarred,
                  onChanged: (v) => setState(() => _isStarred = v),
                ),
                _buildTextField(_pearlsCtrl, 'الملاحظات التشريحية والدروس الجراحية المستفادة', maxLines: 3),
              ],
            ),
            _buildSectionCard(
              title: '9. الأرشيف الصوري الطبي (4 أقسام)',
              icon: Icons.camera_enhance,
              children: [
                _buildMediaPickerSection('صور الأشعة والمفراس والرنين', _radiologyImages, 'xray'),
                const Divider(),
                _buildMediaPickerSection('صور التحاليل المختبرية والتقارير', _labImages, 'lab'),
                const Divider(),
                _buildMediaPickerSection('صور الجرح والعملية (قبل/أثناء/بعد)', _woundImages, 'wound'),
                const Divider(),
                _buildMediaPickerSection('صور تقرير الزرع النسيجي (Biopsy)', _biopsyImages, 'biopsy'),
              ],
            ),
            _buildSectionCard(
              title: '10. النتيجة النهائية وخطة الخروج',
              icon: Icons.fact_check,
              children: [
                _buildDropdown(
                  'النتيجة النهائية للمريض',
                  _finalOutcome,
                  ['شفاء تام', 'تحسن مستمر', 'قيد المتابعة', 'حدوث مضاعفات', 'تحويل لمركز تخصصي', 'وفاة'],
                  (v) => setState(() => _finalOutcome = v!),
                ),
                _buildDropdown(
                  'تصنيف المضاعفات (Clavien-Dindo)',
                  _clavienGrade,
                  ['لا يوجد (None)', 'Grade I', 'Grade II', 'Grade IIIa', 'Grade IIIb', 'Grade IVa', 'Grade IVb', 'Grade V'],
                  (v) => setState(() => _clavienGrade = v!),
                ),
                _buildTextField(_dischargeCtrl, 'علاج الخروج وتوصيات العناية بالجرح', maxLines: 2),
                _buildTextField(_followUpCtrl, 'موعد المراجعة القادم ورفع الخيوط'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _savePatient,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حفظ الحالة في سجل البورد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _templateChip(String label, String diag, String op, String mag, String notes) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ActionChip(
        backgroundColor: Colors.white,
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyPrimary)),
        onPressed: () => _applyQuickTemplate(label, diag, op, mag, notes),
      ),
    );
  }

  Widget _buildMediaPickerSection(String label, List<String> imagesList, String prefix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            TextButton.icon(
              onPressed: () => _addPhoto(imagesList, prefix),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('إرفاق صورة'),
            ),
          ],
        ),
        if (imagesList.isEmpty)
          const Text('لا توجد صور مرفقة في هذا القسم', style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imagesList.length,
              itemBuilder: (ctx, i) {
                final path = imagesList[i];
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 6),
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: File(path).existsSync()
                            ? Image.file(File(path), fit: BoxFit.cover)
                            : const Icon(Icons.broken_image),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => imagesList.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.navyPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final safeValue = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ==========================================
// 5. شاشة عرض ملف المريض التفصيلي + شهادة الخروج + المقارنة البصرية
// ==========================================
class PatientDetailsScreen extends StatefulWidget {
  final int patientId;
  final bool isAnonymized;
  const PatientDetailsScreen({super.key, required this.patientId, this.isAnonymized = false});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  PatientRecord? _patient;
  late bool _anonymized;

  @override
  void initState() {
    super.initState();
    _anonymized = widget.isAnonymized;
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    final all = await DatabaseHelper.instance.getAllPatients();
    try {
      final found = all.firstWhere((p) => p.id == widget.patientId);
      setState(() => _patient = found);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleStar() async {
    if (_patient == null) return;
    final p = _patient!;
    final updated = PatientRecord.fromMap({
      ...p.toMap(),
      'isStarred': p.isStarred ? 0 : 1,
    });
    await DatabaseHelper.instance.updatePatient(updated);
    _loadPatient();
  }

  Future<void> _quickAddImage(String category) async {
    if (_patient == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.navyPrimary),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.statBlueBorder),
              title: const Text('اختيار من استوديو الهاتف'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.gallery, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewImagePath(String category, String path) async {
    final p = _patient!;
    final rad = List<String>.from(p.radiologyImages);
    final lab = List<String>.from(p.labImages);
    final wound = List<String>.from(p.woundImages);
    final biopsy = List<String>.from(p.biopsyImages);

    if (category == 'xray') rad.add(path);
    if (category == 'lab') lab.add(path);
    if (category == 'wound') wound.add(path);
    if (category == 'biopsy') biopsy.add(path);

    final updated = PatientRecord.fromMap({
      ...p.toMap(),
      'radiologyImages': jsonEncode(rad),
      'labImages': jsonEncode(lab),
      'woundImages': jsonEncode(wound),
      'biopsyImages': jsonEncode(biopsy),
    });

    await DatabaseHelper.instance.updatePatient(updated);
    _loadPatient();
  }

  void _openFullScreenImage(String imagePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  void _openVisualComparisonTool() {
    if (_patient == null) return;
    final p = _patient!;
    final List> allImgs = [
      ...p.woundImages.map((e) => {'path': e, 'cat': 'جرح وعملية'}),
      ...p.radiologyImages.map((e) => {'path': e, 'cat': 'أشعة ومفراس'}),
      ...p.labImages.map((e) => {'path': e, 'cat': 'تحاليل'}),
      ...p.biopsyImages.map((e) => {'path': e, 'cat': 'زرع نسيجي'}),
    ];

    if (allImgs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إرفاق صورتين على الأقل داخل ملف المريض لتشغيل أداة المقارنة البصرية (قبل / بعد)'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualComparisonScreen(
          patientName: p.displayName(_anonymized),
          images: allImgs,
        ),
      ),
    );
  }

  Future<void> _generateAndSharePdf() async {
    if (_patient == null) return;
    final p = _patient!;
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pw.Widget buildPdfRow(String label, String val) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Expanded(child: pw.Text(val.isEmpty ? '-' : val, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: arabicFont, fontSize: 10.5))),
            pw.SizedBox(width: 8),
            pw.Text(label, style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFF0D3562))),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF08203E), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('التاريخ: ${p.admissionDate}', style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 11)),
                pw.Text('تقرير حالة سريرية وجراحية (Case Report)', style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 15)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          buildPdfRow('المريض:', '${p.displayName(_anonymized)} (${p.age} سنة - ${p.gender})'),
          buildPdfRow('رقم الملف وفصيلة الدم:', 'MRN: ${p.mrn} | فصيلة الدم: ${p.bloodGroup}'),
          buildPdfRow('الروتيشن والمشرف:', '${p.rotation} | الإشراف: د. ${p.consultantName}'),
          buildPdfRow('دور الجراح وحجم العملية:', '${p.surgeonRole} | ${p.operationMagnitude}'),
          pw.Divider(),
          buildPdfRow('الأمراض المزمنة والأدوية:', '${p.chronicDiseases} | الأدوية: ${p.currentMedications}'),
          buildPdfRow('العمليات الجراحية السابقة:', p.pastSurgeries),
          pw.Divider(),
          buildPdfRow('الشكوى الرئيسية:', p.chiefComplaint),
          buildPdfRow('الفحص السريري والتحاليل:', '${p.clinicalExam} | ${p.labRadiologyNotes}'),
          buildPdfRow('التشخيص النهائي:', p.diagnosis),
          pw.Divider(),
          buildPdfRow('العملية المجراة:', '${p.plannedOperation} (${p.operationUrgency})'),
          buildPdfRow('التخدير وتاريخ العملية:', '${p.anesthesiaType} (${p.asaScore}) - التاريخ: ${p.operationDate}'),
          buildPdfRow('ملاحظات العملية (Operative Notes):', p.operativeNotes),
          buildPdfRow('الدرينات والوقاية:', 'الدرينات: ${p.drainsInfo} | الوقاية: ${p.dvtProphylaxis}'),
          pw.Divider(),
          buildPdfRow('الزرع النسيجي و TNM:', '${p.biopsyStatus} - ${p.histopathologyResult} (${p.tnmStaging})'),
          buildPdfRow('ملاحظات البورد (Surgical Pearls):', p.surgicalPearls),
          buildPdfRow('النتيجة النهائية:', '${p.finalOutcome} (المضاعفات: ${p.clavienDindoGrade})'),
          buildPdfRow('خطة الخروج والمراجعة:', '${p.dischargeTreatment} | المراجعة: ${p.followUpDate}'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Case_${p.mrn.isEmpty ? p.id : p.mrn}.pdf');
  }

  Future<void> _generateDischargeCertificatePdf() async {
    if (_patient == null) return;
    final p = _patient!;
    final rName = await DatabaseHelper.instance.getSetting('residentName', 'د. إيفان إحسان');
    final rLevel = await DatabaseHelper.instance.getSetting('residentLevel', 'البورد في الجراحة العامة');
    final hName = await DatabaseHelper.instance.getSetting('hospitalName', 'المستشفى التعليمي');

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pw.Widget infoBox(String title, String content, {PdfColor? bgColor}) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor ?? PdfColor.fromInt(0xFFF5F7FA),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(title, style: pw.TextStyle(font: arabicBold, fontSize: 11.5, color: PdfColor.fromInt(0xFF08203E))),
            pw.SizedBox(height: 4),
            pw.Text(
              content.trim().isEmpty ? 'حسب إرشادات الطبيب المعالج' : content,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: arabicFont, fontSize: 11),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0D3562),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(hName, style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 12)),
                    pw.Text('قسم: ${p.rotation}', style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 10)),
                    pw.Text('تاريخ الإصدار: ${DateTime.now().toString().split(' ').first}',
                        style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 9.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('شهادة خروج مريض وخطة العلاج',
                        style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 16)),
                    pw.Text('Surgical Discharge Summary & Prescription',
                        style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFF0D3562), width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('رقم الملف (MRN): ${p.mrn.isEmpty ? "-" : p.mrn}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                    pw.Text('العمر / الجنس: ${p.age} سنة - ${p.gender}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                    pw.Text('اسم المريض: ${p.name}', style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('حالة الخروج: ${p.finalOutcome}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFF0D6832))),
                    pw.Text('تاريخ العملية: ${p.operationDate}', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                    pw.Text('تاريخ الدخول: ${p.admissionDate}', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          infoBox('التشخيص الطبي النهائي (Final Diagnosis):', p.diagnosis, bgColor: PdfColors.blue50),
          infoBox('التداخل الجراحي الذي أُجري للمريض (Procedure Performed):',
              '${p.plannedOperation} — (${p.anesthesiaType})', bgColor: PdfColors.blue50),
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F5E9),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF2E7D32), width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('علاج الخروج وتوصيات العناية بالجرح (Discharge Medications & Wound Care):',
                    style: pw.TextStyle(font: arabicBold, fontSize: 12, color: PdfColor.fromInt(0xFF1B5E20))),
                pw.Divider(),
                pw.Text(
                  p.dischargeTreatment.trim().isEmpty
                      ? '1. الالتزام بمواعيد المضادات الحيوية والمسكنات الموصوفة.\n2. الحفاظ على نظافة وجفاف الجرح وتبديل الضماد حسب التعليمات.'
                      : p.dischargeTreatment,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: arabicFont, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (p.drainsInfo.trim().isNotEmpty)
            infoBox('تعليمات متابعة الدرينات / الصوندات (Drains Care):', p.drainsInfo),
          infoBox(
            'موعد المراجعة القادم ورفع الخيوط / متابعة الزرع النسيجي:',
            'موعد المراجعة: ${p.followUpDate.isEmpty ? "بعد أسبوع واحد في العيادة الاستشارية" : p.followUpDate}   |   حالة الزرع النسيجي: ${p.biopsyStatus}',
            bgColor: PdfColor.fromInt(0xFFFFF8E1),
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFEBEE),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE53935)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('علامات تستوجب مراجعة الطوارئ أو الاتصال بالطبيب فوراً (Warning Signs):',
                    style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFFB71C1C))),
                pw.SizedBox(height: 3),
                pw.Text(
                  '• ارتفاع شديد في درجة الحرارة أو قشعريرة.\n'
                  '• احمرار متزايد، تورم، أو خروج إفرازات/نزف مستمر من موضع الجرح.\n'
                  '• ألم شديد لا يستجيب للمسكنات، أو تقيؤ مستمر، أو ضيق في التنفس.',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: arabicFont, fontSize: 9.5, color: PdfColor.fromInt(0xFFB71C1C)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('الاختصاصي المشرف', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                  pw.Text('د. ${p.consultantName.isEmpty ? "___________________" : p.consultantName}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('الطبيب المعالج ($rLevel)', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                  pw.Text('$rName — التوقيع: ________________', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Discharge_${p.name}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _patient!;
    final totalImagesCount = p.radiologyImages.length +
        p.labImages.length +
        p.woundImages.length +
        p.biopsyImages.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName(_anonymized)),
        actions: [
          IconButton(
            icon: Icon(p.isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
            tooltip: 'تمييز للامتحان',
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: const Icon(Icons.compare, color: Colors.cyanAccent),
            tooltip: 'المقارنة البصرية (قبل / بعد)',
            onPressed: _openVisualComparisonTool,
          ),
          IconButton(
            icon: const Icon(Icons.fact_check, color: Colors.greenAccent),
            tooltip: 'شهادة خروج المريض (Discharge PDF)',
            onPressed: _generateDischargeCertificatePdf,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تقرير الحالة الكامل (Case PDF)',
            onPressed: _generateAndSharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل الملف',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PatientFormScreen(existingPatient: p)),
              );
              _loadPatient();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف سجل المريض'),
                  content: const Text('هل أنت متأكد من حذف هذا السجل نهائياً؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseHelper.instance.deletePatient(p.id!);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: AppColors.navyPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName(_anonymized),
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(p.operationStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: AppColors.pillGreenBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'العمر: ${p.age} سنة | ${p.gender} | دم: ${p.bloodGroup} | ملف: ${p.mrn}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (!_anonymized)
                    Text(
                      'هاتف: ${p.phone} | تاريخ الدخول: ${p.admissionDate}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  const Divider(color: Colors.white24, height: 16),
                  Text(
                    'الروتيشن: ${p.rotation} | المشرف: د. ${p.consultantName.isEmpty ? "غير محدد" : p.consultantName}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'الدور: ${p.surgeonRole} | الحجم: ${p.operationMagnitude}',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statMintBorder,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _generateDischargeCertificatePdf,
                    icon: const Icon(Icons.fact_check, size: 19),
                    label: const Text('شهادة خروج المريض PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statPurpleBorder,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _openVisualComparisonTool,
                    icon: const Icon(Icons.compare, size: 19),
                    label: Text('مقارنة بصرية ($totalImagesCount صور)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
          _buildGalleryCard('صور الأشعة والمفراس والرنين (Radiology)', p.radiologyImages, 'xray', Icons.scanner),
          _buildGalleryCard('صور التحاليل المختبرية (Lab Results)', p.labImages, 'lab', Icons.biotech),
          _buildGalleryCard('صور الجرح والعملية (Wound & Intra-Op)', p.woundImages, 'wound', Icons.healing),
          _buildGalleryCard('صور تقرير الزرع النسيجي (Histopathology)', p.biopsyImages, 'biopsy', Icons.science),
          if (p.surgicalPearls.isNotEmpty || p.isStarred)
            Card(
              color: AppColors.statAmberBg,
              margin: const EdgeInsets.only(top: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('ملاحظات البورد والامتحان (Surgical Pearls & Viva)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.brown)),
                      ],
                    ),
                    const Divider(),
                    Text(p.surgicalPearls.isEmpty ? 'حالة مميزة للمراجعة الامتحانية' : p.surgicalPearls,
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          _buildDetailsCard('الزرع النسيجي والأورام (Histopathology & TNM)', [
            _item('حالة الزرع النسيجي:', p.biopsyStatus),
            _item('نتيجة الزرع والحواف (Margins):', p.histopathologyResult),
            _item('تصنيف TNM وقرار اللجان:', p.tnmStaging),
          ]),
          _buildDetailsCard('الشكوى الحالية والتشخيص', [
            _item('مما يعاني حالياً (الشكوى):', p.chiefComplaint),
            _item('الفحص السريري:', p.clinicalExam),
            _item('ملاحظات التحاليل والأشعة:', p.labRadiologyNotes),
            _item('التشخيص النهائي:', p.diagnosis),
          ]),
          _buildDetailsCard('العملية الجراحية ومتابعة الردهة', [
            _item('اسم ونوع العملية:', p.plannedOperation),
            _item('التصنيف والحالة:', '${p.operationUrgency} | الحالة: ${p.operationStatus}'),
            _item('التخدير وتصنيف ASA:', '${p.anesthesiaType} (${p.asaScore})'),
            _item('تاريخ العملية:', p.operationDate),
            _item('تفاصيل العملية (Operative Notes):', p.operativeNotes),
            _item('متابعة الدرينات (Drains):', p.drainsInfo),
            _item('الوقاية الخثرية (DVT Prophylaxis):', p.dvtProphylaxis),
            _item('الصادات الحيوية (Antibiotics):', p.antibioticProphylaxis),
          ]),
          _buildDetailsCard('التاريخ المرضي والجراحي السابق', [
            _item('الأمراض المزمنة:', p.chronicDiseases),
            _item('الحساسية الدوائية:', p.allergies),
            _item('الأدوية المستمرة:', p.currentMedications),
            _item('التدخين:', p.smokingStatus),
            _item('العمليات الجراحية السابقة:', p.pastSurgeries),
            _item('مضاعفات سابقة:', p.pastComplications),
          ]),
          _buildDetailsCard('النتيجة النهائية والمتابعة', [
            _item('النتيجة النهائية:', p.finalOutcome),
            _item('تصنيف المضاعفات (Clavien-Dindo):', p.clavienDindoGrade),
            _item('علاج الخروج وتوصيات الجرح:', p.dischargeTreatment),
            _item('موعد المراجعة القادم:', p.followUpDate),
          ]),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(String title, List<String> paths, String categoryKey, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.navyPrimary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _quickAddImage(categoryKey),
                  icon: const Icon(Icons.add_a_photo, size: 17),
                  label: const Text('إضافة صورة'),
                ),
              ],
            ),
            if (paths.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('لا توجد صور مرفقة — اضغط "إضافة صورة" للتصوير أو الاختيار من الاستوديو',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  itemBuilder: (ctx, i) {
                    final imgPath = paths[i];
                    return GestureDetector(
                      onTap: () => _openFullScreenImage(imgPath, title),
                      child: Container(
                        margin: const EdgeInsets.only(left: 10, top: 6),
                        width: 105,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: File(imgPath).existsSync()
                              ? Image.file(File(imgPath), fit: BoxFit.cover)
                              : const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(String sectionTitle, List<Widget> items) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sectionTitle, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navyPrimary)),
          Expanded(child: Text(val.isEmpty ? 'غير مسجل' : val, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

// ==========================================
// 6. شاشة المقارنة البصرية التفاعلية (قبل / بعد العملية - Before & After)
// ==========================================
class VisualComparisonScreen extends StatefulWidget {
  final String patientName;
  final List> images;

  const VisualComparisonScreen({
    super.key,
    required this.patientName,
    required this.images,
  });

  @override
  State<VisualComparisonScreen> createState() => _VisualComparisonScreenState();
}

class _VisualComparisonScreenState extends State<VisualComparisonScreen> {
  int _beforeIndex = 0;
  int _afterIndex = 1;
  bool _isSliderMode = true;
  double _sliderPosition = 0.5;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _beforeIndex = 0;
      _afterIndex = widget.images.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final beforeImg = widget.images[_beforeIndex];
    final afterImg = widget.images[_afterIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('مقارنة بصرية: ${widget.patientName}', style: const TextStyle(fontSize: 15.5)),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
            onPressed: () => setState(() => _isSliderMode = !_isSliderMode),
            icon: Icon(_isSliderMode ? Icons.grid_view_rounded : Icons.compare),
            label: Text(_isSliderMode ? 'عرض مزدوج' : 'شريط منزلق'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isSliderMode
                  ? _buildInteractiveSliderView(beforeImg['path']!, afterImg['path']!)
                  : _buildSideBySideView(beforeImg['path']!, afterImg['path']!),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF122338),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnailSelectorRow(
                  title: '1. اختر الصورة الأولى (قبل العملية / Pre-Op):',
                  selectedIndex: _beforeIndex,
                  badgeColor: Colors.orange,
                  onSelect: (idx) => setState(() => _beforeIndex = idx),
                ),
                const SizedBox(height: 10),
                _buildThumbnailSelectorRow(
                  title: '2. اختر الصورة الثانية (بعد العملية / Post-Op):',
                  selectedIndex: _afterIndex,
                  badgeColor: AppColors.statMintBorder,
                  onSelect: (idx) => setState(() => _afterIndex = idx),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSliderView(String beforePath, String afterPath) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final splitX = maxW * _sliderPosition;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition = (details.localPosition.dx / maxW).clamp(0.05, 0.95);
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: File(afterPath).existsSync()
                      ? Image.file(File(afterPath), fit: BoxFit.contain)
                      : const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                ),
                ClipRect(
                  clipper: _HorizontalSplitClipper(splitX),
                  child: Container(
                    color: Colors.black,
                    child: File(beforePath).existsSync()
                        ? Image.file(File(beforePath), fit: BoxFit.contain)
                        : const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                  ),
                ),
                Positioned(
                  left: splitX - 18,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 36,
                    height: maxH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 2.5, color: Colors.white),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.navyPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.compare, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _overlayLabel('قبل (Pre-Op)', Colors.orange.shade800),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _overlayLabel('بعد (Post-Op)', AppColors.statMintBorder),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideBySideView(String beforePath, String afterPath) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: File(beforePath).existsSync()
                        ? Image.file(File(beforePath), fit: BoxFit.contain)
                        : const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _overlayLabel('قبل (Pre-Op)', Colors.orange.shade800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: File(afterPath).existsSync()
                        ? Image.file(File(afterPath), fit: BoxFit.contain)
                        : const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _overlayLabel('بعد (Post-Op)', AppColors.statMintBorder)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _overlayLabel(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.88), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildThumbnailSelectorRow({
    required String title,
    required int selectedIndex,
    required Color badgeColor,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 66,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            itemBuilder: (ctx, i) {
              final item = widget.images[i];
              final isSelected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 66,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? badgeColor : Colors.white24,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        File(item['path']!).existsSync()
                            ? Image.file(File(item['path']!), fit: BoxFit.cover)
                            : const Icon(Icons.broken_image, color: Colors.white),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              item['cat']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 8.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitWidth;
  _HorizontalSplitClipper(this.splitWidth);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, splitWidth, size.height);

  @override
  bool shouldReclip(covariant _HorizontalSplitClipper oldClipper) => oldClipper.splitWidth != splitWidth;
}
