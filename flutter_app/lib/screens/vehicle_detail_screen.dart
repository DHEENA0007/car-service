import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'add_vehicle_screen.dart';
import 'add_service_record_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Map<String, dynamic> _vehicle;
  List<dynamic> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getServiceRecords(_vehicle['id'] as int);
      if (mounted && result['success'] == true) {
        setState(() {
          _records = result['data'] as List;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecord(int recordId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Record', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Delete "$name"?', style: const TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await ApiService.deleteServiceRecord(_vehicle['id'] as int, recordId);
    if (mounted) {
      if (result['success'] == true) {
        _loadRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Delete failed'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  double get _totalCost {
    double total = 0;
    for (final r in _records) {
      final cost = r['cost'];
      if (cost != null) total += double.tryParse(cost.toString()) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_vehicle['year']} ${_vehicle['make']} ${_vehicle['model']}';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddVehicleScreen(vehicle: _vehicle)),
              );
              if (updated == true) {
                // Reload vehicle info
                final result = await ApiService.getVehicles();
                if (mounted && result['success'] == true) {
                  final list = result['data'] as List;
                  final found = list.firstWhere(
                    (v) => v['id'] == _vehicle['id'],
                    orElse: () => _vehicle,
                  );
                  setState(() => _vehicle = found as Map<String, dynamic>);
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddServiceRecordScreen(vehicleId: _vehicle['id'] as int),
            ),
          );
          if (added == true) _loadRecords();
        },
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: Column(
          children: [
            _buildVehicleHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      color: AppTheme.primaryColor,
                      child: _records.isEmpty ? _buildEmpty() : _buildRecordList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleHeader() {
    final color = _vehicle['color'] as String?;
    final plate = _vehicle['license_plate'] as String?;
    final vin = _vehicle['vin'] as String?;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_vehicle['year']} ${_vehicle['make']} ${_vehicle['model']}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    if (color != null && color.isNotEmpty)
                      Text(color, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (plate != null && plate.isNotEmpty || vin != null && vin.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                if (plate != null && plate.isNotEmpty)
                  _HeaderChip(label: plate, icon: Icons.credit_card),
                if (vin != null && vin.isNotEmpty)
                  _HeaderChip(label: 'VIN: $vin', icon: Icons.tag),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Services',
                  value: '${_records.length}',
                  icon: Icons.build_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Total Cost',
                  value: '₹${_totalCost.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.45,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.build_outlined, size: 48, color: AppTheme.info),
              ),
              const SizedBox(height: 16),
              const Text('No service records yet',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Tap "+ Add Service" to log your first\nmaintenance record',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      ),
    );
  }

  Widget _buildRecordList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final r = _records[index] as Map<String, dynamic>;
        return _ServiceRecordCard(
          record: r,
          vehicleId: _vehicle['id'] as int,
          onEdit: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddServiceRecordScreen(
                  vehicleId: _vehicle['id'] as int,
                  record: r,
                ),
              ),
            );
            if (updated == true) _loadRecords();
          },
          onDelete: () => _deleteRecord(r['id'] as int, r['service_name'] as String),
        ).animate().fadeIn(delay: (60 * index).ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeaderChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final int vehicleId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceRecordCard({
    required this.record,
    required this.vehicleId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cost = record['cost'] != null ? double.tryParse(record['cost'].toString()) : null;
    final date = record['service_date'] as String? ?? '';
    final mileage = record['mileage'];
    final center = record['service_center_name'] as String?;
    final billImage = record['bill_image'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.build, color: AppTheme.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['service_name'] as String,
                        style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
                        ),
                      ),
                      Text(date,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (cost != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${cost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 13,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  color: AppTheme.cardBg,
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 18),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Detail chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (mileage != null)
                  _DetailChip(icon: Icons.speed, label: '$mileage km', color: AppTheme.warning),
                if (center != null && center.isNotEmpty)
                  _DetailChip(icon: Icons.store_outlined, label: center, color: AppTheme.info),
              ],
            ),
          ),
          if (record['description'] != null && (record['description'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                record['description'] as String,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (record['notes'] != null && (record['notes'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record['notes'] as String,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Bill image thumbnail
          if (billImage != null && billImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: () => _viewBill(context, billImage),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 16),
                    const SizedBox(width: 6),
                    const Text('View Bill',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  void _viewBill(BuildContext context, String url) {
    // Use the server base URL for relative paths
    final fullUrl = url.startsWith('http') ? url : 'http://127.0.0.1:8000$url';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Bill Image', style: TextStyle(color: Colors.white)),
            ),
            Image.network(fullUrl, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load image', style: TextStyle(color: Colors.white)),
                    )),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DetailChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
