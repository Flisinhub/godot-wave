# Godot RTS Base Defense (Sprint 1)

Juego 3D de estrategia en tiempo real (RTS) y defensa de base por oleadas desarrollado en **Godot Engine 4.7.2** con GDScript estricto, inspirado en la estética y mecánicas de StarCraft II.

---

## 🚀 Características Implementadas (Sprint 1)

- **Arquitectura Desacoplada:**
  - `SignalBus` global como Autoload para comunicación reactiva entre entidades, cámara, UI y controladores.
  - **Separación Lógica/Arte:** Todas las entidades 3D poseen un nodo hijo `VisualRoot` independiente para permitir sustitución ágil de mallas sin alterar scripts.
  - Tipado estático estricto en GDScript (`@export`, `@onready`, retornos y parámetros tipados).

- **Cámara RTS Estilo StarCraft II (`RTSCamera3D`):**
  - Inclinación isométrica a 55° sobre el plano XZ.
  - Desplazamiento fluido mediante teclas WASD / Flechas (+ Shift para velocidad aumentada).
  - "Edge Scrolling" configurable en bordes de pantalla.
  - Zoom suave con rueda del ratón y límites de elevación (`min_zoom_height` / `max_zoom_height`).
  - Restricción dentro de los límites del mapa (`map_bounds`).

- **Micromanejo y Selección RTS (`RTSController`):**
  - **Selección Individual:** Clic izquierdo con Raycast 3D.
  - **Caja de Selección (Box Selection):** Arrastre de clic izquierdo con dibujo 2D en UI de un marco verde translúcido estilo SC2 (`SelectionBoxUI`).
  - **Órdenes de Movimiento con Clic Derecho:** Cálculo táctico de formación en cuadrícula (~1.6m de espaciado) para evitar empujes o colisiones infinitas entre unidades.
  - **Feedback Visual:** Indicador circular animado (`MoveIndicator`) en el punto de destino.

- **Defensa de Base y Compuertas:**
  - Núcleo central Terran (`CommandCenter`).
  - Perímetro defensivo con segmentos de muro (`WallSegment`).
  - **Compuertas Inteligentes (`GateStructure`):** Apertura/cierre vertical automatizado por proximidad ante unidades aliadas (`Area3D`), o manual mediante clic, con indicadores lumínicos de estado (Rojo/Verde).

- **Escenario Volcánico:**
  - Iluminación dramática estilo planeta Char (`DirectionalLight3D` + sombras, `WorldEnvironment` con Glow/Bloom y tonemapper ACES).
  - `NavigationRegion3D` configurada para horneado eficiente en tiempo de ejecución.

---

## 🎮 Controles

| Acción | Control |
|---|---|
| **Seleccionar unidad** | Clic Izquierdo |
| **Caja de selección múltiple** | Arrastrar con Clic Izquierdo |
| **Añadir / quitar de selección** | Shift + Clic Izquierdo / Arrastre |
| **Mover unidades (en formación)** | Clic Derecho en terreno |
| **Alternar compuerta** | Clic sobre la compuerta o aproximar unidades |
| **Mover cámara** | Teclas W, A, S, D / Flechas o ratón en bordes |
| **Desplazamiento rápido** | Shift + Teclas de movimiento |
| **Zoom** | Rueda del ratón |

---

## 🛠️ Requisitos de Ejecución

- **Godot Engine 4.x** (probado y optimizado en Godot 4.7.2).
- Abrir el proyecto en Godot y presionar **F5** (la escena principal es `res://levels/main_level.tscn`).
