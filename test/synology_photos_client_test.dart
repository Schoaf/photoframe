import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_display/models/photo_item.dart';
import 'package:ha_display/services/synology_photos_client.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _json(Map<String, dynamic> body) =>
    Response(requestOptions: RequestOptions(), data: body);

void main() {
  late _MockDio dio;
  late SynologyPhotosClient client;
  late List<Map<String, dynamic>> calls;
  late List<String> urls;
  late List<Map<String, dynamic>> responses;

  setUp(() {
    dio = _MockDio();
    calls = [];
    urls = [];
    responses = [];
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      urls.add(invocation.positionalArguments.first as String);
      calls.add(
        invocation.namedArguments[#queryParameters] as Map<String, dynamic>,
      );
      return _json(responses.removeAt(0));
    });
    client = SynologyPhotosClient(
      baseUrl: 'http://nas:5000/',
      user: 'frame',
      password: 'secret',
      dio: dio,
    );
  });

  Map<String, dynamic> loginOk(String sid) => {
    'success': true,
    'data': {'sid': sid},
  };

  test('logs in, then lists the album items with the session id', () async {
    responses = [
      loginOk('sid1'),
      {
        'success': true,
        'data': {
          'list': [
            {
              'id': 7,
              'filename': 'a.jpg',
              'type': 'photo',
              'time': 1700000000,
              'additional': {
                'thumbnail': {'unit_id': 70, 'cache_key': '70_1'},
                'address': {'city': 'Wien', 'country': 'Österreich'},
              },
            },
            {
              'id': 8,
              'filename': 'b.mp4',
              'type': 'video',
              'additional': {
                'thumbnail': {'unit_id': 80, 'cache_key': '80_1'},
                'video_convert': [
                  {'quality': 'medium'},
                ],
              },
            },
          ],
        },
      },
    ];

    final items = await client.listAlbumItems(3);

    expect(calls[0]['api'], 'SYNO.API.Auth');
    expect(calls[0]['account'], 'frame');
    expect(calls[1]['api'], 'SYNO.Foto.Browse.Item');
    expect(calls[1]['album_id'], '3');
    expect(calls[1]['_sid'], 'sid1');
    expect(items, hasLength(2));
    expect(items[0].unitId, 70);
    expect(items[0].place, 'Wien, Österreich');
    expect(items[0].takenAt, isNotNull);
    expect(items[0].isVideo, isFalse);
    expect(items[1].isVideo, isTrue);
    expect(items[1].hasConvertedVideo, isTrue);
  });

  test('logs in again when the session expired', () async {
    responses = [
      loginOk('old'),
      {
        'success': false,
        'error': {'code': 119},
      },
      loginOk('new'),
      {
        'success': true,
        'data': {
          'list': [
            {'id': 1, 'name': 'FotoFrame', 'item_count': 12},
          ],
        },
      },
      {
        'success': true,
        'data': {'list': <Object>[]},
      },
    ];

    final albums = await client.listAlbums();

    expect(albums.single.name, 'FotoFrame');
    expect(albums.single.itemCount, 12);
    expect(calls[3]['_sid'], 'new');
  });

  test('logs in with the webui session', () async {
    responses = [loginOk('sid1')];

    await client.login();

    expect(urls, ['http://nas:5000/webapi/entry.cgi']);
    expect(calls.single['session'], 'webui');
  });

  test(
    'lists own and shared albums; a shared one keeps its passphrase',
    () async {
      responses = [
        loginOk('sid1'),
        {
          'success': true,
          'data': {
            'list': [
              {'id': 1, 'name': 'Urlaub', 'item_count': 3, 'passphrase': 'own'},
            ],
          },
        },
        {
          'success': true,
          'data': {
            'list': [
              {
                'id': 6,
                'name': 'Fotorahmen',
                'item_count': 2,
                'passphrase': 'abc',
              },
            ],
          },
        },
      ];

      final albums = await client.listAlbums();

      expect(calls[2]['method'], 'list_shared_with_me_album');
      expect(albums.map((album) => album.passphrase), ['', 'abc']);
    },
  );

  test('a shared album is read with its passphrase', () async {
    final shared = SynologyPhotosClient(
      baseUrl: 'http://nas:5000',
      user: 'frame',
      password: 'secret',
      passphrase: 'abc',
      dio: dio,
    );
    responses = [
      loginOk('sid1'),
      {
        'success': true,
        'data': {'list': <Object>[]},
      },
    ];

    await shared.listAlbumItems(6);
    const item = PhotoItem(
      id: 7,
      unitId: 70,
      cacheKey: '70_1',
      filename: 'a.jpg',
      isVideo: false,
    );

    expect(calls[1]['passphrase'], 'abc');
    expect(calls[1].containsKey('album_id'), isFalse);
    expect(
      Uri.parse(shared.thumbnailUrl(item, size: ThumbnailSize.sm))
          .queryParameters['passphrase'],
      'abc',
    );
  });

  test('reports a wrong password as a login error', () async {
    responses = [
      {
        'success': false,
        'error': {'code': 400},
      },
    ];

    expect(
      client.listAlbums(),
      throwsA(
        isA<SynologyException>().having(
          (e) => e.isWrongPassword,
          'wrong password',
          true,
        ),
      ),
    );
  });

  test('builds thumbnail URLs from unit id and cache key', () async {
    responses = [loginOk('sid1')];
    await client.login();
    const item = PhotoItem(
      id: 7,
      unitId: 70,
      cacheKey: '70_1',
      filename: 'a.jpg',
      isVideo: false,
    );

    final url = Uri.parse(client.thumbnailUrl(item, size: ThumbnailSize.xl));

    expect(url.origin, 'http://nas:5000');
    expect(url.path, '/webapi/entry.cgi');
    expect(url.queryParameters, containsPair('id', '70'));
    expect(url.queryParameters, containsPair('cache_key', '70_1'));
    expect(url.queryParameters, containsPair('size', 'xl'));
    expect(url.queryParameters, containsPair('_sid', 'sid1'));
  });
}
