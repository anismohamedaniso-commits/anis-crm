import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/models/lead.dart';

void main() {
  final now = DateTime(2026, 2, 11, 10, 0);

  group('LeadModel', () {
    final sampleLead = LeadModel(
      id: 'lead-1',
      name: 'Alice',
      status: LeadStatus.fresh,
      phone: '+1234567890',
      email: 'alice@example.com',
      source: LeadSource.whatsapp,
      campaign: 'Campaign A',
      createdAt: now,
      updatedAt: now,
      lastContactedAt: now.subtract(const Duration(hours: 2)),
      nextFollowupAt: now.add(const Duration(days: 1)),
    );

    test('toJson and fromJson round-trip preserves all fields', () {
      final json = sampleLead.toJson();
      final restored = LeadModel.fromJson(json);

      expect(restored.id, sampleLead.id);
      expect(restored.name, sampleLead.name);
      expect(restored.status, sampleLead.status);
      expect(restored.phone, sampleLead.phone);
      expect(restored.email, sampleLead.email);
      expect(restored.source, sampleLead.source);
      expect(restored.campaign, sampleLead.campaign);
    });

    test('copyWith changes only specified fields', () {
      final updated = sampleLead.copyWith(name: 'Bob', status: LeadStatus.interested);

      expect(updated.name, 'Bob');
      expect(updated.status, LeadStatus.interested);
      expect(updated.id, sampleLead.id);
      expect(updated.phone, sampleLead.phone);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'lead-2',
        'name': 'Minimal Lead',
        'status': 'fresh',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final lead = LeadModel.fromJson(json);

      expect(lead.id, 'lead-2');
      expect(lead.name, 'Minimal Lead');
      expect(lead.phone, isNull);
      expect(lead.email, isNull);
      expect(lead.campaign, isNull);
      expect(lead.lastContactedAt, isNull);
      expect(lead.nextFollowupAt, isNull);
    });
  });

  group('LeadStatusX', () {
    test('fromName parses known statuses', () {
      expect(LeadStatusX.fromName('fresh'), LeadStatus.fresh);
      expect(LeadStatusX.fromName('interested'), LeadStatus.interested);
      expect(LeadStatusX.fromName('noAnswer'), LeadStatus.noAnswer);
      expect(LeadStatusX.fromName('followUp'), LeadStatus.followUp);
      expect(LeadStatusX.fromName('notInterested'), LeadStatus.notInterested);
      expect(LeadStatusX.fromName('converted'), LeadStatus.converted);
      expect(LeadStatusX.fromName('closed'), LeadStatus.closed);
    });

    test('fromName returns fresh for null or unknown', () {
      expect(LeadStatusX.fromName(null), LeadStatus.fresh);
      expect(LeadStatusX.fromName('bogus'), LeadStatus.fresh);
    });
  });

  group('LeadSourceX', () {
    test('fromName parses known sources', () {
      expect(LeadSourceX.fromName('manual'), LeadSource.manual);
      expect(LeadSourceX.fromName('whatsapp'), LeadSource.whatsapp);
      expect(LeadSourceX.fromName('email'), LeadSource.email);
      expect(LeadSourceX.fromName('phone'), LeadSource.phone);
      expect(LeadSourceX.fromName('facebook'), LeadSource.facebook);
      expect(LeadSourceX.fromName('instagram'), LeadSource.instagram);
      expect(LeadSourceX.fromName('linkedin'), LeadSource.linkedin);
      expect(LeadSourceX.fromName('tiktok'), LeadSource.tiktok);
      expect(LeadSourceX.fromName('imported'), LeadSource.imported);
    });

    test('fromName handles alternate web names', () {
      expect(LeadSourceX.fromName('web'), LeadSource.web);
      expect(LeadSourceX.fromName('website'), LeadSource.web);
      expect(LeadSourceX.fromName('websiteForm'), LeadSource.web);
    });

    test('fromName returns whatsapp for null or unknown', () {
      expect(LeadSourceX.fromName(null), LeadSource.whatsapp);
      expect(LeadSourceX.fromName('unknown_source'), LeadSource.whatsapp);
    });
  });
}
