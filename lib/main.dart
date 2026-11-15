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
  runApp(const SurgicalRegistryApp());
}

class SurgicalRegistryApp extends StatelessWidget {
  const SurgicalRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجل الجراحة والمرضى',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
        scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF004D40),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const DashboardScreen(),
    );
  }
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

  // التاريخ المرضي
  final String chronicDiseases;
  final String allergies;
  final String currentMedications;
  final String smokingStatus;

  // التاريخ الجراحي السابق
  final String pastSurgeries;
  final String pastComplications;

  // الشكوى الحالية والتشخيص
  final String chiefComplaint;
  final String clinicalExam;
  final String labRadiologyNotes;
  final String diagnosis;

  // العملية المقررة
  final String plannedOperation;
  final String operationUrgency;
  final String asaScore;
  final String anesthesiaType;
  final String operationDate;
  final String operationStatus;
  final String operativeNotes;

  // النتيجة النهائية والمتابعة
  final String finalOutcome;
  final String clavienDindoGrade;
  final String dischargeTreatment;
  final String followUpDate;

  // مسارات الصور الطبية (JSON Arrays)
  final List<String> radiologyImages;
  final List<String> labImages;
  final List<String> woundImages;

  PatientRecord({
    this.id,
    required this.mrn,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.bloodGroup,
    required this.admissionDate,
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
    required this.finalOutcome,
    required this.clavienDindoGrade,
    required this.dischargeTreatment,
    required this.followUpDate,
    required this.radiologyImages,
    required this.labImages,
    required this.woundImages,
  });

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
      'finalOutcome': finalOutcome,
      'clavienDindoGrade': clavienDindoGrade,
      'dischargeTreatment': dischargeTreatment,
      'followUpDate': followUpDate,
      'radiologyImages': jsonEncode(radiologyImages),
      'labImages': jsonEncode(labImages),
      'woundImages': jsonEncode(woundImages),
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
      finalOutcome: map['finalOutcome'] ?? 'قيد المتابعة',
      clavienDindoGrade: map['clavienDindoGrade'] ?? 'لا يوجد (None)',
      dischargeTreatment: map['dischargeTreatment'] ?? '',
      followUpDate: map['followUpDate'] ?? '',
      radiologyImages: parseList(map['radiologyImages']),
      labImages: parseList(map['labImages']),
      woundImages: parseList(map['woundImages']),
    );
  }
}

// ==========================================
// 2. إدارة قاعدة البيانات المحلية (SQLite Helper)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surgical_patients_v1.db');
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
        finalOutcome TEXT,
        clavienDindoGrade TEXT,
        dischargeTreatment TEXT,
        followUpDate TEXT,
        radiologyImages TEXT,
        labImages TEXT,
        woundImages TEXT
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
// 3. الشاشة الرئيسية ولوحة التحكم (Dashboard)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PatientRecord> _allPatients = [];
  List<PatientRecord> _filteredPatients = [];
  String _searchQuery = '';
  String _selectedFilter = 'الكل';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPatients();
  }

  Future<void> _refreshPatients() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPatients();
    setState(() {
      _allPatients = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    _filteredPatients = _allPatients.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.mrn.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.diagnosis.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.plannedOperation.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'مقررة') return p.operationStatus == 'مقررة';
      if (_selectedFilter == 'تمت العملية') return p.operationStatus == 'تمت العملية';
      if (_selectedFilter == 'طارئة') return p.operationUrgency.contains('طارئة');
      return true;
    }).toList();
  }

  Future<void> _exportBackupJson() async {
    final list = _allPatients.map((e) => e.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: jsonString));
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await Printing.sharePdf(bytes: bytes, filename: 'surgical_patients_backup.json');
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
                  _refreshPatients();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استيراد بيانات المرضى بنجاح')),
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

  @override
  Widget build(BuildContext context) {
    final totalCount = _allPatients.length;
    final scheduledCount = _allPatients.where((p) => p.operationStatus == 'مقررة').length;
    final completedCount = _allPatients.where((p) => p.operationStatus == 'تمت العملية').length;
    final emergencyCount = _allPatients.where((p) => p.operationUrgency.contains('طارئة')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل مرضاي والعمليات الجراحية', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            onSelected: (val) {
              if (val == 'export') _exportBackupJson();
              if (val == 'import') _showImportDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'export', child: Text('نسخ ومشاركة قاعدة البيانات (JSON)')),
              const PopupMenuItem(value: 'import', child: Text('استعادة نسخة احتياطية')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                _buildStatCard('إجمالي المرضى', totalCount.toString(), Colors.teal.shade700, Icons.people),
                const SizedBox(width: 8),
                _buildStatCard('بانتظار العملية', scheduledCount.toString(), Colors.orange.shade800, Icons.schedule),
                const SizedBox(width: 8),
                _buildStatCard('تمت الجراحة', completedCount.toString(), Colors.blue.shade700, Icons.check_circle),
                const SizedBox(width: 8),
                _buildStatCard('حالات طارئة', emergencyCount.toString(), Colors.red.shade700, Icons.warning_amber),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم المريض، التشخيص، نوع العملية، أو رقم الملف...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilters();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: ['الكل', 'مقررة', 'تمت العملية', 'طارئة'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medical_information_outlined, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد ملفات مرضى مطابقة حالياً\nاضغط على زر (+) لإضافة ملف مريض جديد',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (ctx, index) {
                          final patient = _filteredPatients[index];
                          final totalPhotos = patient.radiologyImages.length +
                              patient.labImages.length +
                              patient.woundImages.length;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailsScreen(patientId: patient.id!),
                                  ),
                                );
                                _refreshPatients();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(0xFF004D40),
                                          foregroundColor: Colors.white,
                                          child: Text(patient.bloodGroup),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                patient.name,
                                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'العمر: ${patient.age} | ${patient.gender} | رقم الملف: ${patient.mrn.isEmpty ? "غير محدد" : patient.mrn}',
                                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildStatusBadge(patient.operationStatus),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoLine(Icons.sick_outlined, 'الشكوى والتشخيص:', '${patient.chiefComplaint} (${patient.diagnosis})'),
                                    const SizedBox(height: 4),
                                    _buildInfoLine(Icons.medical_services_outlined, 'العملية المقررة:', '${patient.plannedOperation} [${patient.operationUrgency}]'),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: _buildInfoLine(Icons.verified_outlined, 'النتيجة النهائية:', patient.finalOutcome),
                                        ),
                                        if (totalPhotos > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.collections, size: 15, color: Colors.teal),
                                                const SizedBox(width: 4),
                                                Text('$totalPhotos صور مرفقة', style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                      ],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientFormScreen()),
          );
          _refreshPatients();
        },
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة مريض جديد'),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(right: BorderSide(color: color, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orange.shade100;
    Color fg = Colors.orange.shade900;
    if (status == 'تمت العملية') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
    } else if (status == 'مؤجلة') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.teal.shade700),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
          child: Text(
            value.isEmpty ? 'غير مسجل' : value,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. شاشة إضافة وتعديل ملف المريض الشامل
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
  late TextEditingController _dischargeCtrl;
  late TextEditingController _followUpCtrl;

  String _gender = 'ذكر';
  String _bloodGroup = 'O+';
  String _smokingStatus = 'غير مدخن';
  String _urgency = 'مجدولة (باردة)';
  String _asaScore = 'ASA I';
  String _anesthesia = 'تخدير عام (GA)';
  String _opStatus = 'مقررة';
  String _finalOutcome = 'قيد المتابعة';
  String _clavienGrade = 'لا يوجد (None)';

  List<String> _radiologyImages = [];
  List<String> _labImages = [];
  List<String> _woundImages = [];

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
    _dischargeCtrl = TextEditingController(text: p?.dischargeTreatment ?? '');
    _followUpCtrl = TextEditingController(text: p?.followUpDate ?? '');

    if (p != null) {
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      _smokingStatus = p.smokingStatus;
      _urgency = p.operationUrgency;
      _asaScore = p.asaScore;
      _anesthesia = p.anesthesiaType;
      _opStatus = p.operationStatus;
      _finalOutcome = p.finalOutcome;
      _clavienGrade = p.clavienDindoGrade;
      _radiologyImages = List<String>.from(p.radiologyImages);
      _labImages = List<String>.from(p.labImages);
      _woundImages = List<String>.from(p.woundImages);
    }
  }

  Future<void> _addPhoto(List<String> targetList, String prefix) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
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
      finalOutcome: _finalOutcome,
      clavienDindoGrade: _clavienGrade,
      dischargeTreatment: _dischargeCtrl.text.trim(),
      followUpDate: _followUpCtrl.text.trim(),
      radiologyImages: _radiologyImages,
      labImages: _labImages,
      woundImages: _woundImages,
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
        title: Text(widget.existingPatient == null ? 'إنشاء ملف مريض جديد' : 'تعديل ملف المريض'),
        actions: [
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
                    Expanded(child: _buildTextField(_admissionDateCtrl, 'تاريخ المراجعة/الدخول')),
                  ],
                ),
              ],
            ),
            _buildSectionCard(
              title: '2. التاريخ المرضي والدوائي',
              icon: Icons.history_edu,
              children: [
                _buildTextField(_chronicCtrl, 'الأمراض المزمنة (سكري، ضغط، قلب، ربو، كلى...)', maxLines: 2),
                _buildTextField(_allergiesCtrl, 'الحساسية الدوائية أو الغذائية'),
                _buildTextField(_medsCtrl, 'الأدوية المستمرة (خصوصاً مميعات الدم مثل الأسبرين/الوارفارين)', maxLines: 2),
                _buildDropdown('حالة التدخين', _smokingStatus, ['غير مدخن', 'مدخن حالي', 'مدخن سابق'], (v) => setState(() => _smokingStatus = v!)),
              ],
            ),
            _buildSectionCard(
              title: '3. الجراحات السابقة',
              icon: Icons.healing,
              children: [
                _buildTextField(_pastSurgeriesCtrl, 'العمليات الجراحية السابقة وتواريخها', maxLines: 2),
                _buildTextField(_pastCompCtrl, 'مضاعفات جراحية أو تخديرية سابقة (إن وجدت)'),
              ],
            ),
            _buildSectionCard(
              title: '4. مما يعاني حالياً والتشخيص السريري',
              icon: Icons.medical_information,
              children: [
                _buildTextField(_complaintCtrl, 'الشكوى الرئيسية (مما يعاني المريض حالياً) *', required: true, maxLines: 2),
                _buildTextField(_examCtrl, 'نتائج الفحص السريري والعلامات الحيوية', maxLines: 2),
                _buildTextField(_labNotesCtrl, 'ملخص نتائج التحاليل والأشعة والسونار/المفراس', maxLines: 2),
                _buildTextField(_diagnosisCtrl, 'التشخيص الطبي النهائي (Diagnosis) *', required: true),
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
                        ['مقررة', 'تمت العملية', 'مؤجلة'],
                        (v) => setState(() => _opStatus = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'تصنيف خطورة التخدير',
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
                        ['تخدير عام (GA)', 'تخدير نصفي (Spinal)', 'تخدير موضعي (Local)', 'تخدير فوق الجافية'],
                        (v) => setState(() => _anesthesia = v!),
                      ),
                    ),
                  ],
                ),
                _buildTextField(_opDateCtrl, 'تاريخ إجراء العملية'),
                _buildTextField(_opNotesCtrl, 'ملاحظات الجراح وتفاصيل ما أثناء العملية (Operative Notes)', maxLines: 3),
              ],
            ),
            _buildSectionCard(
              title: '6. المرفقات الصورية (أشعة، تحاليل، وصور الجرح)',
              icon: Icons.camera_enhance,
              children: [
                _buildMediaPickerSection('صور الأشعة والمفراس والرنين', _radiologyImages, 'xray'),
                const Divider(),
                _buildMediaPickerSection('صور التحاليل المختبرية والتقارير', _labImages, 'lab'),
                const Divider(),
                _buildMediaPickerSection('صور الجرح والعملية (قبل/بعد)', _woundImages, 'wound'),
              ],
            ),
            _buildSectionCard(
              title: '7. النتيجة النهائية وخطة الخروج',
              icon: Icons.fact_check,
              children: [
                _buildDropdown(
                  'النتيجة النهائية للمريض',
                  _finalOutcome,
                  ['قيد المتابعة', 'شفاء تام بدون مضاعفات', 'تحسن مستمر', 'حدوث مضاعفات بعد العملية', 'تحويل لمركز تخصصي', 'وفاة'],
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
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _savePatient,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حفظ ملف المريض بالكامل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        border: Border.all(color: Colors.teal.shade200),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF004D40)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
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
// 5. شاشة عرض ملف المريض والأرشيف الصوري والـ PDF
// ==========================================
class PatientDetailsScreen extends StatefulWidget {
  final int patientId;
  const PatientDetailsScreen({super.key, required this.patientId});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  PatientRecord? _patient;

  @override
  void initState() {
    super.initState();
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

  Future<void> _quickAddImage(String category) async {
    if (_patient == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
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

    if (category == 'xray') rad.add(path);
    if (category == 'lab') lab.add(path);
    if (category == 'wound') wound.add(path);

    final updated = PatientRecord.fromMap({
      ...p.toMap(),
      'radiologyImages': jsonEncode(rad),
      'labImages': jsonEncode(lab),
      'woundImages': jsonEncode(wound),
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
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
          ),
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
            pw.Expanded(child: pw.Text(val.isEmpty ? '-' : val, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: arabicFont, fontSize: 11))),
            pw.SizedBox(width: 8),
            pw.Text(label, style: pw.TextStyle(font: arabicBold, fontSize: 11, color: PdfColors.teal900)),
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
            decoration: pw.BoxDecoration(color: PdfColors.teal800, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('التاريخ: ${p.admissionDate}', style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 11)),
                pw.Text('تقرير طبي وجراحي مفصل', style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 16)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          buildPdfRow('اسم المريض:', '${p.name} (${p.age} سنة - ${p.gender})'),
          buildPdfRow('رقم الملف وفصيلة الدم:', 'MRN: ${p.mrn} | فصيلة الدم: ${p.bloodGroup}'),
          pw.Divider(),
          buildPdfRow('الأمراض المزمنة:', p.chronicDiseases),
          buildPdfRow('الحساسية والأدوية المستمرة:', '${p.allergies} | الأدوية: ${p.currentMedications}'),
          buildPdfRow('العمليات الجراحية السابقة:', p.pastSurgeries),
          pw.Divider(),
          buildPdfRow('الشكوى الرئيسية:', p.chiefComplaint),
          buildPdfRow('الفحص السريري والتحاليل:', '${p.clinicalExam} | ${p.labRadiologyNotes}'),
          buildPdfRow('التشخيص الطبي النهائي:', p.diagnosis),
          pw.Divider(),
          buildPdfRow('العملية المقررة:', '${p.plannedOperation} (${p.operationUrgency})'),
          buildPdfRow('التخدير وتاريخ العملية:', '${p.anesthesiaType} (${p.asaScore}) - التاريخ: ${p.operationDate}'),
          buildPdfRow('حالة العملية وملاحظات الجراح:', '${p.operationStatus} - ${p.operativeNotes}'),
          pw.Divider(),
          buildPdfRow('النتيجة النهائية:', '${p.finalOutcome} (المضاعفات: ${p.clavienDindoGrade})'),
          buildPdfRow('خطة الخروج والمراجعة:', '${p.dischargeTreatment} | المراجعة: ${p.followUpDate}'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Patient_${p.name}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _patient!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير وطباعة PDF',
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
                  content: const Text('هل أنت متأكد من حذف هذا السجل النهائي؟'),
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
            color: const Color(0xFF004D40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          p.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(p.operationStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.shade200,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'العمر: ${p.age} سنة | الجنس: ${p.gender} | فصيلة الدم: ${p.bloodGroup} | ملف: ${p.mrn}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'هاتف: ${p.phone} | تاريخ الدخول: ${p.admissionDate}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          _buildGalleryCard('صور الأشعة والمفراس والرنين (Radiology)', p.radiologyImages, 'xray', Icons.scanner),
          _buildGalleryCard('صور التحاليل المختبرية (Lab Results)', p.labImages, 'lab', Icons.biotech),
          _buildGalleryCard('صور الجرح والعملية (Wound & Post-Op)', p.woundImages, 'wound', Icons.healing),
          _buildDetailsCard('الشكوى الحالية والتشخيص', [
            _item('مما يعاني حالياً (الشكوى):', p.chiefComplaint),
            _item('الفحص السريري:', p.clinicalExam),
            _item('ملاحظات التحاليل والأشعة:', p.labRadiologyNotes),
            _item('التشخيص النهائي:', p.diagnosis),
          ]),
          _buildDetailsCard('العملية الجراحية المقررة', [
            _item('اسم ونوع العملية:', p.plannedOperation),
            _item('التصنيف والحالة:', '${p.operationUrgency} | الحالة: ${p.operationStatus}'),
            _item('التخدير وتصنيف ASA:', '${p.anesthesiaType} (${p.asaScore})'),
            _item('تاريخ العملية:', p.operationDate),
            _item('ملاحظات العملية (Operative Notes):', p.operativeNotes),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      Icon(icon, color: Colors.teal.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
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
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('لا توجد صور مرفقة بعد — اضغط "إضافة صورة" للتصوير أو الاختيار من الاستوديو', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                          border: Border.all(color: Colors.teal.shade300),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sectionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
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
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          Expanded(child: Text(val.isEmpty ? 'غير مسجل' : val, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
