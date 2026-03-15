import 'package:flutter/material.dart';

/// Lead model with local persistence support.
class LeadModel {
  final String id;
  final String name;
  final LeadStatus status;
  final String? phone;
  final String? email;
  final LeadSource source;
  final String? campaign;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastContactedAt;
  final DateTime? nextFollowupAt;
  final String? assignedTo;
  final String? assignedToName;
  final double? dealValue;
  final String country;

  const LeadModel({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.email,
    this.source = LeadSource.whatsapp,
    this.campaign,
    required this.createdAt,
    required this.updatedAt,
    this.lastContactedAt,
    this.nextFollowupAt,
    this.assignedTo,
    this.assignedToName,
    this.dealValue,
    this.country = 'egypt',
  });

  LeadModel copyWith({
    String? id,
    String? name,
    LeadStatus? status,
    String? phone,
    String? email,
    LeadSource? source,
    String? campaign,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastContactedAt,
    DateTime? nextFollowupAt,
    String? assignedTo,
    String? assignedToName,
    double? dealValue,
    String? country,
  }) => LeadModel(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        source: source ?? this.source,
        campaign: campaign ?? this.campaign,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastContactedAt: lastContactedAt ?? this.lastContactedAt,
        nextFollowupAt: nextFollowupAt ?? this.nextFollowupAt,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,
        dealValue: dealValue ?? this.dealValue,
        country: country ?? this.country,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'phone': phone,
        'email': email,
        'source': source.name,
        'campaign': campaign,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_contacted_at': lastContactedAt?.toIso8601String(),
        'next_followup_at': nextFollowupAt?.toIso8601String(),
        'assigned_to': assignedTo,
        'assigned_to_name': assignedToName,
        'deal_value': dealValue,
        'country': country,
      };

  factory LeadModel.fromJson(Map<String, dynamic> json) => LeadModel(
        id: json['id'] as String,
        name: json['name'] as String,
        status: LeadStatusX.fromName(json['status'] as String?),
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        source: LeadSourceX.fromName(json['source'] as String?),
        campaign: json['campaign'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
        lastContactedAt: DateTime.tryParse(json['last_contacted_at'] as String? ?? ''),
        nextFollowupAt: DateTime.tryParse(json['next_followup_at'] as String? ?? ''),
        assignedTo: json['assigned_to'] as String?,
        assignedToName: json['assigned_to_name'] as String?,
        dealValue: (json['deal_value'] as num?)?.toDouble(),
        country: json['country'] as String? ?? 'egypt',
      );
}

enum LeadStatus { fresh, interested, noAnswer, followUp, notInterested, converted, closed }

enum LeadSource {
  manual,
  whatsapp,
  email,
  phone,
  web, // website form
  facebook,
  instagram,
  linkedin,
  tiktok,
  imported,
  zapier,
}

extension LeadStatusX on LeadStatus {
  static LeadStatus fromName(String? name) {
    switch (name) {
      case 'fresh':
        return LeadStatus.fresh;
      case 'interested':
        return LeadStatus.interested;
      case 'noAnswer':
        return LeadStatus.noAnswer;
      case 'followUp':
        return LeadStatus.followUp;
      case 'notInterested':
        return LeadStatus.notInterested;
      case 'converted':
        return LeadStatus.converted;
      case 'closed':
        return LeadStatus.closed;
      default:
        return LeadStatus.fresh;
    }
  }
}

extension LeadSourceX on LeadSource {
  static LeadSource fromName(String? name) {
    switch (name) {
      case 'manual':
        return LeadSource.manual;
      case 'email':
        return LeadSource.email;
      case 'phone':
        return LeadSource.phone;
      case 'web':
      case 'website':
      case 'websiteForm':
        return LeadSource.web;
      case 'facebook':
        return LeadSource.facebook;
      case 'instagram':
        return LeadSource.instagram;
      case 'linkedin':
        return LeadSource.linkedin;
      case 'tiktok':
        return LeadSource.tiktok;
      case 'imported':
        return LeadSource.imported;
      case 'zapier':
        return LeadSource.zapier;
      case 'whatsapp':
      default:
        return LeadSource.whatsapp;
    }
  }
}
