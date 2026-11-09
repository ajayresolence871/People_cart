import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/delivery_assignment_data.dart';
import '../providers/delivery_assignment_provider.dart';
import '../services/delivery_assignment_service.dart';

class AdminDeliveryAssignmentsScreen extends StatelessWidget {
  final DeliveryAssignmentDataSource? dataSource;

  const AdminDeliveryAssignmentsScreen({super.key, this.dataSource});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.profile == null ||
        auth.role != 'admin') {
      return const Center(child: Text('Admin access required.'));
    }

    return ChangeNotifierProvider(
      create: (_) => AdminDeliveryAssignmentProvider(
        dataSource: dataSource ?? DeliveryAssignmentService(),
      )..load(),
      child: const _DeliveryAssignmentsContent(),
    );
  }
}

enum _DeliveryFilter { all, unassigned, assigned }

class _DeliveryAssignmentsContent extends StatefulWidget {
  const _DeliveryAssignmentsContent();

  @override
  State<_DeliveryAssignmentsContent> createState() =>
      _DeliveryAssignmentsContentState();
}

class _DeliveryAssignmentsContentState
    extends State<_DeliveryAssignmentsContent> {
  _DeliveryFilter _filter = _DeliveryFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminDeliveryAssignmentProvider>();
    final orders = provider.orders;
    final partners = provider.partners ?? const <DeliveryPartner>[];
    final activeOrders = (orders ?? const <DeliveryManagedOrder>[])
        .where((order) => order.isActive)
        .toList();
    bool isAssigned(DeliveryManagedOrder order) =>
        order.assignedPartnerId != null;
    final unassignedCount = activeOrders
        .where((order) => !isAssigned(order))
        .length;
    final assignedCount = activeOrders.where(isAssigned).length;
    final outForDeliveryCount = activeOrders
        .where((order) => order.isOutForDelivery)
        .length;
    final visibleOrders = activeOrders.where((order) {
      return switch (_filter) {
        _DeliveryFilter.all => true,
        _DeliveryFilter.unassigned => !isAssigned(order),
        _DeliveryFilter.assigned => isAssigned(order),
      };
    }).toList();

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery assignments',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Assign active orders to registered delivery partners.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (orders != null && orders.isNotEmpty)
                    _NeedsPartnerAlert(
                      count: unassignedCount,
                      onTap: () =>
                          setState(() => _filter = _DeliveryFilter.unassigned),
                    ),
                  if (orders != null && orders.isNotEmpty)
                    const SizedBox(height: 10),
                  if (orders != null && orders.isNotEmpty)
                    _DeliverySummaryCards(
                      unassigned: unassignedCount,
                      assigned: assignedCount,
                      outForDelivery: outForDeliveryCount,
                    ),
                  const SizedBox(height: 10),
                  if (orders != null && orders.isNotEmpty)
                    _DeliveryFilters(
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                    ),
                  const SizedBox(height: 12),
                  if (provider.actionError != null)
                    _AssignmentMessage(
                      icon: Icons.error_outline,
                      message: 'Assignment failed: ${provider.actionError}',
                    ),
                  if (provider.isLoading && orders == null)
                    const _AssignmentMessage(
                      icon: Icons.delivery_dining_outlined,
                      message: 'Loading orders and delivery partners…',
                      loading: true,
                    )
                  else if (provider.error != null && orders == null)
                    _AssignmentMessage(
                      icon: Icons.error_outline,
                      message:
                          'Could not load delivery assignments: ${provider.error}',
                      action: provider.load,
                    )
                  else if (orders == null || orders.isEmpty)
                    const _AssignmentMessage(
                      icon: Icons.inbox_outlined,
                      message: 'There are no orders to assign yet.',
                    )
                  else ...[
                    if (provider.error != null)
                      _AssignmentMessage(
                        icon: Icons.error_outline,
                        message:
                            'Refresh failed; showing previous orders. ${provider.error}',
                      ),
                    if (partners.isEmpty)
                      const _AssignmentMessage(
                        icon: Icons.person_search_outlined,
                        message: 'No profiles with the delivery_partner role are available. Register or activate a delivery partner to assign orders.',
                      ),
                    if (visibleOrders.isEmpty)
                      const _AssignmentMessage(
                        icon: Icons.filter_list_off_rounded,
                        message: 'No orders match this delivery filter.',
                      ),
                    for (final order in visibleOrders)
                      _DeliveryOrderCard(
                        order: order,
                        partners: partners,
                        isUpdating: provider.updatingOrderIds.contains(
                          order.id,
                        ),
                        isAssigned: isAssigned(order),
                        onAssign: (partnerId) async {
                          final succeeded = await provider.assign(
                            order.id,
                            partnerId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  succeeded
                                      ? provider.actionMessage ??
                                            'Delivery assignment saved.'
                                      : provider.actionError ??
                                            'Assignment failed.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final DeliveryManagedOrder order;
  final List<DeliveryPartner> partners;
  final bool isUpdating;
  final bool isAssigned;
  final Future<void> Function(String?) onAssign;

  const _DeliveryOrderCard({
    required this.order,
    required this.partners,
    required this.isUpdating,
    required this.isAssigned,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isAssignmentLocked = order.isAssignmentLocked;
    final matchingPartners = partners
        .where((partner) => partner.id == order.assignedPartnerId)
        .toList();
    final returnedPartnerName = order.assignedPartnerName?.trim();
    final partnerName =
        returnedPartnerName != null && returnedPartnerName.isNotEmpty
        ? returnedPartnerName
        : (matchingPartners.isEmpty
              ? 'Assigned partner unavailable'
              : matchingPartners.first.displayName);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  order.totalAmount == null
                      ? '—'
                      : '₹${order.totalAmount!.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${_formatDate(order.createdAt)} · ${order.itemCount} items',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DeliveryStatusPill(status: order.status),
                if (isAssigned)
                  Text(
                    partnerName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  const Text(
                    'Unassigned',
                    style: TextStyle(
                      color: AppColors.accentPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (order.isOutForDelivery)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Partner assignment is locked after pickup.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (isAssignmentLocked)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Completed or cancelled orders cannot be reassigned.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (partners.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isUpdating
                      ? null
                      : () => _confirmAndAssign(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: isAssigned
                        ? AppColors.giftBannerBg
                        : AppColors.accentPink,
                    foregroundColor: isAssigned
                        ? AppColors.primary
                        : Colors.white,
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isAssigned ? 'Change partner' : 'Assign partner'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndAssign(BuildContext context) async {
    final selectedPartnerId = await showDialog<String>(
      context: context,
      builder: (context) => DeliveryPartnerSelectionDialog(
        partners: partners,
        initialPartnerId: order.assignedPartnerId,
      ),
    );
    if (selectedPartnerId == null || !context.mounted) return;
    await onAssign(selectedPartnerId);
  }
}

class DeliveryPartnerSelectionDialog extends StatefulWidget {
  final List<DeliveryPartner> partners;
  final String? initialPartnerId;

  const DeliveryPartnerSelectionDialog({
    super.key,
    required this.partners,
    required this.initialPartnerId,
  });

  @override
  State<DeliveryPartnerSelectionDialog> createState() =>
      _DeliveryPartnerSelectionDialogState();
}

class _DeliveryPartnerSelectionDialogState
    extends State<DeliveryPartnerSelectionDialog> {
  late String? _selected =
      widget.partners.any((partner) => partner.id == widget.initialPartnerId)
      ? widget.initialPartnerId
      : (widget.partners.isEmpty ? null : widget.partners.first.id);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign delivery partner'),
      content: DropdownButtonFormField<String>(
        initialValue: widget.partners.any((partner) => partner.id == _selected)
            ? _selected
            : null,
        decoration: const InputDecoration(labelText: 'Delivery partner'),
        items: [
          for (final partner in widget.partners)
            DropdownMenuItem(
              value: partner.id,
              child: Text(partner.displayName),
            ),
        ],
        onChanged: (value) => setState(() => _selected = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Confirm assignment'),
        ),
      ],
    );
  }
}

class _NeedsPartnerAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NeedsPartnerAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.accentPinkSoft,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.accentPink,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '$count orders need a delivery partner',
                style: const TextStyle(
                  color: AppColors.accentPink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _DeliverySummaryCards extends StatelessWidget {
  final int unassigned;
  final int assigned;
  final int outForDelivery;

  const _DeliverySummaryCards({
    required this.unassigned,
    required this.assigned,
    required this.outForDelivery,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = [
      ('Unassigned', unassigned, Icons.inventory_2_outlined, AppColors.primary),
      (
        'Assigned',
        assigned,
        Icons.delivery_dining_rounded,
        AppColors.badgeGreen,
      ),
      (
        'Out for delivery',
        outForDelivery,
        Icons.check_circle_outline,
        AppColors.accentPink,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < summaries.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    summaries[index].$3,
                    color: summaries[index].$4,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summaries[index].$2}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    summaries[index].$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DeliveryFilters extends StatelessWidget {
  final _DeliveryFilter selected;
  final ValueChanged<_DeliveryFilter> onSelected;

  const _DeliveryFilters({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => SegmentedButton<_DeliveryFilter>(
    showSelectedIcon: false,
    style: const ButtonStyle(
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
    segments: const [
      ButtonSegment(value: _DeliveryFilter.all, label: Text('All')),
      ButtonSegment(
        value: _DeliveryFilter.unassigned,
        label: Text('Unassigned'),
      ),
      ButtonSegment(value: _DeliveryFilter.assigned, label: Text('Assigned')),
    ],
    selected: {selected},
    onSelectionChanged: (selection) => onSelected(selection.first),
  );
}

class _DeliveryStatusPill extends StatelessWidget {
  final String status;

  const _DeliveryStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'delivered' => AppColors.badgeGreen,
      'out_for_delivery' => AppColors.accentPink,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AssignmentMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool loading;
  final Future<void> Function()? action;

  const _AssignmentMessage({
    required this.icon,
    required this.message,
    this.loading = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            if (loading)
              const CircularProgressIndicator(color: AppColors.accentPink)
            else
              Icon(icon, size: 30, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null)
              TextButton(onPressed: action, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
