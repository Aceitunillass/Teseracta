# Teseracta — Editor de objetos y percepción espacial

Estado: especificación arquitectónica, todavía sin implementar ni probar en Godot 4.7.2.
Canon artístico: 3D low-poly isométrico, paletas planas sin sombras pintadas. Mantener avatar V05 de 404 y diario autobiográfico existente.
Fecha: noviembre de 2026.

## Decisión
La visión principal de cada Pomi será espacial y sensorial, sin pasar imágenes constantemente por un modelo multimodal. Godot contiene la verdad del mundo. Cada individuo accede a señales limitadas por posición, orientación, distancia, oclusión, receptores corporales, conocimiento y experiencia. Ministral recibe evidencias perceptivas resumidas, no listas omniscientes de todo lo que existe.

Separar en tres capas:
1. WorldTruth: geometría, posición, estado, inventario, temperatura física, materiales, interacción y hechos.
2. SensoryEvidence: señales observables y físicamente alcanzables (incluidos fragmentos visibles, contacto y fuentes térmicas).
3. BeliefState: conceptos aprendidos, nombres, hipótesis, recuerdos y confianza; un Pomi puede interpretar mal un objeto.

## Editor dentro del propio juego
Crear objetos combinando primitivos (cubo, prisma, cilindro de pocos lados, cuña) y operaciones de transformar, escalar, rotar, duplicar, agrupar, borrar y ajustar a rejilla. Permitir seleccionar objetos, piezas y superficies por separado. Proporcionar modos Auto y Manual para los descriptores perceptivos: el editor puede derivar propiedades de forma y material, y el autor puede ajustarlas. Los descriptores no deben otorgar conocimiento de contenidos invisibles.
Guardar definiciones de objetos reutilizables e instancias con estado independiente. Empezar por un editor sencillo; no intentar replicar todas las herramientas de Blockbench, UV avanzados o un modelador de vértices completo.

## Paletas de colores
Cada muestra tiene una familia cromática (brown, turquoise, pink, etc.) y una variación tonal específica. El jugador distingue distintos tonos de una misma paleta; un receptor cromático básico del Pomi obtiene una familia de color por región realmente visible. No recibe colores RGB completos ni paletas de caras ocultas. Su capacidad para nombrar los colores depende de lo aprendido. La percepción puede conservar proporciones aproximadas de superficie visibles por familia.

## Propiedades por parte y superficie
Visual: familia de color, forma básica, textura de superficie visible, transparencia óptica, orientación, dimensiones, movimiento.
Físico: masa, colisión, temperatura, conductividad térmica simplificada, fricción, rugosidad, dureza, humedad, resistencia, estado, capacidad de contener otros objetos.
Importante: temperatura del objeto no es sensación térmica. Esta última depende de temperatura corporal y ambiente, conductividad, proximidad y contacto, no de una etiqueta literal. Cada receptor recibe solo las señales disponibles en su situación.

## Visión y oclusión
Usar un índice espacial/broadphase para escoger candidatos cercanos; comprobar cono visual, tamaño angular y visibilidad mediante pocas consultas de rayos representativos, escalonadas y cacheadas. Un muro opaco bloquea el conocimiento visual del objeto. Para cristal se comprueba transmission óptica por pieza y se acumula la atenuación en rayos sucesivos. No confundir alpha de render o solidez del objeto con su transparencia perceptiva.
Una nevera con panel transparente puede dejar ver parte de su contenido, pero no revela mágicamente el inventario entero. Si el tomate queda oculto detrás de una caja, el Pomi no recibe evidencia visual del tomate. Reconocer lechuga, tomate o carne requiere aprender categorías o disponer de otras pistas; el identificador interno de mundo no se envía como nombre conocido.
Posibilitar cristales tintados y distorsión en versiones posteriores; MVP con transmisión simple.

## Tacto, calor, otros sentidos
La visión solo detecta lo visualmente accesible. Rugosidad, humedad y dureza se sienten mediante contacto. Calor y frío se reciben por receptores térmicos en contacto, aire o proximidad según capacidad; no consultar temperatura exacta a distancia sin justificación. Sonido y olor serán canales separados en fases posteriores. La propiocepción e interocepción consultan el cuerpo propio pero no revelan los estados internos de otro Pomi.

## Esquema de ejemplo conceptual
ObjectDefinition: id, primitive parts, transforms, palette family + swatch id por pieza, material por superficie, transparencia óptica, atributos físicos, affordances y editor overrides.
WorldObjectInstance: id único, transform, estado real, contenido, dinámica, relaciones, temperatura actual.
PerceptibleObject: región visible, familias percibidas, forma estimada, distancia, orientación, textura aparente, posible clase inferida y confianza. Nunca contiene la lista completa de contenidos ocultos.
Belief: concepto subjetivo, evidencia, certeza, procedencia, actualización por nuevas observaciones.

## Rendimiento y simultaneidad
Godot ejecuta receptores espaciales y fisiología sin invocar Ministral cada frame. Usar actualizaciones escalonadas, eventos, cachés, distancias al cuadrado, presupuestos de consultas y estados dirty. Un solo modelo local compartido puede deliberar para muchos Pomis, cada uno con estado mental individual. La parte física puede simularse en paralelo; las inferencias se planifican y en el hardware actual no podemos prometer simultaneidad ilimitada ni latencia humana. Mediciones previas del modelo 8B indican respuesta muy lenta; la percepción espacial por sí sola no resuelve la velocidad de generación de texto.
El protocolo de identidad largo debe preservarse como definición, pero se pueden preparar contextos compactos para cada turno sin repetir todo el prompt cuando perjudique la fluidez.

## Criterios de aceptación del primer editor y sensor
1. Crear y guardar un objeto de dos colores mediante el editor.
2. Detectar solo familias cromáticas y caras realmente visibles, no todos los tonos.
3. No detectar objetos tras un muro opaco.
4. Detectar solo objetos visibles tras una pieza transparente, sin revelar el inventario oculto.
5. Obtener señales táctiles/térmicas solo al haber receptor y condición física adecuada.
6. El modo manual ajusta propiedades perceptibles sin dar omnisciencia.
7. Permitir que dos Pomis vean diferentes partes del mismo objeto.
8. Medir coste con 3, 10 y 30 objetos antes de escalar.

## Orden
Primero editor mínimo y formato de datos. Segundo sensor visual semántico por posición y oclusión. Tercero materiales, transparencia y tacto. Cuarto interocepción/temperatura y aprendizaje de categorías. Quinto múltiples Pomis y escalado.
No declarar como implementado ninguno de esos módulos antes de programarlos y probarlos.
