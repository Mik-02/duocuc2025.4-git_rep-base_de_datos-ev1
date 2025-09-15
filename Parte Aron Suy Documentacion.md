
# 📘 Documentación Técnica — Persona A (Calidad de Datos y Automatización)

Este documento describe el funcionamiento del archivo único `Parte Aron Suy.sql` que consolida las tareas de **calidad de datos y automatización** sobre los componentes PL/SQL.

---

## 🔹 Contenido del Script

El archivo SQL incluye:

1. **Definición de utilidades básicas**
   - Creación condicional del tipo `VARRAY_MENSAJES`.
   - Creación condicional de la secuencia `SEQ_ERROR`.
   - Procedimiento `SP_LOG_ERROR` para registrar errores en tabla `LOG_ERRORES_PLSQL` **y** mostrar mensajes en `DBMS_OUTPUT`.

2. **Funciones revisadas con manejo de errores**
   - `F_GET_ANTIGUEDAD_ANIOS` → calcula antigüedad de un empleado en años.
   - `F_CALCULAR_INTERES` → interés por días de atraso.
   - `F_CALCULAR_COMISION` → comisión según valor de arriendo y tabla de rangos.
   - `F_OBTENER_TIPO_PROPIEDAD` → descripción de tipo de propiedad.
   - `F_OBTENER_PROPIETARIO` → nombre completo del propietario.

   Todas registran en `LOG_ERRORES_PLSQL` y escriben en `DBMS_OUTPUT` cuando ocurre `NO_DATA_FOUND`, `TOO_MANY_ROWS` o `OTHERS`.

3. **Procedimientos revisados**
   - `P_DETECTAR_SOLAPAMIENTOS`
     - Recorre todas las propiedades.
     - Detecta si existen arriendos solapados entre clientes distintos.
     - Registra los hallazgos en la tabla de logs con severidad **ALTA**.
     - Acumula los mensajes en un `varray_mensajes` y los imprime por `DBMS_OUTPUT`.

   - `P_GENERAR_HABERES_MENSUALES(p_mes, p_anno)`
     - Calcula haberes de cada empleado, sumando sueldo base + comisiones.
     - Consulta descuentos (previsión y salud).
     - Inserta/actualiza en la tabla `HABERES_MENSUALES`.
     - Usa `varray_mensajes` para acumular advertencias (descuentos inexistentes, duplicados, errores de inserción).
     - Al finalizar, imprime por `DBMS_OUTPUT` el resumen del proceso.

4. **Trigger de Auditoría**
   - `TRG_AUDIT_ARRIENDO_AFTER_UPDATE`
     - Se dispara tras un `UPDATE` en `ARRIENDO_PROPIEDAD`.
     - Inserta en `AUDIT_ARRIENDO` los valores antiguos y nuevos de fechas críticas (`fecini_arriendo`, `fecter_arriendo`).
     - Si ocurre error, se registra en logs y se imprime en `DBMS_OUTPUT`.

5. **Scripts de Prueba (comentados)**
   - Forzar `NO_DATA_FOUND` y `TOO_MANY_ROWS` en funciones.
   - Generar errores controlados en `F_CALCULAR_COMISION`.
   - Ejecutar el trigger actualizando un registro de arriendo.
   - Llamar a `P_DETECTAR_SOLAPAMIENTOS` y verificar solapamientos.
   - Llamar a `P_GENERAR_HABERES_MENSUALES` y validar resultados.

---

## 🔹 Cómo Usarlo

### 1. Preparación
- Ejecutar el script en el **esquema de pruebas**.
- Asegurarse que existan las tablas base:
  - `LOG_ERRORES_PLSQL`
  - `AUDIT_ARRIENDO`
  - `HABERES_MENSUALES`
  - `EMPLEADO`, `PROPIEDAD`, `ARREINDO_PROPIEDAD`, `PROPIETARIO`, `DESCUENTOS`, `COMISION`, `TIPO_PROPIEDAD`

### 2. Habilitar salida DBMS_OUTPUT
Antes de ejecutar pruebas, habilitar en cliente SQL:
```sql
SET SERVEROUTPUT ON SIZE 1000000;
```

### 3. Ejecutar scripts de prueba
Ejemplo:
```sql
BEGIN
  DBMS_OUTPUT.PUT_LINE('antig: ' || F_GET_ANTIGUEDAD_ANIOS(999999999));
END;
/
```

Verificar los registros en:
```sql
SELECT * FROM LOG_ERRORES_PLSQL ORDER BY fecha_proceso DESC;
```

### 4. Revisar resultados
- **Errores** → Tabla `LOG_ERRORES_PLSQL` + salida en consola (`DBMS_OUTPUT`).
- **Auditoría** → Tabla `AUDIT_ARRIENDO`.
- **Haberes procesados** → Tabla `HABERES_MENSUALES`.

---

## 🔹 Flujo de Ejecución Típico

1. Se ejecuta el procedimiento o función.
2. Si ocurre un error controlado:
   - Se inserta registro en `LOG_ERRORES_PLSQL` (con `SEQ_ERROR`).
   - Se imprime mensaje en `DBMS_OUTPUT`.
3. Si el procedimiento es `P_DETECTAR_SOLAPAMIENTOS` o `P_GENERAR_HABERES_MENSUALES`:
   - Se acumulan mensajes en `VARRAY_MENSAJES`.
   - Al finalizar, se imprime un resumen de mensajes en `DBMS_OUTPUT`.

---

## 🔹 Beneficios

- **Integridad de datos**: Se detectan y registran inconsistencias automáticamente.
- **Trazabilidad**: Todos los errores quedan en `LOG_ERRORES_PLSQL` con ID único (`SEQ_ERROR`).
- **Auditoría**: Cambios críticos en fechas de arriendo quedan registrados en `AUDIT_ARRIENDO`.
- **Transparencia**: El usuario puede ver en tiempo real el resultado en consola gracias a `DBMS_OUTPUT`.
- **Mantenibilidad**: Centralización del manejo de errores en `SP_LOG_ERROR`.

---

## 🔹 Próximos pasos recomendados

- Crear un **job programado** que consulte periódicamente `LOG_ERRORES_PLSQL` y alerte sobre errores con severidad **ALTA**.
- Implementar índices únicos y constraints para minimizar `TOO_MANY_ROWS`.
- Documentar en un **manual de usuario funcional** cómo interpretar los mensajes de auditoría y de logs.

---

✍️ Autor: **Persona A (Calidad de Datos y Automatización)**  
📅 Fecha de entrega: Septiembre 2025

