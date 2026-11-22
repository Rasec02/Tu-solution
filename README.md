# Tu Solution — Gestión de reparaciones

Aplicación **Android** para el taller de reparación de celulares, tablets y laptops
*Tu Solution*. Sustituye la libreta y las notas sueltas con las que hoy se controla
el trabajo: registra los equipos que entran, lleva cada orden por su flujo de
estados, deja claro qué técnico tiene tomada cada orden, descuenta los repuestos
del almacén y guarda el historial de todo lo que se le ha hecho a cada equipo.

Funciona **sin conexión a internet** y conserva la información aunque la app se
cierre: todo vive en una base SQLite dentro del teléfono.

- **Asignatura:** Programación para Dispositivos Móviles
- **Tecnología base:** Flutter para Android, con **Drift** (persistencia) y **Riverpod** (estado)
- **Arquitectura:** MVVM

---

## 1. Cómo abrir y ejecutar la aplicación

### Requisitos

| Herramienta | Versión con la que se desarrolló |
|---|---|
| Flutter SDK | 3.50.1 (canal stable) |
| Dart | 3.13.5 |
| Android SDK | API 21 o superior (`minSdk` de Flutter) |
| Emulador o teléfono Android | Android 5.0+ con depuración USB activada |

Comprueba que el entorno está listo:

```powershell
flutter doctor
```

### Pasos

1. **Clonar el repositorio**

```powershell
git clone <URL-DEL-REPOSITORIO>
```

2. **Entrar en la carpeta del proyecto**

```powershell
cd tu_solution
```

3. **Descargar las dependencias**

```powershell
flutter pub get
```

4. **(Opcional) Regenerar el código de Drift**

Los archivos generados (`*.g.dart`) ya vienen versionados, así que este paso
solo hace falta si cambias las tablas o los DAO:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

5. **Conectar el teléfono o arrancar un emulador** y comprobar que Flutter lo ve

```powershell
flutter devices
```

6. **Ejecutar la aplicación**

```powershell
flutter run
```

Para generar el APK instalable:

```powershell
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

7. **Ejecutar las pruebas de las reglas del taller** (opcional)

```powershell
flutter test
```

> **Primer arranque:** la app crea la base de datos y carga los datos mínimos
> con los que el taller empieza a trabajar (los tres técnicos y el almacén de
> repuestos). Los clientes, equipos y órdenes se registran desde la app.
> No hay pantalla de inicio de sesión: la app es solo para los técnicos y
> cualquiera que tenga el teléfono entra directamente, tal como pide el caso.

---

## 2. Qué hace la aplicación

### Tablero

Pantalla de inicio con el estado del taller de un vistazo:

- Cuántas órdenes hay abiertas y cuántas en cada estado.
- Cuántas órdenes abiertas **no ha tomado nadie** todavía.
- La **carga de trabajo de cada técnico** (abiertas, en reparación y listas).
- Los **repuestos por agotarse**.

### Órdenes

- **Recibir equipo:** se registra el cliente (nombre y teléfono), el equipo
  (tipo, marca, modelo y número de serie) y la falla que reporta el dueño. Si el
  cliente o el equipo ya existen, se reutilizan: un mismo dueño puede traer
  varios equipos y un mismo equipo puede volver muchas veces.
- **Lista con filtros** por estado (abiertas, en reparación, listas, cerradas) y
  por técnico, para responder "¿qué órdenes están abiertas y quién las tiene?".
- **Detalle de la orden:** tomar o liberar la orden, mover el estado, anotar el
  diagnóstico, registrar los trabajos realizados con su mano de obra y los
  repuestos utilizados con su cantidad, y ver el **costo total**.

### Almacén

- Inventario de repuestos con nombre, código, precio y existencias.
- Alta y edición de repuestos, y reposición de mercancía.
- Aviso de los repuestos **por agotarse** (existencias en o por debajo del mínimo).
- Bitácora de movimientos de cada repuesto, para saber a dónde fue cada pieza.

### Clientes y equipos

- Listado y búsqueda de clientes con sus equipos.
- **Historial de reparaciones** de un equipo y de un cliente: qué se le reparó,
  qué piezas se le cambiaron y cuánto costó cada visita.

### Técnicos

Alta y edición de los técnicos del taller, con su carga de trabajo.

---

## 3. Reglas del taller que la app hace cumplir

Estas son las decisiones tomadas sobre los puntos que el caso plantea:

| Problema del caso | Cómo lo resuelve la app |
|---|---|
| Dos técnicos reparan el mismo equipo | Una orden tiene **un solo responsable**. Si ya está tomada, otro técnico no puede tomarla: primero hay que liberarla. Además un equipo **no puede tener dos órdenes abiertas** a la vez. |
| Nadie sabe en qué estado está cada equipo | Cada orden lleva su estado visible en la lista y en el tablero: `recibida → en reparación → lista → entregada`, o `cancelada`. Las transiciones inválidas se rechazan, y nadie puede poner una orden *en reparación* sin haberla tomado. |
| El stock no coincide con lo anotado | Usar un repuesto en una orden **descuenta el almacén en la misma transacción** en que se registra la línea: o pasan las dos cosas o no pasa ninguna. No se puede consumir más de lo que hay, y quitar una línea devuelve las piezas. Cada movimiento queda en la bitácora. |
| Un repuesto se agota y se descubre tarde | Cada repuesto tiene un **mínimo**; al llegar a él aparece en "por agotarse" en el tablero y en el almacén. |
| Nadie recuerda qué se le reparó antes | El **historial** por equipo y por cliente guarda los trabajos, las piezas y el total de cada visita. |
| Costo de la reparación | El total de la orden es **mano de obra + repuestos**, con el precio del repuesto congelado en el momento del uso. |

Otras decisiones razonables ante los puntos abiertos del caso:

- **Sin autenticación**, como indica el enunciado. Se puede marcar en el tablero
  qué técnico está usando el teléfono, solo para precargarlo al tomar órdenes.
- **Sin interacción con el cliente**: la app no envía mensajes ni presupuestos.
- El **número de serie** identifica al equipo y no se repite.
- Una orden cerrada (entregada o cancelada) **no admite más** trabajos ni repuestos.

---

## 4. Organización del código

Arquitectura **MVVM** en tres capas: la vista no habla nunca con la base de datos.

```
lib/
├── main.dart                     Arranque: abre la base, carga datos iniciales
├── core/
│   ├── theme.dart                Tema Material 3
│   └── formatters.dart           Dinero, fechas y etiquetas en español
├── domain/                       MODELO
│   ├── order_status.dart         Estados de la orden y transiciones válidas
│   └── views.dart                Objetos que consume la vista (OrderSummary…)
├── data/
│   ├── database/
│   │   ├── tables.dart           Tablas Drift
│   │   ├── app_database.dart     Base SQLite (@DriftDatabase)
│   │   └── daos/                 Consultas: catálogo, órdenes, inventario
│   ├── repositories/
│   │   └── workshop_repository.dart   Reglas del negocio (única puerta a los datos)
│   └── seed.dart                 Técnicos y almacén del primer arranque
└── presentation/
    ├── providers.dart            Providers de Riverpod (inyección + streams)
    ├── viewmodels/               VIEWMODEL: StateNotifier por caso de uso
    ├── screens/                  VISTA
    └── widgets/                  Piezas de UI reutilizables
```

- **Modelo:** las tablas de Drift y las reglas del `WorkshopRepository`.
- **ViewModel:** los `StateNotifier` de `presentation/viewmodels`. Reciben las
  acciones de la vista, llaman al repositorio y exponen el resultado como estado
  (cargando / listo / error con el mensaje para el técnico).
- **Vista:** widgets `ConsumerWidget` que observan providers y no contienen
  lógica de negocio.

La UI se actualiza sola: los DAO devuelven `Stream` de Drift, así que al cambiar
una orden o el stock, el tablero, las listas y los avisos se refrescan sin
intervención.

### Base de datos

| Tabla | Para qué |
|---|---|
| `clients` | Dueños de los equipos |
| `devices` | Equipos, con su número de serie, ligados a un cliente |
| `technicians` | Los técnicos del taller |
| `repair_orders` | Cada visita del equipo: estado, responsable, falla, fechas |
| `order_jobs` | Trabajos realizados, con su mano de obra |
| `spare_parts` | Inventario: nombre, código, precio, existencias y mínimo |
| `order_parts` | Repuestos usados en una orden, con cantidad y precio del momento |
| `stock_movements` | Bitácora de entradas y salidas del almacén |

---

## 5. Pruebas

`test/workshop_repository_test.dart` comprueba las reglas del taller sobre una
base SQLite en memoria: que una orden tomada no la pueda tomar otro técnico, que
el flujo de estados no admita saltos, que el stock se descuente y se reponga,
que no se pueda consumir más de lo que hay, que el total sea mano de obra más
repuestos, que avise los repuestos por agotarse y que el historial guarde
trabajos y piezas.

```powershell
flutter test
```

---

## 6. Capturas de pantalla

Las capturas de la aplicación corriendo están en [`screenshots/`](screenshots/).
