import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';

class WorkerAttendanceState {
  final int id;
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
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      jobTitle: json['job_title']?.toString() ?? 'عامل / موظف',
      shiftType: json['shift_type']?.toString() ?? 'all',
      status: json['status']?.toString() ?? 'present',
      workHours: (json['work_hours'] as num?)?.toDouble() ?? 10.0,
      overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0.0,
      delayHours: (json['delay_hours'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      isSaved: json['is_saved'] == true,
    );
  }

  Map<String, dynamic> toSavePayload() {
    return {
      'employee_id': id,
      'status': status,
      'overtime_hours': overtimeHours,
      'delay_hours': delayHours,
      'notes': notes,
    };
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

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
  List<Map<String, dynamic>> _branches = [];
  bool _canEdit = true;

  List<WorkerAttendanceState> _workers = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
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
      final dateStr = _formatDate(_selectedDate);
      String url = '/api/v1/attendance/branch/?date=$dateStr';
      if (_selectedBranchId != null) {
        url += '&branch_id=$_selectedBranchId';
      }

      final res = await api.get(url);
      if (res is Map<String, dynamic> && res['ok'] == true) {
        final bInfo = res['branch'] as Map<String, dynamic>?;
        if (bInfo != null) {
          _selectedBranchId = bInfo['id'] as int?;
          _selectedBranchName = bInfo['name']?.toString() ?? 'الفرع';
        }

        final bList = res['branches'] as List<dynamic>? ?? [];
        _branches = bList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        _canEdit = res['can_edit'] != false;

        final empRaw = res['employees'] as List<dynamic>? ?? [];
        _workers = empRaw.map((e) => WorkerAttendanceState.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _error = res['error']?.toString() ?? 'تعذر تحميل كشف الحضور.';
      }
    } catch (e) {
      _error = 'خطأ في الاتصال بالخادم: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('غير مسموح بالتعديل على هذا اليوم.')),
      );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      res['message']?.toString() ?? 'تم اعتماد وحفظ الكشف بنجاح.',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        _fetchAttendance();
      } else {
        throw Exception(res['error'] ?? 'فشل في حفظ الكشف.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _setAllWorkersStatus(String status) {
    HapticFeedback.selectionClick();
    setState(() {
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchAttendance();
    }
  }

  Future<void> _openDialpadForField(WorkerAttendanceState worker, bool isOvertime) async {
    HapticFeedback.lightImpact();
    final currentVal = isOvertime ? worker.overtimeHours : worker.delayHours;
    final title = isOvertime ? 'ساعات إضافي: ${worker.name}' : 'ساعات تأخير: ${worker.name}';

    final res = await FastQuantityDialSheet.show(
      context,
      title: title,
      unit: 'ساعة',
      initialValue: currentVal,
    );
    if (res != null) {
      setState(() {
        if (isOvertime) {
          worker.overtimeHours = res;
        } else {
          worker.delayHours = res;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _formatDate(_selectedDate) == _formatDate(DateTime.now());

    // Compute live counters
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

    return Scaffold(
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
                    // Top Dashboard & Filters Bar
                    _buildHeaderBar(isToday, presentCount, absentCount, leaveCount, sumOvertime, sumDelay),

                    // Quick Master Actions (⚡ حضور الكل) & Search
                    _buildQuickActionBar(),

                    // Workers Cards List
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
                              itemBuilder: (ctx, index) {
                                return _buildWorkerCard(filteredWorkers[index]);
                              },
                            ),
                    ),
                  ],
                ),
      bottomSheet: !_isLoading && _error == null ? _buildStickySaveBar(presentCount, sumOvertime, sumDelay) : null,
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
            color: AppColors.secondary.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Branch & Date Bar
          Row(
            children: [
              if (_branches.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
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
                          value: b['id'] as int,
                          child: Text(b['name']?.toString() ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
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
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_calendar_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isToday ? 'اليوم' : _formatDate(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Live Counters Row (Horizontal scroll to prevent any pixel overflow)
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
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
              color: Colors.white.withOpacity(0.95),
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
        color: color.withOpacity(0.15),
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
          // ⚡ Master "حضور الكل (10س)" Button
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

          // Search Field
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
    final isLeave = worker.status == 'leave';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? AppColors.primary.withOpacity(0.35)
              : isAbsent
                  ? AppColors.error.withOpacity(0.3)
                  : AppColors.warning.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
            // Top Row: Worker info & current active badge
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
                // Work Hours badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPresent ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPresent ? '10 ساعات عمل' : (isAbsent ? '0 ساعات (غياب)' : '0 ساعات (إجازة)'),
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

            const SizedBox(height: 10),

            // 3-Way Segmented Status Selector (حضر / غياب / أجازة)
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
                      label: 'أجازة',
                      icon: Icons.beach_access_rounded,
                      activeColor: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),

            // If Present: Overtime & Delay Operations Drawer
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
                    // Overtime Row (ساعات إضافي)
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

                    // Delay Row (ساعات تأخير)
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
                    color: activeColor.withOpacity(0.3),
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
    return Row(
      children: [
        // Title & Value Display
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$title:',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value == 0 ? '0 س' : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} س',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),

        // Quick Steppers [-] and [+]
        InkWell(
          onTap: _canEdit
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final step = isOvertime ? 0.5 : 0.25;
                    if (isOvertime) {
                      worker.overtimeHours = (worker.overtimeHours - step).clamp(0.0, 24.0);
                    } else {
                      worker.delayHours = (worker.delayHours - step).clamp(0.0, 10.0);
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: _canEdit
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final step = isOvertime ? 0.5 : 0.25;
                    if (isOvertime) {
                      worker.overtimeHours = (worker.overtimeHours + step).clamp(0.0, 24.0);
                    } else {
                      worker.delayHours = (worker.delayHours + step).clamp(0.0, 10.0);
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
          ),
        ),

        const Spacer(),

        // Quick Preset Chips (+1, +2, +3...)
        ...presets.take(3).map((p) {
          final label = p == 0.25
              ? '¼س'
              : p == 0.5
                  ? '½س'
                  : '+${p.toInt()}س';
          return Padding(
            padding: const EdgeInsets.only(left: 3),
            child: InkWell(
              onTap: _canEdit
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isOvertime) {
                          worker.overtimeHours = p;
                        } else {
                          worker.delayHours = p;
                        }
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          );
        }),

        // ✏️ Direct Dialpad Button (Zero Keyboard Lag)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: InkWell(
            onTap: _canEdit ? () => _openDialpadForField(worker, isOvertime) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.dialpad_rounded, size: 13, color: color),
            ),
          ),
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
            color: Colors.black.withOpacity(0.06),
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
