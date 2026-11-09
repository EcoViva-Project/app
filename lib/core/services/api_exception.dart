/// Erro devolvido pela API (remota ou local), com mensagem pronta para a tela.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Mensagem para mostrar quando uma carga de dados falha, qualquer que seja
/// o tipo do erro.
String describeLoadError(Object error) =>
    error is ApiException
        ? error.message
        : 'Não foi possível carregar os dados. Tente de novo.';
