# PuntoNeutro — Resumen ejecutivo

Esta carpeta contiene la aplicación móvil/desktop/web PuntoNeutro, una app de consumo de noticias con valoraciones y comentarios en tiempo real, analytics de engagement y soporte multiplataforma.

Qué tiene la aplicación
- Feed de noticias con detalle por noticia.
- Valoración por noticia: slider de fiabilidad y comentario opcional.
- Comentarios: lista y publicación (inline + input flotante sincronizado).
- Overlays flotantes (single-instance) que atenúan el resto de la pantalla y mantienen el control activo sin duplicarlo.
- Observadores realtime para ratings y comentarios (actualización en vivo desde Supabase).
- Tracking / Analytics de engagement (eventos: rating started/given, comment started/completed).
- Persistencia local para cache (Hive) y soporte para autenticación/biometría (Supabase + biometric vault).

Qué hace (valor para producto)
- Permite a los usuarios leer y valorar noticias rápidamente, con feedback cuantitativo (slider) y cualitativo (comentarios).
- Sincroniza actividad en tiempo real entre usuarios usando Supabase Realtime (ideal para productos con análisis de interacción inmediata).
- Captura eventos de engagement para alimentar dashboards / modelos analíticos.
- UX pulida: overlays animados, gestión de foco/teclado, y borradores compartidos entre inline y overlay.

Qué usa (stack técnico)
- Flutter (multiplataforma: Android, iOS, Web, Windows, macOS, Linux).
- Supabase: Auth, Realtime y base de datos (scripts SQL en `sql/`).
- Hive (local caching), Provider (estado), `supabase_flutter`, `hive_flutter` y `biometric_storage`.
- Otras dependencias notables: `local_auth`, `fl_chart`, `connectivity_plus`, `geolocator`.

Dónde mirar en el código (enlaces directos a bloques relevantes)
- UI principal de detalle y contenido general: `lib/presentation/screens/news_detail_screen.dart:11-400`
- Tarjeta de valoración (RateCard) y overlay flotante: `lib/presentation/screens/news_detail_screen.dart:408-780`
- Sección de comentarios y overlay de comentario: `lib/presentation/screens/news_detail_screen.dart:874-1262`
- Estado y borrador compartido (ViewModel): `lib/view_models/news_detail_viewmodel.dart:1-260` (contiene `commentDraftController` y la lógica realtime)
- Dimming contextual y utilidades (BrightnessService): `lib/core/brightness_service.dart:1-200`
- Observers realtime (RatingObserver / CommentTracker): `lib/core/observers/rating_observer.dart:1-200`, `lib/core/observers/comment_tracker.dart:1-200`
- Analytics y tracking (session/events): `lib/core/analytics_service.dart:1-200`
- Inicialización (Supabase, Hive): `lib/main.dart:1-60` (revisa `Supabase.initialize` aquí)

Notas operativas rápidas
- En `lib/main.dart` se inicializa Supabase con una URL y anonKey para desarrollo; extraer a variables de entorno antes de publicar.
- Los scripts SQL en `sql/` deben aplicarse en el proyecto de Supabase que vayas a usar (contienen tablas y reglas RLS asociadas a analytics y sessions).


---

## Realtime & Observers

- `RatingObserver` y `CommentTracker` (en `lib/core/observers/`) suscriben a streams de Supabase y llaman callbacks que actualizan los ViewModels.
- `NewsDetailViewModel` registra los observers y actualiza `liveRatings` y la lista de comentarios en tiempo real.
- `AnalyticsService` se utiliza para trackear eventos importantes (rating started/given, comment started/completed) y facilita flush sobre dispose.

---

## Base de datos y SQL (Supabase)

En el directorio `sql/` hay varios scripts, por ejemplo:

- `2025-10-19_create_engagement_events.sql` — creación de tablas para eventos de engagement.
- `2025-10-21_fix_engagement_events_rls.sql` — reglas RLS para las tablas de analytics.

Recomendación para despliegue: ejecutar los scripts en el mismo orden que aparecen, revisar las RLS y probar sus efectos con una cuenta de servicio. Puedo generar `DEPLOY.md` con pasos, comandos `psql`/Supabase CLI y recomendaciones de seguridad.

---

## Tests y verificación

- Hay tests básicos en `test/` (ej. `widget_test.dart`).
---

## Seguridad y configuración de claves

- Actualmente `lib/main.dart` contiene una URL y anonKey de Supabase embebidas para desarrollo.

---

## Contacto rápido del código (para reviewers)

- UI crítica: `lib/presentation/screens/news_detail_screen.dart`
- Lógica de estado: `lib/view_models/news_detail_viewmodel.dart`
- Servicios y observers: `lib/core/` (busca `brightness`, `observers`, `analytics`)
- Scripts SQL: `sql/`

---

