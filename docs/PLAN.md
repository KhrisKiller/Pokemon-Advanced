# Plan de trabajo por fases

**Pokémon Advanced · Mod de Pokémon Esmeralda (GBA)**
Versión 0.1 · Septiembre 2026

Juego completo que combina la exploración y captura de Pokémon Esmeralda, la vida de granja de Stardew Valley y los combates por turnos sobre cuadrícula de Advanced Tactics. Punto de partida: solo la idea. Nivel: principiante.

## Cómo leer este plan

Las fases van en orden. Cada una tiene un objetivo, una lista de tareas y una condición de "terminado". No pases a la siguiente hasta cumplirla. El orden está pensado para que tengas algo jugable pronto: primero una granja pequeña y un combate táctico de prueba, y solo después el contenido grande (región, historia, personajes).

Las duraciones suponen unas 8–10 horas por semana y son estimaciones. En total, un juego completo de este tamaño lleva entre 1,5 y 3 años para una persona que empieza.

## Herramientas recomendadas

Recomiendo trabajar sobre el código descompilado en lugar de editar la ROM con herramientas binarias. Las tres mecánicas nuevas (granja, estaciones, combate táctico) requieren programar en C, y eso solo es práctico con el código fuente.

| Herramienta | Para qué |
| --- | --- |
| [pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) | Base del proyecto. Es pokeemerald (Esmeralda descompilado) con mejoras y una comunidad activa que responde dudas. |
| WSL (Windows) o Linux/macOS | Entorno para compilar con `make` y la toolchain devkitARM. |
| [Porymap](https://github.com/huderlem/porymap) | Editor de mapas, eventos, NPC y conexiones entre rutas. |
| [Poryscript](https://github.com/huderlem/poryscript) | Escribir diálogos y eventos con una sintaxis más legible que los scripts originales. |
| [Porytiles](https://github.com/grunt-lucas/porytiles) | Convertir tus tilesets dibujados al formato que usa el juego. |
| Aseprite o LibreSprite | Pixel art con paletas indexadas de 16 colores (límite de la GBA). |
| [mGBA](https://mgba.io/) | Emulador para probar; tiene visor de memoria y depurador. |
| Git + GitHub | Guardar cada cambio en tu repositorio. Si algo se rompe, vuelves atrás. |

> **Distribución:** publica el juego como parche (`.bps`, creado con Flips) o como código fuente. No compartas la ROM compilada.

## Qué reutilizar de Esmeralda

Varios sistemas del juego original ya hacen parte del trabajo. Partir de ellos ahorra meses.

| Sistema de Esmeralda | Uso en Pokémon Advanced |
| --- | --- |
| Árboles de bayas | Base de los cultivos: ya crecen por etapas, se riegan y se cosechan. |
| Reloj interno (RTC) | Días y estaciones. Recomiendo un calendario propio que avance al dormir, como en Stardew Valley. |
| Bases secretas | Decorar la casa y colocar objetos en la granja. |
| PokéNav / Match Call | Agenda de vecinos y nivel de amistad con cada uno. |
| Cálculo de daño y tipos | Se conserva dentro del combate táctico: cambia el tablero, no las fórmulas. |
| Flags y variables | Progreso de historia, eventos por estación, corazones de amistad. |

## Resumen de fases

| Fase | Nombre | Resultado | Duración |
| :-: | --- | --- | --: |
| 0 | [Preparación](#fase-0--preparación) | Compilas el juego y haces tu primer cambio | 2–4 sem |
| 1 | [Diseño y alcance](#fase-1--diseño-y-alcance) | Documento de diseño corto y reglas del juego | 2–3 sem |
| 2 | [Prototipo de granja](#fase-2--prototipo-de-granja) | Plantar, regar, dormir, cosechar, vender | 1–2 meses |
| 3 | [Prototipo táctico](#fase-3--prototipo-táctico) | Un combate en cuadrícula que se puede ganar y perder | 2–4 meses |
| 4 | [Porción jugable](#fase-4--porción-jugable) | 30 minutos de juego con las tres partes unidas | 1–2 meses |
| 5 | [Gráficos y tiles](#fase-5--gráficos-y-tiles) | Estilo visual propio (en paralelo a la fase 6) | continuo |
| 6 | [Historia y contenido](#fase-6--historia-y-contenido) | Región, personajes, estaciones, campaña | 6–18 meses |
| 7 | [Pruebas y lanzamiento](#fase-7--pruebas-y-lanzamiento) | Beta pública y versión 1.0 | 2–3 meses |

---

### Fase 0 · Preparación

*2–4 semanas*

**Objetivo:** tener el entorno listo y entender cómo está organizado el código.

- [ ] Instalar WSL (si usas Windows), devkitARM y las dependencias que indica el archivo `INSTALL.md` de pokeemerald-expansion.
- [ ] Clonar el proyecto en tu repositorio Pokemon-Advanced y compilar el juego sin cambios.
- [ ] Hacer tres cambios pequeños: un texto de un NPC, el Pokémon inicial y un objeto en un mapa con Porymap.
- [ ] Aprender lo básico de C: variables, funciones, structs, arrays. No hace falta más para empezar.
- [ ] Unirte a la comunidad de pokeemerald (servidor de Discord de RHH) para resolver dudas.

> **Terminado cuando:** el juego compila, arranca en mGBA con tus tres cambios y el código está subido a GitHub.

### Fase 1 · Diseño y alcance

*2–3 semanas*

**Objetivo:** decidir cómo encajan las tres partes antes de programarlas.

- [ ] Definir el ciclo de un día: qué hace el jugador por la mañana, la tarde y la noche.
- [ ] Decidir qué combates son tácticos (¿todos, o solo los de historia y gimnasios?) y cuáles siguen siendo normales.
- [ ] Reglas del tablero: tamaño, cuántos Pokémon por bando, movimiento según velocidad, terreno.
- [ ] Cómo se conectan las partes: por ejemplo, los cultivos dan objetos para el combate y los combates desbloquean zonas para cultivar.
- [ ] Escribir la premisa de la historia en una página. Los detalles vienen en la fase 6.

> **Terminado cuando:** tienes un documento de 3–5 páginas con el ciclo del día, las reglas tácticas y la premisa.

### Fase 2 · Prototipo de granja

*1–2 meses*

**Objetivo:** una granja pequeña que funciona, usando mapas y gráficos provisionales.

- [ ] Crear un mapa de granja en Porymap con 6–10 parcelas.
- [ ] Adaptar el sistema de bayas: plantar semillas, regar y cosechar en parcelas fijas.
- [ ] Añadir la cama: dormir guarda la partida y avanza un día; los cultivos crecen por días, no por horas reales.
- [ ] Una tienda que compra la cosecha y vende semillas.
- [ ] Guardar el día y la estación en variables del juego.

> **Terminado cuando:** puedes plantar, dormir tres días, cosechar y vender sin errores.

### Fase 3 · Prototipo táctico

*2–4 meses*

**Objetivo:** un combate completo en cuadrícula. Es la parte más difícil del proyecto; conviene hacerla pronto para saber si es viable.

- [ ] Montarlo como una pantalla nueva e independiente, sin tocar el combate original.
- [ ] Dibujar la cuadrícula y un cursor que se mueve casilla a casilla.
- [ ] Seleccionar un Pokémon, mostrar sus casillas alcanzables y moverlo.
- [ ] Atacar a una unidad adyacente usando el cálculo de daño de Esmeralda.
- [ ] IA enemiga simple: acercarse a la unidad más cercana y atacar.
- [ ] Condiciones de victoria y derrota, y volver al mapa normal al terminar.

> **Terminado cuando:** un combate de 3 contra 3 se puede jugar de principio a fin, ganando o perdiendo.

### Fase 4 · Porción jugable

*1–2 meses*

**Objetivo:** unir granja, exploración y combate táctico en una muestra corta.

- [ ] Un pueblo, la granja y una ruta con Pokémon salvajes.
- [ ] Dos o tres vecinos con los que hablar y un evento de historia.
- [ ] Un combate táctico que se activa por la historia.
- [ ] Pedir a 3–5 personas que lo jueguen y anotar qué entienden y qué no.

> **Terminado cuando:** alguien que no conoce el proyecto juega 30 minutos sin tu ayuda.

### Fase 5 · Gráficos y tiles

*En paralelo a la fase 6*

**Objetivo:** reemplazar los gráficos provisionales por un estilo propio.

- [ ] Definir la paleta y el estilo con un solo mapa de prueba antes de dibujar todo.
- [ ] Tileset de granja: tierra arada, tierra regada, cultivos en cada etapa, cercas.
- [ ] Tileset táctico: casillas de terreno (hierba, agua, bosque, montaña) y marcas de movimiento y ataque.
- [ ] Sprites de personajes y vecinos. Respeta el límite de 16 colores por paleta.
- [ ] Importar con Porytiles y revisar en mGBA cada tileset nuevo.

> **Terminado cuando:** la porción jugable de la fase 4 ya no usa gráficos de Esmeralda.

### Fase 6 · Historia y contenido

*6–18 meses*

**Objetivo:** construir el juego completo por capítulos. Cada capítulo es una zona nueva con su granja, sus vecinos y sus combates.

- [ ] Escribir la historia completa dividida en capítulos.
- [ ] Diseñar la región: pueblos, rutas y los mapas tácticos de cada combate importante.
- [ ] Sistema de amistad con vecinos: regalos, corazones y escenas por nivel.
- [ ] Cuatro estaciones con cultivos propios y un festival por estación.
- [ ] Campaña táctica con dificultad creciente y rivales recurrentes.
- [ ] Terminar y probar un capítulo antes de empezar el siguiente.

> **Terminado cuando:** el juego se puede completar de principio a fin.

### Fase 7 · Pruebas y lanzamiento

*2–3 meses*

**Objetivo:** publicar una versión estable.

- [ ] Beta cerrada con un grupo pequeño; lista de errores en GitHub Issues.
- [ ] Ajustar dificultad de combates y precios de la granja.
- [ ] Probar en hardware real o en varios emuladores.
- [ ] Publicar el parche `.bps` con instrucciones de instalación.

> **Terminado cuando:** la versión 1.0 está publicada.

---

## Riesgos

- **El combate táctico no cabe en el motor.** Por eso va en la fase 3. Si resulta demasiado difícil, la alternativa es mantener el combate normal y añadir la cuadrícula solo en batallas especiales.
- **Alcance demasiado grande.** Si el ritmo se cae, reduce la fase 6 a menos capítulos y publica una versión corta.
- **Perder trabajo.** Sube cambios a GitHub al final de cada sesión.
- **Memoria de la GBA.** El espacio para guardar partida es limitado; planifica qué variables usan la granja y la amistad antes de crear muchas.

## Esta semana

1. [ ] Instalar WSL y devkitARM.
2. [ ] Clonar pokeemerald-expansion dentro de tu repositorio Pokemon-Advanced.
3. [ ] Compilar y abrir el juego en mGBA.
4. [ ] Cambiar un diálogo, compilar de nuevo y subir el cambio.
