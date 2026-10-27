# Notas de Diseño y Referencia SFE5

Este documento recopila las referencias oficiales de diseño de **Special Forces Elite 5 (SFE5)** obtenidas de `sfe5.wiki` y documenta las decisiones técnicas y matemáticas adoptadas en este clon en Godot 4.7.

---

## 1. Principio Fundamental: Concentración de Poder

A diferencia de los RTS convencionales de macrogestión de ejércitos masivos, SFE5 castiga severamente la dispersión de recursos entre múltiples unidades. La estrategia óptima y núcleo de su identidad reside en concentrar el mineral y las mejoras en **1 o 2 unidades principales** (héroe y/o unidad élite).

El flujo de inversión óptimo según la wiki es:
1. **Mejoras propias de la unidad** (habilidades y pasivas base baratas).
2. **Mejoras raciales primarias** (daño, blindaje, vida, energía, cadencia).
3. **Bufos de consola** (Tiers 1 a 7, más As y Demiurge).
4. **Atributos puros** (Fuerza, Destreza, Inteligencia, Aguante).

---

## 2. Fórmula Maestra de Ingresos (Income Formula)

El mineral no se recolecta pasivamente de yacimientos; procede de la eliminación activa de enemigos.

### Parámetros de la unidad destruida:
* $\text{Vida}_{\text{eff}} = \text{VidaBase} \times \text{MultVida}$
* $\text{Escudo}_{\text{eff}} = \text{EscudoBase} \times \text{MultVida}$
* $\text{Daño}_{\text{eff}} = \text{DañoArma} \times \text{MultDaño}$

### Cálculo del valor base $s$:
* Si la unidad está armada:
  $$s = \frac{\text{Vida}_{\text{eff}} + \text{Escudo}_{\text{eff}}}{3} + \frac{\text{Daño}_{\text{eff}}}{\max(\text{PeriodoAtaque}, 0.01)}$$
* Si la unidad está desarmada:
  $$s = \left(\frac{\text{Vida}_{\text{eff}} + \text{Escudo}_{\text{eff}}}{3}\right) \times 2$$
* Si posee energía máxima ($\text{EnergiaMax} > 0$):
  $$s = s \times \left(\frac{\text{EnergiaMax}}{50}\right)$$

### Curva de amortiguación:
* Si $s > 500.000$:
  $$s = \left(\frac{s}{10}\right)^{0.32} \times 3$$
* En caso contrario:
  $$s = s^{0.32}$$

### Reparto y multiplicador de ritmo:
* Modo Split Income (el asesino se lleva todo):
  $$s = s \times 10 \times 0.9$$
* Modo Compartido (distribuido entre jugadores activos):
  $$s = s \times 4 \times \left(\frac{12 - \text{Jugadores}}{4}\right)$$
* Ritmo base:
  $$s = s \times 0.24$$

### Multiplicadores de categoría:
* Estructura: $\times 8.0$
* Heroica: $\times 4.0$
* Élite / Map Boss: $\times 6.0$
* Jefe Invocado: $\times 2.0$
* Jefe Principal (Pinnacle Boss): $\times 6.0$

### Bono de Pedestal y Mínimo Garantizado:
$$s = s + \text{BonoPedestal}$$
$$\text{Recompensa Final} = \max(1, \lfloor s + 0.5 \rfloor)$$

---

## 3. Cadena de Engendradores (Spawners)
* Ciclo periódico de 20 segundos.
* Cada engendrador es invulnerable hasta que el eslabón anterior de su familia/cadena es destruido.
* Límite de presupuesto de 300 enemigos vivos en el mapa. Si se alcanza, los engendradores detienen su producción hasta que el enjambre sea mermado.
* Destruir un nido otorga bufos permanentes y una tonalidad distintiva de color a los enemigos restantes de esa clase.

---

## 4. Referencias y Calculadoras
* Portal oficial de la wiki: [sfe5.wiki](https://sfe5.wiki/wiki)
* Calculadora de ingresos: [sfe5.wiki/income](https://sfe5.wiki/income)
* Calculadora de daño: [sfe5.wiki/calculator/damage](https://sfe5.wiki/calculator/damage)
* Calculadora de rangos y puntos: [sfe5.wiki/rank](https://sfe5.wiki/rank)
