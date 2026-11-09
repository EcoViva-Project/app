import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

class CommunityComment {
  CommunityComment({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.timeLabel,
  });

  final String id;
  final String authorName;
  final String authorInitials;
  final String content;
  final String timeLabel;

  factory CommunityComment.fromApi(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'].toString(),
      authorName: json['authorName'] as String? ?? 'Vizinho',
      authorInitials: json['authorInitials'] as String? ?? '??',
      content: json['content'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
    );
  }
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.likes,
    required this.likedByMe,
    required this.isMine,
    required this.timeLabel,
    required this.comments,
  });

  final String id;
  final String authorName;
  final String authorInitials;
  final String content;
  final int likes;
  final bool likedByMe;

  /// A publicação é do usuário logado (pode ser excluída por ele).
  final bool isMine;
  final String timeLabel;
  final List<CommunityComment> comments;

  CommunityPost copyWith({
    int? likes,
    bool? likedByMe,
    List<CommunityComment>? comments,
  }) => CommunityPost(
    id: id,
    authorName: authorName,
    authorInitials: authorInitials,
    content: content,
    likes: likes ?? this.likes,
    likedByMe: likedByMe ?? this.likedByMe,
    isMine: isMine,
    timeLabel: timeLabel,
    comments: comments ?? this.comments,
  );

  factory CommunityPost.fromApi(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'].toString(),
      authorName: json['authorName'] as String? ?? 'Vizinho',
      authorInitials: json['authorInitials'] as String? ?? '??',
      content: json['content'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? false,
      timeLabel: json['timeLabel'] as String? ?? '',
      comments:
          ((json['comments'] as List?) ?? const [])
              .map(
                (item) =>
                    CommunityComment.fromApi(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

/// Feed da comunidade. É a única fonte das publicações para as telas.
class CommunityService extends ChangeNotifier {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final List<CommunityPost> _posts = [];
  final Set<String> _likesInFlight = {};
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<CommunityPost> get posts => List.unmodifiable(_posts);

  bool get isLoaded => _loaded;

  bool get loading => _loading;

  String? get error => _error;

  CommunityPost? byId(String id) {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    try {
      final data = await ApiClient.instance.get('/community/posts');
      _posts
        ..clear()
        ..addAll(
          ((data['posts'] as List?) ?? const []).map(
            (item) => CommunityPost.fromApi(item as Map<String, dynamic>),
          ),
        );
      _loaded = true;
    } catch (error) {
      _error = describeLoadError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CommunityPost> createPost(String content) async {
    final data = await ApiClient.instance.post('/community/posts', {
      'content': content,
    });
    final post = CommunityPost.fromApi(data['post'] as Map<String, dynamic>);
    _posts.insert(0, post);
    notifyListeners();
    return post;
  }

  /// Alterna a curtida. Toques repetidos enquanto a requisição está em
  /// andamento são ignorados.
  Future<void> toggleLike(String id) async {
    if (!_likesInFlight.add(id)) return;
    try {
      final data = await ApiClient.instance.post('/community/posts/$id/like');
      final index = _posts.indexWhere((post) => post.id == id);
      if (index < 0) return;
      _posts[index] = _posts[index].copyWith(
        likes: (data['likes'] as num?)?.toInt(),
        likedByMe: data['likedByMe'] as bool?,
      );
      notifyListeners();
    } finally {
      _likesInFlight.remove(id);
    }
  }

  Future<CommunityComment> addComment(String postId, String content) async {
    final data = await ApiClient.instance.post(
      '/community/posts/$postId/comments',
      {'content': content},
    );
    final comment = CommunityComment.fromApi(
      data['comment'] as Map<String, dynamic>,
    );
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index >= 0) {
      _posts[index] = _posts[index].copyWith(
        comments: [..._posts[index].comments, comment],
      );
      notifyListeners();
    }
    return comment;
  }

  /// Exclui uma publicação do próprio usuário.
  Future<void> deletePost(String id) async {
    await ApiClient.instance.delete('/community/posts/$id');
    _posts.removeWhere((post) => post.id == id);
    notifyListeners();
  }

  void reset() {
    _posts.clear();
    _likesInFlight.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
