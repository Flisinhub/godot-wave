# 🌌 Special Forces Elite 5 (SFE5) — Godot Engine 4.7.2

Juego 3D de estrategia en tiempo real (RTS), defensa de base y RPG táctico desarrollado en **Godot Engine 4.7.2** (Forward+ / Jolt Physics 3D) con GDScript de tipado estático estricto, inspirado directamente en el clásico arcade de StarCraft II (*Special Forces Elite*) y ambientado en el hostil planeta volcánico de **Char**.

---

## 🚀 Estado Actual del Proyecto

* **Estado de Pruebas:** **110 / 110 pruebas pasando (100% Verde)** en el ejecutor maestro `tests/test_runner.gd`.
* **Rendimiento:** Simulación masiva boids del Enjambre Zerg (>1.000 unidades en pantalla a >75-95 FPS sostenidos en GPU MultiMesh).
* **Física y Colisiones:** Física anti-túnel blindada (0 penetraciones de muros o compuertas bajo congestión extrema).
* **Fidelidad Visual StarCraft II:** Modelos tridimensionales `.glb` binarios integrados con materiales PBR y jerarquía de `AnimationPlayer` dentro de `VisualRoot` (Marines, Jim Raynor, Centro de Mando, Búnker, Torreta Automática, Zerglings, Roaches, Banelings e Hydralisks).

---

## 📖 Documentación Completa y Guía de Traspaso (Handoff)

Si vas a colaborar o continuar con el desarrollo del proyecto, consulta la guía maestra detallada:
👉 **[PROJECT_HANDOFF.md](./PROJECT_HANDOFF.md)**

En ella encontrarás:
1. Instrucciones de instalación, controles y ejecución paso a paso.
2. Arquitectura del proyecto y sus **5 Reglas Inviolables** (`VisualRoot`, GPU Batching, Crossfire Nullification, Headless Safety, BankManager).
3. Inventario detallado de todo lo implementado al 100%.
4. **Roadmap Priorizado** con lo que falta para terminar el juego (Audio SFX, Jefes de Evento Brutalisk/Híbrido y Campaña de 30 rondas).

---

## 🎮 Cómo Jugar (Inicio Rápido)

1. Abre el proyecto en **Godot Engine 4.7.2** o posterior.
2. Presiona **F5** para iniciar la escena principal (`res://levels/main_level.tscn`).
3. En la consola previa a la misión:
   - Elige tu dificultad: `Casual`, `Normal`, `Hard`, `Brutal` o `Torment`.
   - Selecciona a tu Comandante Héroe (Jim Raynor, Tychus, Nova, Zeratul, Tassadar, Medic) o elige `🎲 RANDOM HERO` (+50 minerales extra y 1% de despertar al mítico *Xel'Naga Harbinger*).
   - Presiona **DEPLOY TO CHAR** (o la tecla `Espacio`/`Enter`).

### Controles Principales:
* **Cámara RTS:** `W`, `A`, `S`, `D` o bordes de pantalla (*Edge Scroll*). Rueda del ratón para Zoom. `Shift` para acelerar.
* **Selección:** Clic izquierdo (individual) o arrastre de caja verde estilo SC2 (múltiple).
* **Mover / Formación:** Clic derecho sobre el terreno (las unidades se mueven en formación táctica anti-empuje).
* **Órdenes de Combate:** `S` (Stop / Detenerse), `H` (Hold Position / Mantener posición).
* **Habilidades del Héroe:** Teclas `Q`, `W`, `E`, `R`.
* **Terminal de Armería:** Acércate a la estación en la base o haz clic en su botón en la consola SC2 para comprar mejoras balísticas, blindaje o desplegar torretas defensivas.

---

## 🧪 Verificación Automatizada (Tests)

Para ejecutar la batería completa de 110 pruebas de integración sin entorno gráfico:
```bash
godot --headless --path . -s tests/test_runner.gd
```

Para verificar que el nivel principal arranca limpiamente en headless:
```bash
godot --headless --path . --quit-after 200
```
