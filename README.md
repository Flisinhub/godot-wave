# 🌌 SFE5 — Godot Engine 4.7.2

Clon de **Special Forces Elite 5 (SFE5)** desarrollado en **Godot Engine 4.7.2** (Forward+ / Jolt Physics 3D) con GDScript de tipado estático estricto. Supervivencia táctica, microgestión, enjambres masivos y combate heroico en el planeta volcánico de Char.

---

## 📖 Planificación y Diseño

La única fuente viva de planificación y arquitectura del proyecto es:
👉 **[ROADMAP.md](./ROADMAP.md)**

Para fundamentos de diseño y fórmulas de referencia contrastadas con la wiki de SFE5:
👉 **[DESIGN_NOTES.md](./docs/DESIGN_NOTES.md)**

---

## 🎮 Cómo Jugar (Inicio Rápido)

1. Abre el proyecto en **Godot Engine 4.7.2** (`project.godot`).
2. Presiona **F5** para iniciar la escena principal (`res://levels/main_level.tscn`).
3. En el modal de inicio:
   - Selecciona dificultad (`Casual` a `Torment`).
   - Elige Héroe o pulsa `🎲 RANDOM HERO` para bonus de mineral inicial.
   - Confirma el despliegue y defiende la brecha de la base.

### Controles Principales (Estilo StarCraft II):
* **Cámara RTS:** Mover el cursor a los bordes de la pantalla (*Edge Scroll*) o mantener pulsado el **Botón Central del Ratón** para arrastrar. Rueda para zoom. Flechas del teclado como alternativa.
* **Selección:** Clic izquierdo (individual o caja de arrastre).
* **Mover / Atacar:** Clic derecho para mover / `A` + Clic izquierdo para Attack-Move.
* **Órdenes de Héroe:** `S` (Stop), `H` (Hold Position).
* **Habilidades Activas:** Teclas `Q`, `W`, `E`, `R`.
* **Armería:** Tecla `E` cerca de la terminal para abrir el menú de mejoras.

---

## 🧪 Verificación Automatizada (Tests)

Ejecutar la suite completa de pruebas en modo headless:
```bash
godot --headless --path . -s tests/test_runner.gd
```

Verificar arranque limpio de la escena principal sin entorno gráfico:
```bash
godot --headless --path . --quit-after 200 "res://levels/main_level.tscn"
```
