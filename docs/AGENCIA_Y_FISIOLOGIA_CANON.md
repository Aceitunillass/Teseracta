# TESERACTA — Agencia emergente y fisiología causal

Estado: diseño objetivo; **no declarar implementado**. Aprobado conceptualmente para el prototipo vertical *un Pomi / una vivienda* (09-11-2026). Preservar modelo Pomi V05 LIGERO MOVIL y el render low-poly de colores planos (sin sombreado pintado). Desarrollo directamente en `main`, con cambios verificables.

## Principio
Un Pomi **no es un chatbot con patas**. Es un agente virtual cuya percepción, memoria, motivación, deliberación, fisiología y capacidad de actuar pertenecen al mismo estado causal y persistente. El lenguaje es un medio para pensar, comunicarse y proponer acciones, **no una autoridad** que pueda reescribir la realidad del mundo.

No se afirma consciencia o experiencia subjetiva literal. Se persigue **agencia funcional y consecuencias verificables dentro de la simulación**. Evitar antropomorfismo engañoso o atribuir «aprendizaje» al simple mantenimiento de un prompt.

## Arquitectura para un Pomi (no simular la ciudad todavía)
- **WorldState** (verdad): habitación, posiciones, objetos, energía, agua, inventarios, permisos, relaciones, acontecimientos con IDs y tiempo.
- **BodyState / Homeostasis** (verdad): energía metabólica, hidratación, nutrición, vejiga, sueño, dolor, estrés físico, integridad/estado de salud; parámetros fisiológicos con límites y efectos. Empezar con pocos canales validados, extender.
- **Perception** (parcial): línea de visión, objetos alcanzables, sonidos/texto del jugador, interocepción (hambre, dolor, cansancio) y confianza en cada observación.
- **BeliefState / Knowledge** (privado del agente): distinción entre hecho percibido, relato de otra persona, hipótesis, error y conocimiento actualizado; procedencia y certeza.
- **Memory**: episodios con causa, resultado, lugar, fecha, emoción, saliencia; conocimientos derivados; sueños separados de hechos; persistencia versionada y recuperación relevante.
- **Motivation / Deliberation**: múltiples objetivos y preferencias, evaluación de consecuencias y oportunidades, capacidad de crear metas y planes revisables, hábitos aprendidos.
- **Action Proposal**: el motor generativo puede solicitar acciones tipadas sobre capacidades disponibles; las decisiones urgentes y reflejas pueden ejecutarse sin esperar una inferencia.
- **Action Validator / Executor**: comprueba recursos, alcance, obstáculos, energía, tiempo, propiedad, consentimiento, causalidad. Solo su ejecución produce cambios; devuelve éxito, fracaso y consecuencias observables.
- **Dialogue**: expresa la perspectiva del agente según creencias, memoria y circunstancias; no acepta automáticamente como cierto lo que el jugador afirma, ni promete que ya ejecutó acciones que el mundo no validó.

## Ejemplo: hambre **que existe realmente en el sistema**
1. Metabolismo consume reservas y puede generar señales de hambre.
2. El agente percibe intensidad y posibles consecuencias (fatiga, rendimiento, dolor).
3. Si persiste una deficiencia suficientemente grave, se deteriora salud o capacidad de realizar tareas según una fisiología cuantitativa y comprobable; no basta con que el Pomi «diga que está mal».
4. La deliberación pondera comer, descansar, pedir ayuda, buscar alimento, posponer una tarea, investigar alternativas, etc. **No** codificar «hambre < X → ir a la nevera» como comportamiento universal.
5. Una acción elegida requiere desplazamiento válido, posesión/acceso a comida, interacción y consumo físico de un recurso.
6. El simulador verifica y aplica efectos; la experiencia y sus resultados actualizan los recuerdos y hábitos.
7. Si la comida falta, el Pomi no la inventa ni se limita a afirmar que ha comido. El sistema conserva la escasez.

Los mecanismos de homeostasis y daño físico sí son **reglas codificadas** (como las leyes físicas). Lo que no debe fijarse exhaustivamente por código son las respuestas sociales, metas, conversaciones ni soluciones a problemas.

## Conversaciones e intención
«Quédate en la cocina» no puede resolverse con una línea de diálogo que diga «me quedo»: el sistema debe detectar si es una petición, y el agente puede **aceptarla, rechazarla, negociarla o ignorarla** según sus creencias, necesidades y situación. Solo si acepta, debe emitirse una propuesta tipada (p. ej. desplazarse, esperar), verificar y ejecutar. Si una necesidad crítica obliga a cambiar, no debe mentir al jugador sobre lo sucedido.

Una conversación sobre filosofía, sexo entre adultos, orientación, romance o religión no requiere una lista de temas «tabú» en el simulador. Los vínculos e intimidad de adultos tienen condiciones de consentimiento y capacidades reales; ninguna frase del jugador altera esos estados sin acciones validadas. Separar contenido conversacional, acciones y mundo.

## Diseño de capacidades genéricas (ejemplos, no conductas obligatorias)
`move_to(target)`, `inspect(entity)`, `use(object, interaction)`, `pick_up(item)`, `consume(item)`, `communicate(target, utterance)`, `wait(duration)`, `rest(location)`, `remember(event)`, `propose_goal(goal)`.
Cada capacidad presenta prerrequisitos, costes, ejecución y resultado; debe ser composable y restringida al entorno. Ampliar las capacidades sin reescribir el agente.

## Límites de rendimiento y privacidad
Un único modelo local compartido, inferencia por demanda y presupuesto; la simulación física sigue ejecutándose sin LLM. Evitar llamar al LLM en cada tick. La información de la mente queda almacenada localmente en partida; no exponer secretos de otros agentes a la percepción del Pomi. Las acciones urgentes no pueden quedar bloqueadas por una inferencia lenta.

## Criterios de aceptación del primer prototipo
1. Pomi deja de comer si no hay alimento; comida y reservas disminuyen de modo coherente.
2. Déficit prolongado modifica al menos una capacidad medible (velocidad, resistencia o salud) y tiene recuperación verificable tras reponer recursos.
3. Una orden conversacional no modifica el mundo sin un acuerdo y una acción efectivamente validada; el agente puede negarse.
4. La misma necesidad puede provocar soluciones diferentes según entorno, memoria y objetivos, sin scripts específicos por frase.
5. Los sucesos y recuerdos persisten y tienen procedencia; una declaración falsa del jugador no se convierte en hecho.
6. La IA puede fallar sin detener el mundo ni falsificar acciones.
7. La latencia y consumo se miden en Windows; no afirmar que funciona sin pruebas Godot y Ollama reales.

## Estado actual (09-11-2026)
La versión existente contiene descenso de cinco necesidades, utilidad de cinco acciones prefijadas, casa 3D, modelo local para conversación y memoria rudimentaria. **Todavía no implementa** interocepción, daño causal por inanición, acción deliberativa generativa validada, creencias tipadas, verdadero aprendizaje a largo plazo ni coordinación robusta entre diálogo y movimiento. Eliminar gradualmente ese acoplamiento antes de añadir más Pomis.

## Orden de implementación
1. Homeostasis causal + consecuencias físicas con pruebas deterministas.
2. Acciones genéricas, API tipada y validación; separar intenciones conversacionales y resultados.
3. Percepción y conocimiento parcial; revisar memoria episódica.
4. Planificación, hábitos adaptativos y recuperación de recuerdos.
5. Evaluación longitudinal de coherencia, agencia, calidad conversacional y rendimiento antes de ampliar la ciudad.
