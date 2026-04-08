import 'player_model.dart';

enum ActionReportType {
  mafiaKill,
  bountyKill,
  doctorSave,
  copInvestigate,
  nurseFindsDoctor;

  factory ActionReportType.fromString(String val) {
    switch (val) {
      case 'mafia_kill':
        return ActionReportType.mafiaKill;
      case 'bounty_kill':
        return ActionReportType.bountyKill;
      case 'doctor_save':
        return ActionReportType.doctorSave;
      case 'cop_investigate':
        return ActionReportType.copInvestigate;
      case 'nurse_finds_doctor':
        return ActionReportType.nurseFindsDoctor;
      default:
        return ActionReportType.mafiaKill;
    }
  }
}

/// Broadcast to all clients when a major night action succeeds/completes
class ActionReport {
  final ActionReportType type;
  
  // Specific data regarding the event (e.g. target name, role found, etc).
  // Kept flexible so the backend can send arbitrary string payloads.
  final String title;
  final String description;
  final String? targetName;
  final String? roleName; // Use if investigating or revealing a role
  final double? precision;
  final int? xpGained;

  const ActionReport({
    required this.type,
    required this.title,
    required this.description,
    this.targetName,
    this.roleName,
    this.precision,
    this.xpGained,
  });

  factory ActionReport.fromJson(Map<String, dynamic> json) {
    return ActionReport(
      type: ActionReportType.fromString(json['type'] as String? ?? ''),
      title: json['title'] as String? ?? 'ACTION REPORT',
      description: json['description'] as String? ?? 'Action recorded in system logs.',
      targetName: json['targetName'] as String?,
      roleName: json['roleName'] as String?,
      precision: (json['precision'] as num?)?.toDouble(),
      xpGained: json['xpGained'] as int?,
    );
  }
}
