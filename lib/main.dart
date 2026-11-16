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
// رسام خط نبض القلب (ECG Wave Painter)
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
// 1. نموذج بيانات المريض (Patient Model)
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

  // حقول الطوارئ والإصابات الجديدة (Trauma)
  final String isTraumaCase; // نعم / لا
  final String gcsScore; // 3 - 15
  final String traumaType; // نافذة / كليلة
  final String traumaAction; // استكشاف عاجل / إنعاش

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

  // بنك أسئلة الـ Viva وحالات الامتحان
  final String vivaQuestion;
  final String vivaAnswerReference;

  // المراجع الطبية الموثقة للحالة
  final String guidelineNotes;

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
    required this.isTraumaCase,
    required this.gcsScore,
    required this.traumaType,
    required this.traumaAction,
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
    required this.vivaQuestion,
    required this.vivaAnswerReference,
    required this.guidelineNotes,
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
      'isTraumaCase': isTraumaCase,
      'gcsScore': gcsScore,
      'traumaType': traumaType,
      'traumaAction': traumaAction,
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
      'vivaQuestion': vivaQuestion,
      'vivaAnswerReference': vivaAnswerReference,
      'guidelineNotes': guidelineNotes,
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
      isTraumaCase: map['isTraumaCase'] ?? 'لا',
      gcsScore: map['gcsScore'] ?? '15',
      traumaType: map['traumaType'] ?? 'إصابة كليلة (Blunt)',
      traumaAction: map['traumaAction'] ?? 'استقرار بالردهة',
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
      vivaQuestion: map['vivaQuestion'] ?? '',
      vivaAnswerReference: map['vivaAnswerReference'] ?? '',
      guidelineNotes: map['guidelineNotes'] ?? '',
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
// 2. إدارة قاعدة البيانات المحلية (SQLite)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surgical_board_logbook_v4.db');
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
        isTraumaCase TEXT,
        gcsScore TEXT,
        traumaType TEXT,
        traumaAction TEXT,
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
        vivaQuestion TEXT,
        vivaAnswerReference TEXT,
        guidelineNotes TEXT,
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
// 3. الهيكل الرئيسي مع الشريط السفلي الرباعي
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

  String _residentName = 'د. إيفان إحسان';
  String _residentLevel = 'البورد في الجراحة العامة';
  String _hospitalName = 'المستشفى التعليمي';
  int _boardTargetP = 100;

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

    setState(() {
      _allPatients = data;
      _residentName = rName;
      _residentLevel = rLevel;
      _hospitalName = hName;
      _boardTargetP = int.tryParse(targetStr) ?? 100;
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
      if (_selectedFilter == 'حوادث طوارئ 🚨') return p.isTraumaCase == 'نعم';
      if (_selectedFilter == 'اسئلة Viva 💡') return p.vivaQuestion.isNotEmpty;
      if (_selectedFilter == 'امتحان') return p.isStarred;
      return true;
    }).toList();
  }

  void _showBackupMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('النسخ الاحتياطي واستعادة البيانات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppColors.navyPrimary),
                title: const Text('تصدير ومشاركة نسخة احتياطية (JSON Backup)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportBackupJson();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore, color: AppColors.statMintBorder),
                title: const Text('استعادة نسخة احتياطية سابقة'),
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
                    const SnackBar(content: Text('تم استيراد بيانات اللوكبوك بنجاح')),
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
          pw.Text('أولاً: خلاصة الأدوار الجراحية والتصنيف', style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('طارئة', arabicBold),
                  _pdfCell('باردة', arabicBold),
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('إشراف (S-TU)', arabicBold),
                  _pdfCell('إشراف (S-TS)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('المجموع', arabicBold),
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
          pw.Text('ثانياً: التجميع الإحصائي حسب نوع العملية', style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('بإشراف (S)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('العدد', arabicBold),
                  _pdfCell('اسم العملية الجراحية', arabicBold),
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
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الاستشاري المشرف: ___________________', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
              pw.Text('توقيع الطبيب المقيم ($_residentName): ___________________', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
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
      child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 8.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSurgicalHeader(),
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
          colors: [Color(0xFF061A33), Color(0xFF0D325E), Color(0xFF164A84)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('سجل البورد الجراحي',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  width: 170,
                  child: CustomPaint(painter: EcgWavePainter()),
                ),
              ],
            ),
          ),
          Container(height: 46, width: 1.5, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white38),
          _buildHeaderSquareButton(
            label: 'سيمينار',
            iconWidget: Icon(
              _isAnonymized ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white,
              size: 22,
            ),
            onTap: () {
              setState(() => _isAnonymized = !_isAnonymized);
            },
          ),
          const SizedBox(width: 8),
          _buildHeaderSquareButton(
            label: 'لوكبوك PDF',
            iconWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(5)),
              child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboardTab() {
    final totalCount = _allPatients.length;
    final primarySurgeonCount = _allPatients.where((p) => p.surgeonRole.startsWith('P') || p.surgeonRole.startsWith('S')).length;
    final traumaCount = _allPatients.where((p) => p.isTraumaCase == 'نعم').length;
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
                    onTap: () => setState(() { _selectedFilter = 'الكل'; _applyFilters(); }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: primarySurgeonCount.toString(),
                    label: 'جراح P/S',
                    bgColor: AppColors.statBlueBg,
                    bottomBorderColor: AppColors.statBlueBorder,
                    icon: Icons.colorize_rounded,
                    iconColor: AppColors.statBlueBorder,
                    onTap: () => setState(() { _selectedFilter = 'الكل'; _applyFilters(); }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: traumaCount.toString(),
                    label: 'طوارئ 🚨',
                    bgColor: AppColors.statMintBg,
                    bottomBorderColor: AppColors.statMintBorder,
                    icon: Icons.local_hospital_rounded,
                    iconColor: const Color(0xFFC53030),
                    onTap: () => setState(() { _selectedFilter = 'حوادث طوارئ 🚨'; _applyFilters(); }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: starredCount.toString(),
                    label: 'امتحان',
                    bgColor: AppColors.statAmberBg,
                    bottomBorderColor: AppColors.statAmberBorder,
                    icon: Icons.star_rounded,
                    iconColor: AppColors.statAmberBorder,
                    onTap: () => setState(() { _selectedFilter = 'امتحان'; _applyFilters(); }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blueGrey.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                    setState(() { _searchQuery = val; _applyFilters(); });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(label: 'الكل', icon: Icons.grid_view_rounded, iconColor: _selectedFilter == 'الكل' ? Colors.white : AppColors.navyPrimary),
                    const SizedBox(width: 8),
                    _buildFilterPill(label: 'مقررة', icon: Icons.calendar_month_rounded, iconColor: _selectedFilter == 'مقررة' ? Colors.white : AppColors.navyPrimary),
                    const SizedBox(width: 8),
                    _buildFilterPill(label: 'تمت العملية', icon: Icons.check_circle_rounded, iconColor: _selectedFilter == 'تمت العملية' ? Colors.white : const Color(0xFF00A86B)),
                    const SizedBox(width: 8),
                    _buildFilterPill(label: 'حوادث طوارئ 🚨', icon: Icons.warning_amber_rounded, iconColor: _selectedFilter == 'حوادث طوارئ 🚨' ? Colors.white : Colors.red),
                    const SizedBox(width: 8),
                    _buildFilterPill(label: 'اسئلة Viva 💡', icon: Icons.lightbulb_rounded, iconColor: _selectedFilter == 'اسئلة Viva 💡' ? Colors.white : Colors.orange),
                    const SizedBox(width: 8),
                    _buildFilterPill(label: 'امتحان', icon: Icons.star_rounded, iconColor: _selectedFilter == 'امتحان' ? Colors.white : AppColors.statAmberBorder),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_filteredPatients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
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
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientFormScreen()));
                  _loadAllData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF072549), Color(0xFF104076)]),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: AppColors.navyPrimary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: AppColors.navyDark, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text('إضافة حالة جديدة', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
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
            border: Border(bottom: BorderSide(color: bottomBorderColor, width: 4.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 4),
              Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navyDark, height: 1.1)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyDark), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({required String label, required IconData icon, required Color iconColor}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () { setState(() { _selectedFilter = label; _applyFilters(); }); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyPrimary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.navyPrimary : Colors.blueGrey.shade100),
          boxShadow: [if (isSelected) BoxShadow(color: AppColors.navyPrimary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.navyDark, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSurgicalPatientCard(PatientRecord patient) {
    final totalPhotos = patient.radiologyImages.length + patient.labImages.length + patient.woundImages.length + patient.biopsyImages.length;
    final shortRole = patient.surgeonRole.split(' ').first;
    final shortMag = patient.operationMagnitude.split(' ').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(right: BorderSide(color: AppColors.navyPrimary, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: patient.id!, isAnonymized: _isAnonymized)));
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
                            style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: AppColors.navyDark),
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
                    decoration: BoxDecoration(color: AppColors.roleBadgeBg, borderRadius: BorderRadius.circular(12)),
                    child: Text('( $shortRole )', textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.navyDark, fontWeight: FontWeight.w900, fontSize: 13.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${patient.rotation}   |   د. ${patient.consultantName.isEmpty ? "غير محدد" : patient.consultantName}   |   دم: ${patient.bloodGroup}',
                  style: const TextStyle(color: AppColors.navyDark, fontSize: 13, fontWeight: FontWeight.w600),
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
                  const Text('التشخيص: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyAccent)),
                  Expanded(
                    child: Text(
                      '${patient.diagnosis} (${patient.chiefComplaint})',
                      style: const TextStyle(fontSize: 14, color: AppColors.navyDark, fontWeight: FontWeight.w500),
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
                  const Text('العملية: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyAccent)),
                  Expanded(
                    child: Text(
                      '${patient.plannedOperation} [$shortMag]',
                      style: const TextStyle(fontSize: 14, color: AppColors.navyDark, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildBottomCardPill(text: patient.finalOutcome, icon: Icons.monitor_heart_rounded, bgColor: AppColors.pillGreenBg, textColor: AppColors.pillGreenText)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildBottomCardPill(
                      text: patient.isTraumaCase == 'نعم' ? 'طوارئ 🚨' : 'باردة',
                      icon: Icons.warning_rounded,
                      bgColor: patient.isTraumaCase == 'نعم' ? const Color(0xFFFEE2E2) : AppColors.pillOrangeBg,
                      textColor: patient.isTraumaCase == 'نعم' ? Colors.red.shade800 : AppColors.pillOrangeText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _buildBottomCardPill(text: '$totalPhotos صور', icon: Icons.photo_library_outlined, bgColor: AppColors.pillPurpleBg, textColor: AppColors.pillPurpleText)),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomCardPill({required String text, required IconData icon, required Color bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
      return const Center(child: Text('لا توجد حالات مسجلة لتصنيفها حسب الروتيشن بعد', style: TextStyle(color: Colors.blueGrey)));
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('أرشيف الحالات مقسماً حسب الروتيشن الجراحي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
        const SizedBox(height: 10),
        ...grouped.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.statBlueBg,
                child: Text('${entry.value.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyPrimary)),
              ),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('جراح رئيسي (P): ${entry.value.where((e) => e.surgeonRole.startsWith("P")).length}', style: const TextStyle(fontSize: 12)),
              children: entry.value.map((p) {
                return ListTile(
                  title: Text(p.displayName(_isAnonymized), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.plannedOperation} — ${p.diagnosis}'),
                  trailing: Text(p.operationDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: p.id!, isAnonymized: _isAnonymized)));
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
              const Text('مؤشر إنجاز متطلبات البورد (جراح رئيسي P)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المنجز: $pCount عملية من أصل $_boardTargetP', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statBlueBorder)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: AppColors.statBlueBg, color: AppColors.statBlueBorder),
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
              const Text('توزيع العمليات حسب دورك الجراحي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const Divider(),
              _buildStatRowItem('P - جراح رئيسي (Performed)', pCount, total, AppColors.statBlueBorder),
              _buildStatRowItem('S - بإشراف الاستشاري (Supervised)', sCount, total, AppColors.statMintBorder),
              _buildStatRowItem('A - مساعد جراح (Assisted)', aCount, total, AppColors.statAmberBorder),
            ],
          ),
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

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بيانات الطبيب المقيم (تظهر في تقارير الـ PDF الرسمية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyDark)),
              const Divider(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الطبيب المقيم', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: levelCtrl, decoration: const InputDecoration(labelText: 'المرحلة / الاختصاص', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: hospCtrl, decoration: const InputDecoration(labelText: 'المستشفى / المركز التدريبي', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: targetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد المستهدف لعمليات P', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () async {
                    await DatabaseHelper.instance.saveSetting('residentName', nameCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('residentLevel', levelCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('hospitalName', hospCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('boardTargetP', targetCtrl.text.trim());
                    _loadAllData();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الطبيب بنجاح')));
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
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
                    Text(items[i]['label'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(height: 3, width: isSelected ? 48 : 0, decoration: BoxDecoration(color: const Color(0xFF0066CC), borderRadius: BorderRadius.circular(4))),
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
// 4. شاشة إضافة وتعديل ملف المريض
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
  late TextEditingController _vivaQCtrl;
  late TextEditingController _vivaACtrl;
  late TextEditingController _guidelineCtrl;
  late TextEditingController _dischargeCtrl;
  late TextEditingController _followUpCtrl;

  String _gender = 'ذكر';
  String _bloodGroup = 'O+';
  String _surgeonRole = 'P - جراح رئيسي (Performed)';
  String _opMagnitude = 'Major';
  String _isTraumaCase = 'لا';
  String _gcsScore = '15';
  String _traumaType = 'إصابة كليلة (Blunt)';
  String _traumaAction = 'استقرار بالردهة';
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
    _vivaQCtrl = TextEditingController(text: p?.vivaQuestion ?? '');
    _vivaACtrl = TextEditingController(text: p?.vivaAnswerReference ?? '');
    _guidelineCtrl = TextEditingController(text: p?.guidelineNotes ?? '');
    _dischargeCtrl = TextEditingController(text: p?.dischargeTreatment ?? '');
    _followUpCtrl = TextEditingController(text: p?.followUpDate ?? '');

    if (p != null) {
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      _surgeonRole = p.surgeonRole;
      _opMagnitude = p.operationMagnitude;
      _isTraumaCase = p.isTraumaCase;
      _gcsScore = p.gcsScore;
      _traumaType = p.traumaType;
      _traumaAction = p.traumaAction;
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
              title: const Text('اختيار من استوديو الهاتف'),
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
      isTraumaCase: _isTraumaCase,
      gcsScore: _gcsScore,
      traumaType: _traumaType,
      traumaAction: _traumaAction,
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
      vivaQuestion: _vivaQCtrl.text.trim(),
      vivaAnswerReference: _vivaACtrl.text.trim(),
      guidelineNotes: _guidelineCtrl.text.trim(),
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
                      child: _buildDropdown('فصيلة الدم', _bloodGroup, ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'], (v) => setState(() => _bloodGroup = v!)),
                    ),
                  ],
                ),
              ],
            ),

            // الفكرة 1: سجل حوادث الطوارئ والإصابات (Trauma & Acute Care)
            _buildSectionCard(
              title: '2. سجل حوادث الطوارئ والإصابات (Trauma)',
              icon: Icons.emergency_rounded,
              children: [
                _buildDropdown('هل الحالة حادث طارئ / إصابة (Trauma)؟', _isTraumaCase, ['لا', 'نعم'], (v) => setState(() => _isTraumaCase = v!)),
                if (_isTraumaCase == 'نعم') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_gcsScore, 'مقياس غلاسكو (GCS 3-15)', isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdown('نوع الإصابة', _traumaType, ['إصابة كليلة (Blunt)', 'إصابة نافذة (Penetrating)', 'حروق / أخرى'], (v) => setState(() => _traumaType = v!))),
                    ],
                  ),
                  _buildDropdown('إجراء الطوارئ الفوري', _traumaAction, ['عملية استكشاف عاجلة (Exploratory)', 'إنعاش واستقرار بالردهة', 'تحويل للعناية المركزة (ICU)'], (v) => setState(() => _traumaAction = v!)),
                ],
              ],
            ),

            _buildSectionCard(
              title: '3. بيانات اللوكبوك الجراحي (Board Logbook)',
              icon: Icons.badge,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(_rotationCtrl, 'الروتيشن')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_consultantCtrl, 'الاختصاصي المشرف')),
                  ],
                ),
                _buildDropdown('دورك في العملية', _surgeonRole, ['P - جراح رئيسي (Performed)', 'S-TS - بإشراف مباشر', 'S-TU - بإشراف غير مباشر', 'A - مساعد جراح'], (v) => setState(() => _surgeonRole = v!)),
                _buildDropdown('حجم العملية', _opMagnitude, ['Complex Major', 'Major', 'Intermediate', 'Minor'], (v) => setState(() => _opMagnitude = v!)),
              ],
            ),

            _buildSectionCard(
              title: '4. التاريخ المرضي والتشخيص السريري',
              icon: Icons.medical_information,
              children: [
                _buildTextField(_chronicCtrl, 'الأمراض المزمنة', maxLines: 2),
                _buildTextField(_complaintCtrl, 'الشكوى الرئيسية (مما يعاني حالياً) *', required: true, maxLines: 2),
                _buildTextField(_diagnosisCtrl, 'التشخيص الطبي النهائي *', required: true),
              ],
            ),

            _buildSectionCard(
              title: '5. تفاصيل العملية الجراحية المقررة',
              icon: Icons.local_hospital,
              children: [
                _buildTextField(_operationCtrl, 'اسم ونوع العملية المقررة *', required: true),
                _buildDropdown('حالة العملية', _opStatus, ['تمت العملية', 'مقررة', 'مؤجلة'], (v) => setState(() => _opStatus = v!)),
                _buildTextField(_opNotesCtrl, 'تفاصيل خطوات العملية (Operative Notes)', maxLines: 3),
              ],
            ),

            // الفكرة 5: بنك الأسئلة الامتحانية وحالات الـ Viva
            _buildSectionCard(
              title: '6. بنك أسئلة الـ Viva وحالات الامتحان',
              icon: Icons.lightbulb_rounded,
              children: [
                _buildTextField(_vivaQCtrl, 'سؤال تم طرحه أو متوقع في امتحان الـ Viva لهذه الحالة', maxLines: 2),
                _buildTextField(_vivaACtrl, 'الإجابة النموذجية مع ذكر المصدر (مثل Bailey & Love)', maxLines: 2),
              ],
            ),

            // الفكرة 3 (المضافة حديثاً): مذكرات المراجع الطبية الموثقة (Surgical Guidelines)
            _buildSectionCard(
              title: '7. مذكرات الـ Guidelines والمراجع الطبية',
              icon: Icons.menu_book_rounded,
              children: [
                _buildTextField(_guidelineCtrl, 'قواعد وبروتوكولات التعامل مع الحالة حسب المراجع العالمية', maxLines: 2),
                _buildTextField(_pearlsCtrl, 'ملاحظات وتشريحات جراحية خاصة (Surgical Pearls)', maxLines: 2),
              ],
            ),

            _buildSectionCard(
              title: '8. الأرشيف الصوري الطبي',
              icon: Icons.camera_enhance,
              children: [
                _buildMediaPickerSection('صور الأشعة والمفراس', _radiologyImages, 'xray'),
                const Divider(),
                _buildMediaPickerSection('صور الجرح والعملية', _woundImages, 'wound'),
              ],
            ),

            _buildSectionCard(
              title: '9. النتيجة النهائية وخطة الخروج',
              icon: Icons.fact_check,
              children: [
                _buildDropdown('النتيجة النهائية', _finalOutcome, ['شفاء تام', 'تحسن مستمر', 'قيد المتابعة', 'حدوث مضاعفات', 'وفاة'], (v) => setState(() => _finalOutcome = v!)),
                _buildTextField(_dischargeCtrl, 'علاج الخروج وتوصيات الجرح', maxLines: 2),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
          const Text('لا توجد صور مرفقة', style: TextStyle(color: Colors.grey, fontSize: 12))
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
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueGrey.shade200)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: File(path).existsSync() ? Image.file(File(path), fit: BoxFit.cover) : const Icon(Icons.broken_image),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => imagesList.removeAt(i)),
                        child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
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
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark))),
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
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ==========================================
// 5. شاشة عرض ملف المريض التفصيلي
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
    final updated = PatientRecord.fromMap({...p.toMap(), 'isStarred': p.isStarred ? 0 : 1});
    await DatabaseHelper.instance.updatePatient(updated);
    _loadPatient();
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = _patient!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName(_anonymized)),
        actions: [
          IconButton(icon: Icon(p.isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber), onPressed: _toggleStar),
          IconButton(icon: Icon(_anonymized ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _anonymized = !_anonymized)),
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
                  Text(p.displayName(_anonymized), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('العمر: ${p.age} | ${p.gender} | دم: ${p.bloodGroup} | طوارئ: ${p.isTraumaCase}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          if (p.vivaQuestion.isNotEmpty)
            Card(
              color: AppColors.statAmberBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.lightbulb, color: Colors.orange), SizedBox(width: 8), Text('بنك أسئلة الـ Viva والامتحان', style: TextStyle(fontWeight: FontWeight.bold))]),
                    const Divider(),
                    Text('السؤال: ${p.vivaQuestion}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('الإجابة والمصدر: ${p.vivaAnswerReference}'),
                  ],
                ),
              ),
            ),
          _buildDetailsCard('التشخيص والعملية', [
            _item('التشخيص النهائي:', p.diagnosis),
            _item('العملية المجراة:', p.plannedOperation),
            _item('ملاحظات الجراح:', p.operativeNotes),
          ]),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String title, List<Widget> items) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark)), const Divider(), ...items]),
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
