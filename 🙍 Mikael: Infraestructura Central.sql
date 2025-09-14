-- M.sql
-- 1. Crear tabla de logs de errores
CREATE TABLE LOG_ERRORES_PLSQL (
    id_error NUMBER PRIMARY KEY,
    subprograma VARCHAR2(100),
    gravedad VARCHAR2(20),
    mensaje VARCHAR2(4000),
    fecha_proceso DATE
);

-- 2. Crear tabla para haberes mensuales
CREATE TABLE HABERES_MENSUALES (
    numrut_emp NUMBER(10),
    mes NUMBER(2),
    anno NUMBER(4),
    total_haberes NUMBER(10),
    total_descuentos NUMBER(10),
    total_neto NUMBER(10),
    fecha_proceso DATE,
    CONSTRAINT pk_haberes_mensuales PRIMARY KEY (numrut_emp, mes, anno)
);

-- 3. Crear tabla de auditoría para arriendos y secuencia
CREATE TABLE AUDIT_ARRIENDO (
    id_audit NUMBER PRIMARY KEY,
    nro_propiedad NUMBER,
    numrut_cli NUMBER,
    fecini_arriendo_old DATE,
    fecini_arriendo_new DATE,
    fecter_arriendo_old DATE,
    fecter_arriendo_new DATE,
    usuario VARCHAR2(100),
    fecha_modificacion DATE
);

CREATE SEQUENCE seq_audit_arriendo;

-- 10. Crear procedimiento para generar haberes mensuales
CREATE OR REPLACE PROCEDURE P_GENERAR_HABERES_MENSUALES(p_mes NUMBER, p_anno NUMBER) IS
    TYPE r_empleado IS RECORD (
        numrut_emp empleado.numrut_emp%TYPE,
        sueldo_emp empleado.sueldo_emp%TYPE
    );
    TYPE t_empleados IS TABLE OF r_empleado;
    v_empleados t_empleados;
    v_total_haberes NUMBER;
    v_total_descuentos NUMBER;
    v_total_neto NUMBER;
    v_comision NUMBER;
    v_prevision NUMBER;
    v_salud NUMBER;
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
    v_errores varray_mensajes := varray_mensajes();
BEGIN
    v_fecha_inicio := TO_DATE('01/' || p_mes || '/' || p_anno, 'DD/MM/YYYY');
    v_fecha_fin := LAST_DAY(v_fecha_inicio);

    SELECT numrut_emp, sueldo_emp
    BULK COLLECT INTO v_empleados
    FROM empleado;

    FOR i IN 1..v_empleados.COUNT LOOP
        v_total_haberes := v_empleados(i).sueldo_emp;
        v_comision := 0;

        FOR arriendo IN (
            SELECT p.nro_propiedad, p.valor_arriendo
            FROM propiedad p
            JOIN arriendo_propiedad a ON p.nro_propiedad = a.nro_propiedad
            WHERE p.numrut_emp = v_empleados(i).numrut_emp
            AND a.fecini_arriendo <= v_fecha_fin
            AND (a.fecter_arriendo IS NULL OR a.fecter_arriendo >= v_fecha_inicio)
        ) LOOP
            v_comision := v_comision + F_CALCULAR_COMISION(arriendo.valor_arriendo);
        END LOOP;

        v_total_haberes := v_total_haberes + v_comision;

        BEGIN
            SELECT prevision, salud INTO v_prevision, v_salud
            FROM DESCUENTOS
            WHERE numrut_emp = v_empleados(i).numrut_emp
            AND mes_proceso = p_mes
            AND anno_proceso = p_anno;
            v_total_descuentos := v_prevision + v_salud;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_total_descuentos := 0;
            WHEN OTHERS THEN
                v_total_descuentos := 0;
                v_errores.EXTEND;
                v_errores(v_errores.COUNT) := 'Error descuentos empleado ' || v_empleados(i).numrut_emp;
                INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
                VALUES (seq_error.NEXTVAL, 'P_GENERAR_HABERES_MENSUALES', 'MEDIA', 'Error al obtener descuentos: ' || SQLERRM, SYSDATE);
        END;

        v_total_neto := v_total_haberes - v_total_descuentos;

        BEGIN
            INSERT INTO HABERES_MENSUALES (numrut_emp, mes, anno, total_haberes, total_descuentos, total_neto, fecha_proceso)
            VALUES (v_empleados(i).numrut_emp, p_mes, p_anno, v_total_haberes, v_total_descuentos, v_total_neto, SYSDATE);
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                UPDATE HABERES_MENSUALES
                SET total_haberes = v_total_haberes,
                    total_descuentos = v_total_descuentos,
                    total_neto = v_total_neto,
                    fecha_proceso = SYSDATE
                WHERE numrut_emp = v_empleados(i).numrut_emp AND mes = p_mes AND anno = p_anno;
            WHEN OTHERS THEN
                v_errores.EXTEND;
                v_errores(v_errores.COUNT) := 'Error insert empleado ' || v_empleados(i).numrut_emp;
                INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
                VALUES (seq_error.NEXTVAL, 'P_GENERAR_HABERES_MENSUALES', 'ALTA', 'Error al insertar haberes: ' || SQLERRM, SYSDATE);
        END;
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
        VALUES (seq_error.NEXTVAL, 'P_GENERAR_HABERES_MENSUALES', 'ALTA', 'Error general: ' || SQLERRM, SYSDATE);
        RAISE;
END;
/
