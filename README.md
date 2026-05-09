# Crear-directorios-development-staging-data

Script para crear una estructura base de proyecto en `/srv/<nombre-proyecto>`.
El nombre del proyecto solo admite letras, números, guiones (`-`) y guiones bajos (`_`).

## Uso

```bash
./setup-directory.sh
```

## Estructura creada

```text
/srv/<nombre-proyecto>/
├── development
├── staging
└── data
    ├── postgres
    └── redis
```
