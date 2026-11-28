import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/numeric_keypad_sheet.dart';

double _parseHours(dynamic raw, {double fallback = 0.0}) {
  if (raw == null) return fallback;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString()) ?? fallback;
}

class WorkerAttendanceState {
  final int id;
  final int? attendanceId;
  final String name;
  final String jobTitle;
  final String shiftType;
  String status; // 'present', 'absent', 'leave'
  double workHours;
  double overtimeHours;
  double delayHours;
  String notes;
  bool isSaved;

  WorkerAttendanceState({
    required this.id,
    this.attendanceId,
    required this.name,
    required this.jobTitle,
    required this.shiftType,
    this.status = 'present',
    this.workHours = 10.0,
    this.overtimeHours = 0.0,
    this.delayHours = 0.0,
    this.notes = '',
    this.isSaved = false,
  });

  factory WorkerAttendanceState.fromJson(Map<String, dynamic> json) {
    return WorkerAttendanceState(
      id: (json['id'] as num).toInt(),
      attendanceId: (json['attendance_id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      jobTitle: json['job_title']?.toString() ?? 'عامل / موظف',
      shiftType: json['shift_type']?.toString() ?? 'all',
      status: json['status']?.toString() ?? 'present',
      workHours: _parseHours(json['work_hours'], fallback: 10.0),
      overtimeHours: _parseHours(json['overtime_hours']),
      delayHours: _parseHours(json['delay_hours']),
      notes: json['notes']?.toString() ?? '',
      isSaved: json['is_saved'] == true,
    );
  }

  Map<String, dynamic> toSavePayload() {
    return {
      'employee_id': id,
      'status': status,
      'work_hours': status == 'present' ? workHours : 0.0,
      'overtime_hours': status == 'present' ? overtimeHours : 0.0,
      'delay_hours': status == 'present' ? delayHours : 0.0,
      'notes': notes,
    };
  }
}

class AttendanceScreen extends StatefulWidget {
  final bool openRecordsSheet;

  const AttendanceScreen({super.key, this.openRecordsSheet = false});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  DateTime _selectedDate = DateTime.now();
  int? _selectedBranchId;
  String _selectedBranchName = 'الفرع الحالي';
  String _selectedShiftFilter = 'all';
  List<Map<String, dynamic>> _branches = [];
  bool _canEdit = true;

  List<WorkerAttendanceState> _workers = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _didAutoOpenRecords = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendance().then((_) {
      if (widget.openRecordsSheet && !_didAutoOpenRecords && mounted) {
        _didAutoOpenRecords = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openDetailedRecordsSheet();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final params = <String, String>{
        'date': _formatDate(_selectedDate),
        'page_size': '100',
        if (_selectedBranchId != null) 'branch_id': '$_selectedBranchId',
        if (_selectedShiftFilter != 'all') 'shift': _selectedShiftFilter,
      };

      final res = await api.get('/api/v1/attendance/branch/', queryParams: params);
      if (res is Map<String, dynamic> && res['ok'] == true) {
        final bInfo = res['branch'] as Map<String, dynamic>?;
        if (bInfo != null) {
          _selectedBranchId = (bInfo['id'] as num?)?.toInt();
          _selectedBranchName = bInfo['name']?.toString() ?? 'الفرع';
        }

        final bList = res['branches'] as List<dynamic>? ?? [];
        _branches = bList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        _canEdit = res['can_edit'] != false;

        final empRaw = res['employees'] as List<dynamic>? ?? [];
        _workers = empRaw
            .map((e) => WorkerAttendanceState.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _hasUnsavedChanges = false;
      } else if (res is Map<String, dynamic>) {
        _error = res['error']?.toString() ?? 'تعذر تحميل كشف الحضور.';
      }
    } catch (e) {
      _error = 'خطأ في الاتصال بالخادم: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_hasUnsavedChanges) return true;
    return AppConfirmDialog.show(
      context,
      title: 'تغييرات غير محفوظة',
      message:
          'لديك تعديلات في كشف الحضور لم تُحفظ بعد. هل تريد تجاهلها والمتابعة؟',
      confirmLabel: 'تجاهل التعديلات',
      isDestructive: true,
    );
  }

  Future<void> _saveAttendance() async {
    if (!_canEdit) {
      AppFeedback.showError(context, 'غير مسموح بالتعديل على هذا اليوم.');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final api = context.read<ApiClient>();
      final payload = {
        'date': _formatDate(_selectedDate),
        'branch_id': _selectedBranchId,
        'records': _workers.map((w) => w.toSavePayload()).toList(),
      };

      final res = await api.post('/api/v1/attendance/branch/save/', body: payload);
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        _hasUnsavedChanges = false;
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            res['message']?.toString() ??
                'تم اعتماد وحفظ الكشف (${res['saved_count'] ?? _workers.length} سجل) بنجاح.',
          );
        }
        _fetchAttendance();
      } else {
        throw Exception((res is Map ? res['error'] : null) ?? 'فشل في حفظ الكشف.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'خطأ أثناء الحفظ: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _setAllWorkersStatus(String status) {
    HapticFeedback.selectionClick();
    setState(() {
      _hasUnsavedChanges = true;
      for (final w in _workers) {
        w.status = status;
        if (status == 'present') {
          w.workHours = 10.0;
        } else {
          w.workHours = 0.0;
          w.overtimeHours = 0.0;
          w.delayHours = 0.0;
        }
      }
    });
  }

  void _resetAllOvertimeDelay() {
    HapticFeedback.selectionClick();
    setState(() {
      _hasUnsavedChanges = true;
      for (final w in _workers) {
        w.overtimeHours = 0.0;
        w.delayHours = 0.0;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null && picked != _selectedDate && mounted) {
      if (!await _confirmDiscardIfDirty() || !mounted) return;
      setState(() => _selectedDate = picked);
      _fetchAttendance();
    }
  }

  Future<void> _openDialpadForField(WorkerAttendanceState worker, bool isOvertime) async {
    HapticFeedback.lightImpact();
    final currentVal = isOvertime ? worker.overtimeHours : worker.delayHours;
    final title = isOvertime ? 'ساعات إضافي: ${worker.name}' : 'ساعات تأخير: ${worker.name}';

    final res = await AppNumericKeypadSheet.showDouble(
      context,
      title: title,
      unit: 'ساعة',
      initialValue: currentVal,
      allowDecimal: true,
      quickAddValues: isOvertime ? const [0.5, 1, 2, 3] : const [0.25, 0.5, 1, 2],
    );
    if (res != null && mounted) {
      setState(() {
        _hasUnsavedChanges = true;
        if (isOvertime) {
          worker.overtimeHours = res.clamp(0.0, 24.0);
        } else {
          worker.delayHours = res.clamp(0.0, 10.0);
        }
      });
    }
  }

  Future<void> _editWorkerNoteDialog(WorkerAttendanceState worker) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _WorkerNoteDialog(
        workerName: worker.name,
        initialNote: worker.notes,
      ),
    );
    if (saved != null && mounted) {
      setState(() {
        _hasUnsavedChanges = true;
        worker.notes = saved;
      });
    }
  }

  void _openDetailedRecordsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetailedAttendanceRecordsSheet(
        branches: _branches,
        initialBranchId: _selectedBranchId,
        workers: _workers,
        onChanged: _fetchAttendance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _formatDate(_selectedDate) == _formatDate(DateTime.now());

    int presentCount = 0;
    int absentCount = 0;
    int leaveCount = 0;
    double sumOvertime = 0;
    double sumDelay = 0;

    for (final w in _workers) {
      if (w.status == 'present') {
        presentCount++;
        sumOvertime += w.overtimeHours;
        sumDelay += w.delayHours;
      } else if (w.status == 'absent') {
        absentCount++;
      } else if (w.status == 'leave') {
        leaveCount++;
      }
    }

    final filteredWorkers = _workers.where((w) {
      if (_searchQuery.isEmpty) return true;
      return w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscardIfDirty() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حضور وانصراف العمال',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo'),
            ),
            Text(
              '$_selectedBranchName · ${_formatDate(_selectedDate)}',
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'Cairo'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded, size: 21),
            tooltip: 'سجل الحضور التفصيلي',
            onPressed: _openDetailedRecordsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            tooltip: 'تغيير التاريخ',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _fetchAttendance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchAttendance,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderBar(isToday, presentCount, absentCount, leaveCount, sumOvertime, sumDelay),
                    _buildQuickActionBar(),
                    Expanded(
                      child: filteredWorkers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'لا يوجد عمال يطابقون البحث' : 'لا توجد عمالة مسجلة في هذا الفرع',
                                    style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                              itemCount: filteredWorkers.length,
                              itemBuilder: (ctx, index) => _buildWorkerCard(filteredWorkers[index]),
                            ),
                    ),
                  ],
                ),
      bottomSheet: !_isLoading && _error == null ? _buildStickySaveBar(presentCount, sumOvertime, sumDelay) : null,
    ),
    );
  }

  Widget _buildHeaderBar(bool isToday, int present, int absent, int leave, double totalOt, double totalDl) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_branches.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedBranchId,
                      dropdownColor: AppColors.secondaryLight,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      items: _branches.map((b) {
                        return DropdownMenuItem<int>(
                          value: (b['id'] as num).toInt(),
                          child: Text(b['name']?.toString() ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null && val != _selectedBranchId) {
                          if (!await _confirmDiscardIfDirty() || !mounted) return;
                          setState(() => _selectedBranchId = val);
                          _fetchAttendance();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  isToday ? 'كشف اليوم (10 ساعات للحاضرين)' : 'كشف تاريخ: ${_formatDate(_selectedDate)}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC0E7A6),
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedShiftFilter,
                  dropdownColor: AppColors.secondaryLight,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 11),
                  icon: const Icon(Icons.schedule_rounded, color: Colors.white70, size: 15),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('كل الورديات')),
                    DropdownMenuItem(value: 'morning', child: Text('صباحي')),
                    DropdownMenuItem(value: 'evening', child: Text('مسائي')),
                  ],
                  onChanged: (v) async {
                    if (v != null && v != _selectedShiftFilter) {
                      if (!await _confirmDiscardIfDirty() || !mounted) return;
                      setState(() => _selectedShiftFilter = v);
                      _fetchAttendance();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatChip('حاضر', present.toString(), const Color(0xFF16A34A), Icons.check_circle_rounded),
                const SizedBox(width: 6),
                _buildStatChip('غياب', absent.toString(), const Color(0xFFDC2626), Icons.cancel_rounded),
                const SizedBox(width: 6),
                _buildStatChip('إجازة', leave.toString(), const Color(0xFFD97706), Icons.beach_access_rounded),
                if (totalOt > 0) ...[
                  const SizedBox(width: 8),
                  _buildMiniMetric('إضافي', '+${totalOt.toStringAsFixed(1)}س', const Color(0xFF60A5FA)),
                ],
                if (totalDl > 0) ...[
                  const SizedBox(width: 6),
                  _buildMiniMetric('تأخير', '-${totalDl.toStringAsFixed(1)}س', const Color(0xFFFBBF24)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            onPressed: _canEdit ? () => _setAllWorkersStatus('present') : null,
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text(
              'حضور الكل',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            tooltip: 'تصفير الإضافي والتأخير',
            onPressed: _canEdit ? _resetAllOvertimeDelay : null,
            icon: const Icon(Icons.rotate_left_rounded, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'بحث باسم الموظف...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerAttendanceState worker) {
    final isPresent = worker.status == 'present';
    final isAbsent = worker.status == 'absent';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? AppColors.primary.withValues(alpha: 0.35)
              : isAbsent
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isPresent
                      ? AppColors.primaryLight
                      : isAbsent
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFFEF3C7),
                  child: Icon(
                    isPresent
                        ? Icons.person_rounded
                        : isAbsent
                            ? Icons.person_off_rounded
                            : Icons.beach_access_rounded,
                    size: 18,
                    color: isPresent
                        ? AppColors.primary
                        : isAbsent
                            ? AppColors.error
                            : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        worker.jobTitle,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ملاحظات',
                  onPressed: _canEdit ? () => _editWorkerNoteDialog(worker) : null,
                  icon: Icon(
                    worker.notes.isNotEmpty ? Icons.sticky_note_2_rounded : Icons.note_add_outlined,
                    size: 18,
                    color: worker.notes.isNotEmpty ? AppColors.accentAmber : AppColors.textMuted,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPresent ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPresent ? '${worker.workHours.toStringAsFixed(0)} س عمل' : (isAbsent ? 'غياب' : 'إجازة'),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPresent ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (worker.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'ملاحظة: ${worker.notes}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatusSegmentButton(
                      worker: worker,
                      statusKey: 'present',
                      label: 'حضر (10س)',
                      icon: Icons.check_circle_rounded,
                      activeColor: AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _buildStatusSegmentButton(
                      worker: worker,
                      statusKey: 'absent',
                      label: 'غياب',
                      icon: Icons.cancel_rounded,
                      activeColor: AppColors.error,
                    ),
                  ),
                  Expanded(
                    child: _buildStatusSegmentButton(
                      worker: worker,
                      statusKey: 'leave',
                      label: 'إجازة',
                      icon: Icons.beach_access_rounded,
                      activeColor: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            if (isPresent) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildHoursModifierRow(
                      worker: worker,
                      title: 'إضافي',
                      value: worker.overtimeHours,
                      color: const Color(0xFF2563EB),
                      icon: Icons.add_circle_outline_rounded,
                      isOvertime: true,
                      presets: const [1.0, 2.0, 3.0, 4.0, 5.0],
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildHoursModifierRow(
                      worker: worker,
                      title: 'تأخير',
                      value: worker.delayHours,
                      color: const Color(0xFFD97706),
                      icon: Icons.access_time_filled_rounded,
                      isOvertime: false,
                      presets: const [0.25, 0.5, 1.0, 1.5, 2.0],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSegmentButton({
    required WorkerAttendanceState worker,
    required String statusKey,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = worker.status == statusKey;

    return InkWell(
      onTap: _canEdit
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _hasUnsavedChanges = true;
                worker.status = statusKey;
                if (statusKey == 'present') {
                  worker.workHours = 10.0;
                } else {
                  worker.workHours = 0.0;
                  worker.overtimeHours = 0.0;
                  worker.delayHours = 0.0;
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursModifierRow({
    required WorkerAttendanceState worker,
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    required bool isOvertime,
    required List<double> presets,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              '$title:',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                value == 0 ? '0 س' : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} س',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _canEdit
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _hasUnsavedChanges = true;
                        final step = isOvertime ? 0.5 : 0.25;
                        if (isOvertime) {
                          worker.overtimeHours = (worker.overtimeHours - step).clamp(0.0, 24.0);
                        } else {
                          worker.delayHours = (worker.delayHours - step).clamp(0.0, 10.0);
                        }
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.remove, size: 15, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _canEdit
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _hasUnsavedChanges = true;
                        final step = isOvertime ? 0.5 : 0.25;
                        if (isOvertime) {
                          worker.overtimeHours = (worker.overtimeHours + step).clamp(0.0, 24.0);
                        } else {
                          worker.delayHours = (worker.delayHours + step).clamp(0.0, 10.0);
                        }
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.add, size: 15, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...presets.take(3).map((p) {
              final label = p == 0.25
                  ? '¼س'
                  : p == 0.5
                      ? '½س'
                      : '+${p.toInt()}س';
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: _canEdit
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _hasUnsavedChanges = true;
                            if (isOvertime) {
                              worker.overtimeHours = p;
                            } else {
                              worker.delayHours = p;
                            }
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              );
            }),
            InkWell(
              onTap: _canEdit ? () => _openDialpadForField(worker, isOvertime) : null,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.dialpad_rounded, size: 15, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickySaveBar(int present, double totalOt, double totalDl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كشف $present حاضر (10 ساعات)',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'إضافي: ${totalOt.toStringAsFixed(1)}س | تأخير: ${totalDl.toStringAsFixed(1)}س',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: _canEdit && !_isSaving ? _saveAttendance : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'اعتماد وحفظ الكشف',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedAttendanceRecordsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final int? initialBranchId;
  final List<WorkerAttendanceState> workers;
  final VoidCallback onChanged;

  const _DetailedAttendanceRecordsSheet({
    required this.branches,
    required this.initialBranchId,
    required this.workers,
    required this.onChanged,
  });

  @override
  State<_DetailedAttendanceRecordsSheet> createState() => _DetailedAttendanceRecordsSheetState();
}

class _DetailedAttendanceRecordsSheetState extends State<_DetailedAttendanceRecordsSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _branchEmployees = [];
  int? _branchId;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _branchId = widget.initialBranchId;
    _loadEmployeesForSheet();
    _loadRecords();
  }

  Future<void> _loadEmployeesForSheet() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.get(
        '/api/v1/hr/employees/',
        queryParams: {
          'is_active': 'true',
          'page_size': '100',
          if (_branchId != null) 'branch_id': '$_branchId',
        },
      );
      if (res is Map<String, dynamic> && mounted) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _branchEmployees = raw.whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (_) {
      if (mounted && _branchId == widget.initialBranchId) {
        setState(() {
          _branchEmployees = widget.workers
              .map((w) => <String, dynamic>{'id': w.id, 'name': w.name})
              .toList();
        });
      }
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final params = <String, String>{
        'page_size': '50',
        if (_branchId != null) 'branch_id': '$_branchId',
        if (_statusFilter.isNotEmpty) 'status': _statusFilter,
      };
      final res = await api.get('/api/v1/attendance/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _records = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _showSingleRecordDialog({Map<String, dynamic>? existing}) async {
    if (_branchEmployees.isEmpty && existing == null) {
      await _loadEmployeesForSheet();
      if (!mounted) return;
    }
    final employees = _branchEmployees.isNotEmpty
        ? _branchEmployees
        : widget.workers
            .map((w) => <String, dynamic>{'id': w.id, 'name': w.name})
            .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SingleAttendanceRecordDialog(
        api: context.read<ApiClient>(),
        employees: employees,
        existing: existing,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        existing == null ? 'تم تسجيل الحضور الفردي بنجاح' : 'تم تحديث سجل الحضور بنجاح',
      );
      _loadRecords();
      widget.onChanged();
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> rec) async {
    final emp = rec['employee'] as Map<String, dynamic>?;
    final empName = emp?['name']?.toString() ?? rec['employee_name']?.toString() ?? '';
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف سجل حضور',
      message: 'هل تريد حذف سجل حضور "$empName" بتاريخ ${rec['date'] ?? ''} نهائياً؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final api = context.read<ApiClient>();
    try {
      await api.delete('/api/v1/attendance/${rec['id']}/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف سجل الحضور بنجاح');
      _loadRecords();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'تعذر الحذف: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'سجل الحضور والانصراف التفصيلي',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showSingleRecordDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('سجل فردي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.branches.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: _branchId,
                      decoration: const InputDecoration(labelText: 'الفرع', isDense: true),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                        ...widget.branches.map((b) => DropdownMenuItem<int?>(
                              value: (b['id'] as num).toInt(),
                              child: Text(b['name']?.toString() ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _branchId = v);
                        _loadEmployeesForSheet();
                        _loadRecords();
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _statusFilter,
                    decoration: const InputDecoration(labelText: 'الحالة', isDense: true),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('الكل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      DropdownMenuItem(value: 'present', child: Text('حاضر', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      DropdownMenuItem(value: 'absent', child: Text('غائب', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      DropdownMenuItem(value: 'leave', child: Text('إجازة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v ?? '');
                      _loadRecords();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error)))
                      : _records.isEmpty
                          ? const Center(child: Text('لا توجد سجلات مطابقة.', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
                          : ListView.separated(
                              controller: scrollCtrl,
                              itemCount: _records.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (c, i) {
                                final r = _records[i];
                                final emp = r['employee'] as Map<String, dynamic>?;
                                final empName = emp?['name']?.toString() ?? r['employee_name']?.toString() ?? '';
                                final st = r['status']?.toString() ?? 'present';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('$empName · ${r['date'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(
                                              '${r['status_display'] ?? st} | عمل: ${r['work_hours'] ?? 0}س | إضافي: ${r['overtime_hours'] ?? 0}س | تأخير: ${r['delay_hours'] ?? 0}س',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                        onPressed: () => _showSingleRecordDialog(existing: r),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        onPressed: () => _deleteRecord(r),
                                      ),
                                    ],
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
}

class _WorkerNoteDialog extends StatefulWidget {
  final String workerName;
  final String initialNote;

  const _WorkerNoteDialog({
    required this.workerName,
    required this.initialNote,
  });

  @override
  State<_WorkerNoteDialog> createState() => _WorkerNoteDialogState();
}

class _WorkerNoteDialogState extends State<_WorkerNoteDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'ملاحظة: ${widget.workerName}',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'اكتب ملاحظة الحضور أو الانصراف...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('تثبيت', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

class _SingleAttendanceRecordDialog extends StatefulWidget {
  final ApiClient api;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? existing;

  const _SingleAttendanceRecordDialog({
    required this.api,
    required this.employees,
    this.existing,
  });

  @override
  State<_SingleAttendanceRecordDialog> createState() =>
      _SingleAttendanceRecordDialogState();
}

class _SingleAttendanceRecordDialogState
    extends State<_SingleAttendanceRecordDialog> {
  int? _employeeId;
  late String _status;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _workCtrl;
  late final TextEditingController _otCtrl;
  late final TextEditingController _delayCtrl;
  late final TextEditingController _checkInCtrl;
  late final TextEditingController _checkOutCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _employeeId = (e?['employee_id'] as num?)?.toInt() ??
        (e?['employee'] as Map?)?['id'] as int? ??
        (widget.employees.isNotEmpty
            ? (widget.employees.first['id'] as num?)?.toInt()
            : null);
    _status = e?['status']?.toString() ?? 'present';
    _dateCtrl = TextEditingController(
      text: e?['date']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
    );
    _workCtrl =
        TextEditingController(text: e?['work_hours']?.toString() ?? '10');
    _otCtrl =
        TextEditingController(text: e?['overtime_hours']?.toString() ?? '0');
    _delayCtrl =
        TextEditingController(text: e?['delay_hours']?.toString() ?? '0');
    _checkInCtrl =
        TextEditingController(text: e?['check_in']?.toString() ?? '');
    _checkOutCtrl =
        TextEditingController(text: e?['check_out']?.toString() ?? '');
    _notesCtrl = TextEditingController(text: e?['notes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _workCtrl.dispose();
    _otCtrl.dispose();
    _delayCtrl.dispose();
    _checkInCtrl.dispose();
    _checkOutCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_employeeId == null) {
      setState(() => _error = 'اختر الموظف أولاً.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final work = double.tryParse(_workCtrl.text.trim()) ?? 10;
      final ot = double.tryParse(_otCtrl.text.trim()) ?? 0;
      final delay = double.tryParse(_delayCtrl.text.trim()) ?? 0;
      final payload = <String, dynamic>{
        'employee_id': _employeeId,
        'date': _dateCtrl.text.trim(),
        'status': _status,
        'work_hours': _status == 'present' ? work : 0,
        'overtime_hours': _status == 'present' ? ot : 0,
        'delay_hours': _status == 'present' ? delay : 0,
        if (_checkInCtrl.text.trim().isNotEmpty)
          'check_in': _checkInCtrl.text.trim(),
        if (_checkOutCtrl.text.trim().isNotEmpty)
          'check_out': _checkOutCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };
      if (widget.existing == null) {
        await widget.api.post('/api/v1/attendance/create/', body: payload);
      } else {
        await widget.api.put(
          '/api/v1/attendance/${widget.existing!['id']}/update/',
          body: payload,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(
        isNew ? 'إضافة سجل حضور فردي' : 'تعديل سجل حضور #${widget.existing!['id']}',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AppInlineError(message: _error!),
              const SizedBox(height: 10),
            ],
            if (isNew && widget.employees.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: widget.employees
                        .any((e) => (e['id'] as num?)?.toInt() == _employeeId)
                    ? _employeeId
                    : (widget.employees.first['id'] as num?)?.toInt(),
                decoration: const InputDecoration(
                  labelText: 'الموظف',
                  isDense: true,
                ),
                items: widget.employees
                    .map(
                      (e) => DropdownMenuItem<int>(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          e['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _employeeId = v),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'التاريخ',
                suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                isDense: true,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _dateCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _status,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'present',
                  child: Text('حاضر', style: TextStyle(fontFamily: 'Cairo')),
                ),
                DropdownMenuItem(
                  value: 'absent',
                  child: Text('غائب', style: TextStyle(fontFamily: 'Cairo')),
                ),
                DropdownMenuItem(
                  value: 'leave',
                  child: Text('إجازة', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'present'),
            ),
            if (_status == 'present') ...[
              const SizedBox(height: 10),
              AppNumericField(
                controller: _workCtrl,
                label: 'ساعات العمل',
                unit: 'ساعة',
                allowDecimal: true,
                isDense: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _otCtrl,
                      label: 'إضافي',
                      unit: 'س',
                      allowDecimal: true,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppNumericField(
                      controller: _delayCtrl,
                      label: 'تأخير',
                      unit: 'س',
                      allowDecimal: true,
                      isDense: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTimeField(
                      controller: _checkInCtrl,
                      label: 'وقت الحضور',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTimeField(
                      controller: _checkOutCtrl,
                      label: 'وقت الانصراف',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
