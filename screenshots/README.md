# Capturas de pantalla

Aquí van las capturas reales de la aplicación corriendo en un emulador o en un
teléfono Android, como pide la entrega.

## Cómo tomarlas

Con la app corriendo (`flutter run`) y el dispositivo conectado:

```powershell
adb exec-out screencap -p > screenshots/01-tablero.png
```

Repite el comando cambiando el nombre del archivo en cada pantalla. En un
emulador también sirve el botón de cámara de la barra lateral.

## Pantallas que conviene mostrar

| Archivo sugerido | Qué debe verse |
|---|---|
| `01-tablero.png` | Conteos por estado, órdenes sin tomar, carga de los técnicos y repuestos por agotarse |
| `02-ordenes.png` | Lista de órdenes con los filtros por estado y por técnico |
| `03-recibir-equipo.png` | Formulario de entrada: cliente, equipo y falla reportada |
| `04-detalle-orden.png` | Orden tomada por un técnico, con trabajos, repuestos y costo total |
| `05-detalle-orden-estados.png` | Cambio de estado de la orden |
| `06-almacen.png` | Inventario con existencias y precios |
| `07-por-agotarse.png` | Aviso de repuestos por agotarse |
| `08-clientes.png` | Listado de clientes con sus equipos |
| `09-historial-equipo.png` | Historial de reparaciones de un equipo |
| `10-tecnicos.png` | Técnicos del taller y su carga de trabajo |
