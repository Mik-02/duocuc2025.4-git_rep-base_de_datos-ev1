-- B.sql
-- 4. Crear tipo VARRAY para mensajes
CREATE TYPE varray_mensajes AS VARRAY(10) OF VARCHAR2(100);

-- 5. Crear función para calcular antigüedad
CREATE OR REPLACE FUNCTION F_GET_ANTIGUEDAD_ANIOS(p_numrut_emp NUMBER) RETURN NUMBER IS
    v_fecing_emp DATE;
    v_antiguedad NUMBER;
BEGIN
    SELECT fecing_emp INTO v_fecing_emp
    FROM empleado
    WHERE numrut_emp = p_numrut_emp;

    v_antiguedad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecing_emp) / 12);
    RETURN v_antiguedad;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'F_GET_ANTIGUEDAD_ANIOS', 'ALTA', 'Error al calcular antigüedad: ' || SQLERRM, SYSDATE);
        RETURN -1;
END;


-- 6. Crear función para calcular interés
CREATE OR REPLACE FUNCTION F_CALCULAR_INTERES(p_dias_atraso NUMBER) RETURN NUMBER IS
    v_interes NUMBER;
BEGIN
    IF p_dias_atraso <= 0 THEN
        RETURN 0;
    ELSE
        v_interes := p_dias_atraso * 0.001; -- 0.1% por día
        RETURN v_interes;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'F_CALCULAR_INTERES', 'MEDIA', 'Error al calcular interés: ' || SQLERRM, SYSDATE);
        RETURN 0;
END;


-- 7. Crear función para calcular comisión
CREATE OR REPLACE FUNCTION F_CALCULAR_COMISION(p_valor_arriendo NUMBER) RETURN NUMBER IS
    v_comision NUMBER;
BEGIN
    SELECT valor_comision INTO v_comision
    FROM COMISION
    WHERE p_valor_arriendo BETWEEN total_arriendo_inf AND total_arriendo_sup
    AND ROWNUM = 1;
    RETURN v_comision;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'F_CALCULAR_COMISION', 'MEDIA', 'Error al calcular comisión: ' || SQLERRM, SYSDATE);
        RETURN 0;
END;


-- 8. Crear función para obtener tipo de propiedad
CREATE OR REPLACE FUNCTION F_OBTENER_TIPO_PROPIEDAD(p_nro_propiedad NUMBER) RETURN VARCHAR2 IS
    v_tipo_propiedad VARCHAR2(30);
BEGIN
    SELECT tp.desc_tipo_propiedad INTO v_tipo_propiedad
    FROM propiedad p
    JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad
    WHERE p.nro_propiedad = p_nro_propiedad;
    RETURN v_tipo_propiedad;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'No encontrado';
    WHEN OTHERS THEN
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'F_OBTENER_TIPO_PROPIEDAD', 'BAJA', 'Error: ' || SQLERRM, SYSDATE);
        RETURN 'Error';
END;


-- 9. Crear función para obtener propietario
CREATE OR REPLACE FUNCTION F_OBTENER_PROPIETARIO(p_nro_propiedad NUMBER) RETURN VARCHAR2 IS
    v_propietario VARCHAR2(100);
BEGIN
    SELECT pr.nombre_prop || ' ' || pr.appaterno_prop || ' ' || pr.apmaterno_prop INTO v_propietario
    FROM propiedad p
    JOIN propietario pr ON p.numrut_prop = pr.numrut_prop
    WHERE p.nro_propiedad = p_nro_propiedad;
    RETURN v_propietario;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'No encontrado';
    WHEN OTHERS THEN
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'F_OBTENER_PROPIETARIO', 'BAJA', 'Error: ' || SQLERRM, SYSDATE);
        RETURN 'Error';
END;


-- 12. Crear procedimiento para detectar solapamientos
CREATE OR REPLACE PROCEDURE P_DETECTAR_SOLAPAMIENTOS IS
    CURSOR c_propiedades IS
        SELECT nro_propiedad FROM propiedad;
    v_errores varray_mensajes := varray_mensajes();
BEGIN
    FOR prop IN c_propiedades LOOP
        FOR solap IN (
            SELECT a1.nro_propiedad, a1.numrut_cli as cliente1, a2.numrut_cli as cliente2
            FROM arriendo_propiedad a1
            JOIN arriendo_propiedad a2 ON a1.nro_propiedad = a2.nro_propiedad
            WHERE a1.nro_propiedad = prop.nro_propiedad
            AND a1.numrut_cli <> a2.numrut_cli
            AND (
                (a1.fecini_arriendo BETWEEN a2.fecini_arriendo AND NVL(a2.fecter_arriendo, SYSDATE)) OR
                (a1.fecter_arriendo BETWEEN a2.fecini_arriendo AND NVL(a2.fecter_arriendo, SYSDATE)) OR
                (a2.fecini_arriendo BETWEEN a1.fecini_arriendo AND NVL(a1.fecter_arriendo, SYSDATE))
            )
        ) LOOP
            v_errores.EXTEND;
            v_errores(v_errores.COUNT) := 'Solapamiento en propiedad ' || solap.nro_propiedad || ' entre clientes ' || solap.cliente1 || ' y ' || solap.cliente2;
            INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
            VALUES (seq_error.NEXTVAL, 'P_DETECTAR_SOLAPAMIENTOS', 'ALTA', v_errores(v_errores.COUNT), SYSDATE);
        END LOOP;
    END LOOP;
END;