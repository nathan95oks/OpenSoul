import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/dictionary/data/asset_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/dictionary/data/lexicon_cache.dart';
import 'package:lsb_legal_app/core/dictionary/data/lexicon_repository_impl.dart';
import 'package:lsb_legal_app/core/dictionary/data/proposal_outbox.dart';
import 'package:lsb_legal_app/core/dictionary/data/remote_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/dictionary/domain/dictionary_document.dart';
import 'package:lsb_legal_app/core/dictionary/domain/dictionary_proposal.dart';

/// Pruebas del envío de propuestas del diccionario evolutivo (Fase 3):
/// entrega directa, cola offline (outbox), reenvío en sincronización y
/// fallo total. La regla central: una propuesta redactada nunca se pierde
/// en silencio — todo desenlace es explícito.

const _emptyDoc = DictionaryDocument(
  version: 1,
  dialect: 'cochabamba',
  categoryOrder: [],
  entries: [],
);

class _FakeAsset implements AssetLexiconDataSource {
  @override
  AssetBundle get bundle => throw UnimplementedError();

  @override
  Future<DictionaryDocument> load() async => _emptyDoc;
}

class _FakeRemote implements RemoteLexiconDataSource {
  _FakeRemote({this.configured = true, this.failPosts = false});

  bool configured;
  bool failPosts;
  final List<DictionaryProposal> posted = [];

  @override
  http.Client get client => throw UnimplementedError();

  @override
  String get apiUrl => configured ? 'https://fake/dictionary' : '';

  @override
  bool get isConfigured => configured;

  @override
  Future<DictionaryDocument> fetch() async => _emptyDoc;

  @override
  Future<void> postProposal(DictionaryProposal proposal) async {
    if (failPosts) throw Exception('sin red');
    posted.add(proposal);
  }
}

class _MemoryOutbox implements ProposalOutbox {
  _MemoryOutbox({this.failWrites = false});

  bool failWrites;
  List<DictionaryProposal> items = [];

  @override
  Future<List<DictionaryProposal>> readAll() async => List.of(items);

  @override
  Future<bool> writeAll(List<DictionaryProposal> proposals) async {
    if (failWrites) return false;
    items = List.of(proposals);
    return true;
  }

  @override
  Future<bool> add(DictionaryProposal proposal) async {
    if (failWrites) return false;
    items.add(proposal);
    return true;
  }
}

class _NoCache implements LexiconCache {
  @override
  Future<DictionaryDocument?> read() async => null;

  @override
  Future<void> write(DictionaryDocument document) async {}
}

DictionaryProposal _proposal(String word) =>
    DictionaryProposal(word: word, description: 'significado de $word');

LexiconRepositoryImpl _repo(_FakeRemote remote, _MemoryOutbox outbox) =>
    LexiconRepositoryImpl(
      assetDataSource: _FakeAsset(),
      remoteDataSource: remote,
      cache: _NoCache(),
      outbox: outbox,
    );

void main() {
  test('con backend disponible la propuesta se envía y no queda en cola',
      () async {
    final remote = _FakeRemote();
    final outbox = _MemoryOutbox();

    final result =
        await _repo(remote, outbox).submitProposal(_proposal('MUNICIPIO'));

    expect(result, ProposalSubmissionResult.sent);
    expect(remote.posted.map((p) => p.word), ['MUNICIPIO']);
    expect(outbox.items, isEmpty);
  });

  test('sin red la propuesta queda encolada (queued), no se pierde', () async {
    final remote = _FakeRemote(failPosts: true);
    final outbox = _MemoryOutbox();

    final result =
        await _repo(remote, outbox).submitProposal(_proposal('MUNICIPIO'));

    expect(result, ProposalSubmissionResult.queued);
    expect(outbox.items.map((p) => p.word), ['MUNICIPIO']);
  });

  test('sin endpoint configurado se encola directamente', () async {
    final remote = _FakeRemote(configured: false);
    final outbox = _MemoryOutbox();

    final result =
        await _repo(remote, outbox).submitProposal(_proposal('MUNICIPIO'));

    expect(result, ProposalSubmissionResult.queued);
    expect(remote.posted, isEmpty);
    expect(outbox.items, hasLength(1));
  });

  test('refresh() reenvía la cola pendiente cuando vuelve la conexión',
      () async {
    final remote = _FakeRemote();
    final outbox = _MemoryOutbox()
      ..items = [_proposal('UNO'), _proposal('DOS')];

    await _repo(remote, outbox).refresh();

    expect(remote.posted.map((p) => p.word), ['UNO', 'DOS']);
    expect(outbox.items, isEmpty);
  });

  test('si falla el envío parcial, lo no entregado permanece en cola',
      () async {
    final remote = _FakeRemote(failPosts: true);
    final outbox = _MemoryOutbox()..items = [_proposal('UNO')];

    await _repo(remote, outbox).refresh();

    expect(outbox.items.map((p) => p.word), ['UNO']);
  });

  test('sin red Y sin disco el desenlace es failed (la UI pide reintentar)',
      () async {
    final remote = _FakeRemote(failPosts: true);
    final outbox = _MemoryOutbox(failWrites: true);

    final result =
        await _repo(remote, outbox).submitProposal(_proposal('MUNICIPIO'));

    expect(result, ProposalSubmissionResult.failed);
  });

  test('la propuesta sobrevive el viaje JSON (outbox) sin perder campos', () {
    final original = DictionaryProposal(
      word: 'MUNICIPIO',
      description: 'gobierno local',
      categoryId: 'Instituciones',
      contexts: ['orientacion'],
      videoUrl: 'https://video/x.mp4',
      proposedBy: 'Ana',
    );

    final restored = DictionaryProposal.fromJson(original.toJson());

    expect(restored.word, original.word);
    expect(restored.description, original.description);
    expect(restored.categoryId, original.categoryId);
    expect(restored.contexts, original.contexts);
    expect(restored.videoUrl, original.videoUrl);
    expect(restored.proposedBy, original.proposedBy);
  });
}
