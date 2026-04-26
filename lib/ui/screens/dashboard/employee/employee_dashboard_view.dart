import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../../constants/app_colors.dart';
import 'employee_dashboard_viewmodel.dart';

class EmployeeDashboardView extends StatelessWidget {
  const EmployeeDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<EmployeeDashboardViewModel>.reactive(
      viewModelBuilder: () => EmployeeDashboardViewModel(),
      onViewModelReady: (model) => model.init(),
      builder: (context, model, child) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xff2F2061),
            elevation: 0,
            title: const Text(
              'HippoCloud CRM',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: model.logout,
              ),
            ],
          ),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: Palette.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserCard(model),
                      const SizedBox(height: 24),
                      const Text('My Overview',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0E0E0E))),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'My Tasks',
                              value: '—',
                              icon: Icons.task_alt_outlined,
                              color: Palette.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Leave Balance',
                              value: '—',
                              icon: Icons.beach_access_outlined,
                              color: const Color(0xff0F9E35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Attendance',
                              value: '—',
                              icon: Icons.access_time_outlined,
                              color: Color(0xff2F2061),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Pending',
                              value: '—',
                              icon: Icons.hourglass_empty_outlined,
                              color: Color(0xffC42B61),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text('Quick Actions',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0E0E0E))),
                      const SizedBox(height: 12),
                      _ActionTile(
                        icon: Icons.task_alt_outlined,
                        title: 'My Tasks',
                        subtitle: 'View and update your tasks',
                        color: Palette.primary,
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.beach_access_outlined,
                        title: 'Leave Requests',
                        subtitle: 'Apply and track leaves',
                        color: const Color(0xff0F9E35),
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.access_time_outlined,
                        title: 'Attendance',
                        subtitle: 'Check in / check out',
                        color: const Color(0xff2F2061),
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.person_outline,
                        title: 'My Profile',
                        subtitle: 'View and edit your profile',
                        color: const Color(0xff505050),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildUserCard(EmployeeDashboardViewModel model) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2F2061), Palette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2F2061).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              model.userName.isNotEmpty ? model.userName[0].toUpperCase() : 'E',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12)),
                Text(model.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(model.role,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xff716E6E))),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff716E6E))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xff979797)),
          ],
        ),
      ),
    );
  }
}
