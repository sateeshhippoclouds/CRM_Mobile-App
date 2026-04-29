import 'dart:convert';

class ResourcePermission {
  final bool canRead;
  final bool canWrite;
  final bool canUpdate;
  final bool canDelete;

  const ResourcePermission({
    this.canRead = false,
    this.canWrite = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  static const all = ResourcePermission(
      canRead: true, canWrite: true, canUpdate: true, canDelete: true);
  static const none = ResourcePermission();

  factory ResourcePermission.fromJson(Map<String, dynamic> json) =>
      ResourcePermission(
        canRead: json['can_read'] as bool? ?? false,
        canWrite: json['can_write'] as bool? ?? false,
        canUpdate: json['can_update'] as bool? ?? false,
        canDelete: json['can_delete'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'can_read': canRead,
        'can_write': canWrite,
        'can_update': canUpdate,
        'can_delete': canDelete,
      };
}

class PermissionsModel {
  final int id;
  final String roleName;
  final bool selfOnly;
  final ResourcePermission employees;
  final ResourcePermission bills;
  final ResourcePermission masters;
  final ResourcePermission leads;
  final ResourcePermission clients;
  final ResourcePermission roleManagement;
  final ResourcePermission services;
  final ResourcePermission followup;
  final ResourcePermission task;

  const PermissionsModel({
    required this.id,
    required this.roleName,
    required this.selfOnly,
    required this.employees,
    required this.bills,
    required this.masters,
    required this.leads,
    required this.clients,
    required this.roleManagement,
    required this.services,
    required this.followup,
    required this.task,
  });

  // Company users: all permissions granted
  static const companyDefault = PermissionsModel(
    id: 0,
    roleName: 'Company',
    selfOnly: false,
    employees: ResourcePermission.all,
    bills: ResourcePermission.all,
    masters: ResourcePermission.all,
    leads: ResourcePermission.all,
    clients: ResourcePermission.all,
    roleManagement: ResourcePermission.all,
    services: ResourcePermission.all,
    followup: ResourcePermission.all,
    task: ResourcePermission.all,
  );

  factory PermissionsModel.fromJson(Map<String, dynamic> json) {
    final p = json['permissions'] as Map<String, dynamic>? ?? {};
    return PermissionsModel(
      id: json['id'] as int? ?? 0,
      roleName: json['role_name'] as String? ?? '',
      selfOnly: json['self_only'] as bool? ?? false,
      employees: p['employees'] != null
          ? ResourcePermission.fromJson(
              p['employees'] as Map<String, dynamic>)
          : ResourcePermission.none,
      bills: p['bills'] != null
          ? ResourcePermission.fromJson(p['bills'] as Map<String, dynamic>)
          : ResourcePermission.none,
      masters: p['masters'] != null
          ? ResourcePermission.fromJson(p['masters'] as Map<String, dynamic>)
          : ResourcePermission.none,
      leads: p['leads'] != null
          ? ResourcePermission.fromJson(p['leads'] as Map<String, dynamic>)
          : ResourcePermission.none,
      clients: p['clients'] != null
          ? ResourcePermission.fromJson(p['clients'] as Map<String, dynamic>)
          : ResourcePermission.none,
      roleManagement: p['rolemanagement'] != null
          ? ResourcePermission.fromJson(
              p['rolemanagement'] as Map<String, dynamic>)
          : ResourcePermission.none,
      services: p['services'] != null
          ? ResourcePermission.fromJson(
              p['services'] as Map<String, dynamic>)
          : ResourcePermission.none,
      followup: p['followup'] != null
          ? ResourcePermission.fromJson(
              p['followup'] as Map<String, dynamic>)
          : ResourcePermission.none,
      task: p['task'] != null
          ? ResourcePermission.fromJson(p['task'] as Map<String, dynamic>)
          : ResourcePermission.none,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role_name': roleName,
        'self_only': selfOnly,
        'permissions': {
          'employees': employees.toJson(),
          'bills': bills.toJson(),
          'masters': masters.toJson(),
          'leads': leads.toJson(),
          'clients': clients.toJson(),
          'rolemanagement': roleManagement.toJson(),
          'services': services.toJson(),
          'followup': followup.toJson(),
          'task': task.toJson(),
        },
      };

  String encode() => jsonEncode(toJson());

  static PermissionsModel? decode(String? encoded) {
    if (encoded == null) return null;
    try {
      return PermissionsModel.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
