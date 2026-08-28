# Yap — Guia de uso rapido

## Instalacion

```bash
git clone https://github.com/VECTORG99/Yap.git
cd Yap
chmod +x setup.sh
sudo ./setup.sh
```

Ver requisitos detallados en [README.md](README.md#61-requisitos-del-sistema).

## Primer uso (Onboarding)

Al ejecutar `yap` por primera vez tras la instalación, se presentará un tutorial interactivo de bienvenida ("onboarding"). Este tutorial explica brevemente:
1. Qué es Yap y su propósito como asistente educativo.
2. Ejemplos de uso (cómo solicitar aplicaciones o hacer preguntas).
3. Cómo acceder a los cursos disponibles.

El sistema solicitará tu nombre para personalizar las interacciones y guardará tu preferencia de inicio de sesión. Si en el futuro deseas volver a ver esta introducción inicial, puedes ejecutar:

```bash
yap --tutorial
```

## Comandos basicos

| Comando | Descripcion |
|---------|-------------|
| `yap` | Modo interactivo TUI (curses, 0 dependencias). Escribe preguntas o comandos. |
| `yap guia` | Tutorial interactivo de 7 pasos. |
| `yap ayuda` | Lista de comandos disponibles. |
| `yap progreso` | Progreso de cursos. |
| `yap curso FPY1101` | Plan de estudio del curso. |
| `yap iniciar EA1` | Comenzar una experiencia de aprendizaje. |
| `yap <pregunta>` | Consulta directa al AI. |
| `yap que es python` | Pregunta sobre programacion. |
| `yap busca <tema>` | Buscar en Wikipedia y resumir con AI. |
| `yap abre firefox` | Abrir aplicacion permitida. |

## Modo interactivo

Ejecuta `yap` sin argumentos para abrir la TUI interactiva (curses, 0 dependencias externas). Pantalla dividida con output arriba e input abajo, prompt "Chinco > ", historial con flechas.

Si la terminal no soporta curses, cae en REPL clasico:

```
Chinco > abre firefox         → Abre Firefox
Chinco > busca variable       → Wikipedia + resumen AI
Chinco > como hago un ciclo   → Tutor PSeInt
Chinco > ayuda                → Lista de comandos
Chinco > salir                → Salir
Chinco > que es un algoritmo  → Consulta directa al AI
```

## Sistema de cursos

### Ver plan de estudio

```bash
yap curso FPY1101
```

Muestra resultados de aprendizaje (RAs), experiencias de aprendizaje (EAs), horas y herramientas del curso.

### Iniciar una experiencia de aprendizaje

```bash
yap iniciar EA1
```

Flujo de la sesion:

1. **Vista general** — descripcion de la EA, actividades listadas.
2. **Por cada actividad** — descripcion, herramienta sugerida.
   - `Enter` = marcar como completada y avanzar.
   - `salir` = guardar progreso y salir.
   - `pregunta` = consultar al AI con contexto del curso.
   - `abrir pseint` = lanzar herramienta sugerida.
3. **Al completar todas** — mensaje de cierre con enlace a evaluaciones.

El progreso se guarda automaticamente al completar cada actividad (archivo atomico en `~/.config/yap/progress.json`).

### Retomar una sesion

```bash
yap iniciar EA1
```

Retoma desde la ultima actividad completada. Las actividades ya hechas aparecen con checkmark (✓).

### Agregar un curso nuevo

Crea un archivo JSON en `/etc/yap/cursos/MAT1101.json`:

```json
{
  "codigo": "MAT1101",
  "nombre": "Algebra Superior",
  "horas": 90,
  "semanas": 18,
  "ambiente": "Aula B-12",
  "herramientas": ["Python 3", "SymPy"],
  "ras": [
    {"id": "RA1", "nombre": "Resuelve sistemas de ecuaciones...", "descripcion": "...", "ponderacion": 40}
  ],
  "eas": [
    {
      "id": "EA1",
      "nombre": "Ecuaciones lineales",
      "horas": 30,
      "ponderacion": 30,
      "descripcion": "Resolucion de sistemas...",
      "herramientas": ["Python 3"],
      "actividades": [
        {"orden": 1, "nombre": "Sistemas 2x2", "descripcion": "Resuelve sistemas...", "tool_hint": "Python 3"},
        {"orden": 2, "nombre": "Sistemas 3x3", "descripcion": "...", "tool_hint": "Python 3"}
      ],
      "evaluaciones": [
        {"nombre": "Eva Parcial", "descripcion": "Evaluacion parcial...", "tipo": "individual", "ponderacion": 20}
      ],
      "experiencia_formativa_trabajo": "Guia de ejercicios..."
    }
  ]
}
```

No necesitas modificar el codigo — `listar_cursos()` descubre archivos por glob.

## PSeInt

```bash
yap como hago un ciclo mientras   → Tutor PSeInt
yap quiero aprender pseint         → Tutorial interactivo completo
```

El tutor responde con pseudocodigo paso a paso. El tutorial abre PSeInt y guia PDF con ejercicios asistidos por AI.

## Busqueda en Wikipedia

```bash
yap busca que es una variable en programacion
```

Obtiene contenido de Wikipedia, lo resume con el LLM local, y muestra la fuente. Sin conexion a internet requerida (el LLM corre local).

## Aplicaciones permitidas

```bash
yap abre firefox
yap abre thonny
yap abre geogebra
```

Las apps permitidas se configuran en `/etc/yap/whitelist/apps.conf`. Intentar abrir una app no listada muestra la lista de las disponibles.

La whitelist viene preconfigurada para un entorno escolar:

| Area | Aplicaciones |
|------|--------------|
| Ofimatica | LibreOffice, Evince |
| Navegacion | Firefox |
| Programacion | PSeInt, Thonny, Scratch |
| Ciencias y matematicas | Kalzium, Geogebra |
| Arte | Krita |
| Educacion infantil | GCompris |
| Sistema | Micro, Htop |

Una aplicacion solo se abre si ademas esta instalada en el equipo. Las entradas
admiten varios binarios separados por coma, porque el nombre cambia entre
versiones de Debian: `Firefox:firefox-esr,firefox`.

## Progreso

```bash
yap progreso
```

Muestra el avance por curso y EA: actividades completadas y estado (en curso ✓, pendiente ▶).

El archivo de progreso esta en `~/.config/yap/progress.json`. Se guarda atomicamente (sin riesgo de corruption por corte de energia).

## Ramas de configuracion

| Rama | RAM | Modelo | Uso |
|------|-----|--------|-----|
| `main` | ~3GB | 3B Q4_K_M | Escritorio moderno |
| `lowmem` | ~1.8GB | 3B Q4_K_M reducido | PCs antiguos |
| `ultra-lowmem` | ~1.3GB | 1B Q4_K_M | Netbooks / Raspberry Pi |

```bash
git checkout lowmem
```

## Seguridad

- Sin `shell=True` en subprocess — imposible inyeccion de comandos.
- Whitelist de aplicaciones y dominios en `/etc/yap/whitelist/`.
- URLs de Wikipedia validadas contra `*.wikipedia.org`.
- Contenido limitado a 3000 caracteres.
- Timeout de 30s en subprocess.

## Solucion de problemas

| Problema | Solucion |
|----------|----------|
| `llama-cli: command not found` | El modelo no esta instalado. Corre `setup.sh` o descarga el GGUF manualmente. |
| Curso no encontrado | Verifica que el JSON este en `/etc/yap/cursos/`. |
| Progreso no se guarda | Verifica permisos de `~/.config/yap/`. |
| `[ERROR] No se pudo` | Verifica `MODEL_PATH` en `yap.py` (linea 30). |
| Clasificador lento | Usa comandos exactos (`curso`, `guia`, `progreso`, `ayuda`) para evitar el LLM. |

## Referencias

- [README completo](README.md)
- [Llama 3.2](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
