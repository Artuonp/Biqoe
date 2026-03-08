// Stub para plataformas no-web (Android nativo, iOS nativo).
// No hace nada — en nativo el email se envía via http directamente.

void sendNoCorsPost(String url, String jsonBody) {
  // No-op en nativo
}

bool isSafariBrowser() => false; // Nunca es Safari en nativo
