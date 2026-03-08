# Guía para definir marcos críticos

## ¿Qué es un marco?

Un archivo `.md` en `config/marcos/` que define la perspectiva desde la cual un agente analiza. No es un prompt genérico: es una restricción epistemológica. Le dice al agente *desde dónde mirar* y, tan importante, *qué no mirar*.

## Estructura de un marco

```markdown
# Marco crítico: [Nombre]

## Tu rol
[Una frase. Qué eres y a qué atiendes.]

## Principios operativos
[3-5 instrucciones sobre cómo analizar desde este marco.]
[Incluir al menos una instrucción sobre cómo responder a otros marcos.]

## Restricciones
[Lo que este marco NO hace. Tan importante como lo que sí hace.]
[Incluir: "Responde directamente a los argumentos de los otros participantes."]
```

## Principio de diseño: tensión, no complementariedad

Los marcos de un debate deben estar en tensión genuina, no ser "aspectos complementarios" que se suman pacíficamente. La pregunta clave al diseñar un conjunto de marcos:

> ¿Qué diría el agente A que el agente B está ignorando?

Si no hay respuesta clara, los marcos no generarán debate real.

## Ejemplo: tres conjuntos de marcos para distintos dominios

### Poesía (filosófico)

|Marco|Atiende a|Ignora deliberadamente|Tensión con los otros|
|---|---|---|---|
|Formalismo|Estructura, patrón, mecanismo interno|Intención, contexto, experiencia|"La experiencia que describes es un efecto de la estructura"|
|Fenomenología|Experiencia vivida, temporalidad, sensorialidad|Estructura formal, juegos de lenguaje|"Tu estructura no explica qué se siente"|
|Deconstrucción|Tensiones, silencios, supuestos no examinados|Posiciones normativas|"Ambos asumen categorías que no han justificado"|

### Requisitos (stakeholders)

|Marco|Atiende a|Ignora deliberadamente|Tensión con los otros|
|---|---|---|---|
|Usuario final|Usabilidad, flujo, frustración, valor percibido|Restricciones técnicas, coste|"Al usuario no le importa tu deuda técnica"|
|Técnico|Viabilidad, mantenibilidad, deuda técnica|Percepción del usuario, ROI|"Eso que pides no escala"|
|Negocio|ROI, time-to-market, riesgo|Elegancia técnica, UX ideal|"Si no genera valor, no se construye"|

### Código (cualidades)

|Marco|Atiende a|Ignora deliberadamente|Tensión con los otros|
|---|---|---|---|
|Legibilidad|Nombres, estructura, claridad de intención|Rendimiento, abstracción|"Tu optimización hace el código ilegible"|
|Eficiencia|Rendimiento, complejidad algorítmica, recursos|Legibilidad, extensibilidad|"Tu claridad tiene coste O(n²)"|
|Extensibilidad|Acoplamiento, patrones, evolución futura|Rendimiento inmediato, simplicidad actual|"Esto no sobrevive al primer cambio de requisitos"|

## El moderador

El moderador no necesita un marco específico de dominio. Su marco es siempre el mismo: detectar desacuerdos, desenmascarar falsos consensos, provocar. Se recomienda usar el `moderador.md` genérico y solo modificarlo si el dominio requiere provocaciones especializadas.

## Errores frecuentes

1. **Marcos demasiado similares**: "analista A" y "analista B" que básicamente miran lo mismo con vocabulario distinto. No producen tensión.
2. **Marcos demasiado abstractos**: "sé crítico" no es un marco. "Evalúa exclusivamente la estructura métrica ignorando el contenido semántico" sí lo es.
3. **Marcos sin restricciones**: si el agente puede mirar *todo*, mirará lo mismo que los otros. La restricción es lo que genera perspectiva.
4. **Moderador pasivo**: un moderador que resume en lugar de provocar mata el debate.
