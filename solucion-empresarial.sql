
/**************************************************************************
  Archivo: A.sql
  Descripción: Script único  con salida DBMS_OUTPUT para logs.
  NOTA PRE-EJECUCIÓN:
    - En SQL*Plus / SQL Developer habilitar DBMS_OUTPUT:
        SET SERVEROUTPUT ON SIZE 1000000
      o en PL/SQL:
        BEGIN DBMS_OUTPUT.ENABLE(NULL); END;
**************************************************************************/



-- PRECAUCIÓN: habilitar DBMS_OUTPUT  antes de ejecutar tests:
--    SET SERVEROUTPUT ON SIZE 1000000
-- o ejecutar al inicio:
--    BEGIN DBMS_OUTPUT.ENABLE(NULL); END;




-- 1) Crear tipo varray_mensajes (tipo SQL) si no existe

DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM user_types
  WHERE type_name = 'VARRAY_MENSAJES';

  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TYPE varray_mensajes AS VARRAY(200) OF VARCHAR2(4000)';
  END IF;
END;
/

-- 0.2) Crear secuencia seq_error si no existe

DECLARE
  v_count2 INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count2
  FROM user_sequences
  WHERE sequence_name = 'SEQ_ERROR';

  IF v_count2 = 0 THEN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_error START WITH 1 INCREMENT BY 1 NOCACHE';
  END IF;
END;
/

-- 1) Procedimiento utilitario central para registrar errores (con DBMS_OUTPUT)

CREATE OR REPLACE PROCEDURE SP_LOG_ERROR (
  p_subprograma IN VARCHAR2,
  p_gravedad    IN VARCHAR2,
  p_mensaje     IN VARCHAR2
) IS
BEGIN
  -- Insert en tabla de logs
  INSERT INTO LOG_ERRORES_PLSQL (id_error, subprograma, gravedad, mensaje, fecha_proceso)
  VALUES (seq_error.NEXTVAL, p_subprograma, p_gravedad, SUBSTR(p_mensaje,1,4000), SYSDATE);
  COMMIT;
  -- Escritura a DBMS_OUTPUT para visibilidad inmediata
  BEGIN
    DBMS_OUTPUT.PUT_LINE('LOG_ERROR [' || p_gravedad || '] ' || p_subprograma || ' : ' || SUBSTR(p_mensaje,1,2000));
  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- No queremos que falle el logging por DBMS_OUTPUT
  END;
EXCEPTION
  WHEN OTHERS THEN
    -- Si falla el logging hacia la tabla, intentar al menos mostrar en DBMS_OUTPUT
    BEGIN
      DBMS_OUTPUT.PUT_LINE('SP_LOG_ERROR FALLA: ' || SQLERRM || ' subprograma=' || p_subprograma || ' msg=' || SUBSTR(p_mensaje,1,1000));
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
END;
/

-- 2) Funciones revisadas (mantener DBMS_OUTPUT vía SP_LOG_ERROR)


-- F_GET_ANTIGUEDAD_ANIOS
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
        SP_LOG_ERROR('F_GET_ANTIGUEDAD_ANIOS','BAJA','NO_DATA_FOUND: empleado '||NVL(TO_CHAR(p_numrut_emp),'NULL'));
        RETURN 0;
    WHEN TOO_MANY_ROWS THEN
        SP_LOG_ERROR('F_GET_ANTIGUEDAD_ANIOS','ALTA','TOO_MANY_ROWS: múltiples registros para numrut_emp '||NVL(TO_CHAR(p_numrut_emp),'NULL'));
        RETURN -1;
    WHEN OTHERS THEN
        SP_LOG_ERROR('F_GET_ANTIGUEDAD_ANIOS','ALTA','OTHERS: '||SQLERRM||' for numrut '||NVL(TO_CHAR(p_numrut_emp),'NULL'));
        RETURN -1;
END;
/
-- F_CALCULAR_INTERES
CREATE OR REPLACE FUNCTION F_CALCULAR_INTERES(p_dias_atraso NUMBER) RETURN NUMBER IS
    v_interes NUMBER;
BEGIN
    IF p_dias_atraso IS NULL THEN
        RAISE NO_DATA_FOUND;
    END IF;

    IF p_dias_atraso <= 0 THEN
        RETURN 0;
    ELSE
        v_interes := p_dias_atraso * 0.001; -- 0.1% por día
        RETURN v_interes;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        SP_LOG_ERROR('F_CALCULAR_INTERES','BAJA','NO_DATA_FOUND: p_dias_atraso IS NULL');
        RETURN 0;
    WHEN OTHERS THEN
        SP_LOG_ERROR('F_CALCULAR_INTERES','MEDIA','OTHERS: '||SQLERRM||' p_dias_atraso='||NVL(TO_CHAR(p_dias_atraso),'NULL'));
        RETURN 0;
END;
/
-- F_CALCULAR_COMISION
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
        SP_LOG_ERROR('F_CALCULAR_COMISION','BAJA','NO_DATA_FOUND: no hay rango para valor '||NVL(TO_CHAR(p_valor_arriendo),'NULL'));
        RETURN 0;
    WHEN TOO_MANY_ROWS THEN
        SP_LOG_ERROR('F_CALCULAR_COMISION','MEDIA','TOO_MANY_ROWS: rangos solapados para valor '||NVL(TO_CHAR(p_valor_arriendo),'NULL'));
        RETURN 0;
    WHEN OTHERS THEN
        SP_LOG_ERROR('F_CALCULAR_COMISION','ALTA','OTHERS: '||SQLERRM||' valor='||NVL(TO_CHAR(p_valor_arriendo),'NULL'));
        RETURN 0;
END;
/
-- F_OBTENER_TIPO_PROPIEDAD
CREATE OR REPLACE FUNCTION F_OBTENER_TIPO_PROPIEDAD(p_nro_propiedad NUMBER) RETURN VARCHAR2 IS
    v_tipo_propiedad VARCHAR2(200);
BEGIN
    SELECT tp.desc_tipo_propiedad INTO v_tipo_propiedad
    FROM propiedad p
    JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad
    WHERE p.nro_propiedad = p_nro_propiedad;

    RETURN v_tipo_propiedad;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        SP_LOG_ERROR('F_OBTENER_TIPO_PROPIEDAD','BAJA','NO_DATA_FOUND: propiedad '||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'No encontrado';
    WHEN TOO_MANY_ROWS THEN
        SP_LOG_ERROR('F_OBTENER_TIPO_PROPIEDAD','MEDIA','TOO_MANY_ROWS: propiedad duplicada '||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'Error';
    WHEN OTHERS THEN
        SP_LOG_ERROR('F_OBTENER_TIPO_PROPIEDAD','BAJA','OTHERS: '||SQLERRM||' nro='||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'Error';
END;
/
-- F_OBTENER_PROPIETARIO
CREATE OR REPLACE FUNCTION F_OBTENER_PROPIETARIO(p_nro_propiedad NUMBER) RETURN VARCHAR2 IS
    v_propietario VARCHAR2(400);
BEGIN
    SELECT pr.nombre_prop || ' ' || pr.appaterno_prop || ' ' || pr.apmaterno_prop INTO v_propietario
    FROM propiedad p
    JOIN propietario pr ON p.numrut_prop = pr.numrut_prop
    WHERE p.nro_propiedad = p_nro_propiedad;

    RETURN v_propietario;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        SP_LOG_ERROR('F_OBTENER_PROPIETARIO','BAJA','NO_DATA_FOUND: propietario no encontrado para propiedad '||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'No encontrado';
    WHEN TOO_MANY_ROWS THEN
        SP_LOG_ERROR('F_OBTENER_PROPIETARIO','MEDIA','TOO_MANY_ROWS: múltiples propietarios para propiedad '||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'Error';
    WHEN OTHERS THEN
        SP_LOG_ERROR('F_OBTENER_PROPIETARIO','BAJA','OTHERS: '||SQLERRM||' nro='||NVL(TO_CHAR(p_nro_propiedad),'NULL'));
        RETURN 'Error';
END;
/

-- 3) Procedimientos revisados (con salida DBMS_OUTPUT donde corresponde)


-- P_DETECTAR_SOLAPAMIENTOS
CREATE OR REPLACE PROCEDURE P_DETECTAR_SOLAPAMIENTOS IS
    CURSOR c_propiedades IS
        SELECT nro_propiedad FROM propiedad;
    -- usar varray definido
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
            SP_LOG_ERROR('P_DETECTAR_SOLAPAMIENTOS','ALTA', v_errores(v_errores.COUNT));
        END LOOP;
    END LOOP;

    -- Mostrar en DBMS_OUTPUT resumen de solapamientos detectados
    IF v_errores.COUNT > 0 THEN
      DBMS_OUTPUT.PUT_LINE('P_DETECTAR_SOLAPAMIENTOS: Se detectaron ' || v_errores.COUNT || ' solapamientos.');
      FOR i IN 1..v_errores.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  - ' || v_errores(i));
      END LOOP;
    ELSE
      DBMS_OUTPUT.PUT_LINE('P_DETECTAR_SOLAPAMIENTOS: No se detectaron solapamientos.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        SP_LOG_ERROR('P_DETECTAR_SOLAPAMIENTOS','ALTA','Error general: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE('P_DETECTAR_SOLAPAMIENTOS ERROR: ' || SQLERRM);
        RAISE;
END;
/
-- P_GENERAR_HABERES_MENSUALES (usa varray_mensajes para acumular logs y DBMS_OUTPUT al final)
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
    v_msgs varray_mensajes := varray_mensajes();
    v_counter NUMBER := 0;
BEGIN
    v_fecha_inicio := TO_DATE('01/' || LPAD(p_mes,2,'0') || '/' || p_anno, 'DD/MM/YYYY');
    v_fecha_fin := LAST_DAY(v_fecha_inicio);

    -- Reemplazo de BULK COLLECT por cursor complejo con FETCH
    DECLARE
        CURSOR c_empleados IS
            SELECT numrut_emp, sueldo_emp
            FROM empleado;
        v_emp r_empleado;
    BEGIN
        v_empleados := t_empleados();
        OPEN c_empleados;
        LOOP
            FETCH c_empleados INTO v_emp;
            EXIT WHEN c_empleados%NOTFOUND;
            
            v_empleados.EXTEND;
            v_empleados(v_empleados.COUNT) := v_emp;
        END LOOP;
        CLOSE c_empleados;
    END;

    IF v_empleados.COUNT = 0 THEN
      SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','BAJA','No hay empleados para procesar mes='||p_mes||' anno='||p_anno);
      DBMS_OUTPUT.PUT_LINE('P_GENERAR_HABERES_MENSUALES: No hay empleados para procesar para '||p_mes||'/'||p_anno);
      RETURN;
    END IF;

    FOR i IN 1..v_empleados.COUNT LOOP
        v_total_haberes := NVL(v_empleados(i).sueldo_emp,0);
        v_comision := 0;

        -- calcular comisiones por arriendos activos en el periodo
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

            v_total_descuentos := NVL(v_prevision,0) + NVL(v_salud,0);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_total_descuentos := 0;
                v_counter := v_counter + 1;
                v_msgs.EXTEND;
                v_msgs(v_msgs.COUNT) := 'NO_DATA_FOUND descuentos empleado '||v_empleados(i).numrut_emp;
                SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','BAJA','NO_DATA_FOUND descuentos empleado '||v_empleados(i).numrut_emp);
            WHEN TOO_MANY_ROWS THEN
                v_total_descuentos := 0;
                v_counter := v_counter + 1;
                v_msgs.EXTEND;
                v_msgs(v_msgs.COUNT) := 'TOO_MANY_ROWS en DESCUENTOS para empleado '||v_empleados(i).numrut_emp;
                SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','ALTA','TOO_MANY_ROWS en DESCUENTOS para empleado '||v_empleados(i).numrut_emp);
            WHEN OTHERS THEN
                v_total_descuentos := 0;
                v_counter := v_counter + 1;
                v_msgs.EXTEND;
                v_msgs(v_msgs.COUNT) := 'ERROR al obtener descuentos: '||SQLERRM||' emp='||v_empleados(i).numrut_emp;
                SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','ALTA','Error al obtener descuentos: '||SQLERRM||' emp='||v_empleados(i).numrut_emp);
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
                v_counter := v_counter + 1;
                v_msgs.EXTEND;
                v_msgs(v_msgs.COUNT) := 'ERROR insertar/actualizar HABERES_MENSUALES: '||SQLERRM||' emp='||v_empleados(i).numrut_emp;
                SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','ALTA','Error insertar/actualizar HABERES_MENSUALES: '||SQLERRM||' emp='||v_empleados(i).numrut_emp);
        END;
    END LOOP;

    COMMIT;

    -- Mostrar resumen y mensajes acumulados via DBMS_OUTPUT
    DBMS_OUTPUT.PUT_LINE('P_GENERAR_HABERES_MENSUALES finalizado. Empleados procesados: ' || v_empleados.COUNT || '. Mensajes: ' || v_counter);
    IF v_counter > 0 THEN
      FOR i IN 1..v_msgs.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  * ' || v_msgs(i));
      END LOOP;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        SP_LOG_ERROR('P_GENERAR_HABERES_MENSUALES','ALTA','Error general: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE('P_GENERAR_HABERES_MENSUALES ERROR GENERAL: ' || SQLERRM);
        RAISE;
END;
/

-- 4) Trigger de auditoría: TRG_AUDIT_ARRIENDO_AFTER_UPDATE (sin cambios funcionales)

CREATE OR REPLACE TRIGGER TRG_AUDIT_ARRIENDO_AFTER_UPDATE
AFTER UPDATE ON arriendo_propiedad
FOR EACH ROW
BEGIN
    -- Solo registrar si las fechas críticas cambiaron
    IF NVL(:OLD.fecini_arriendo, TO_DATE('1900-01-01','YYYY-MM-DD')) <> NVL(:NEW.fecini_arriendo, TO_DATE('1900-01-01','YYYY-MM-DD'))
       OR NVL(:OLD.fecter_arriendo, TO_DATE('1900-01-01','YYYY-MM-DD')) <> NVL(:NEW.fecter_arriendo, TO_DATE('1900-01-01','YYYY-MM-DD')) THEN

        INSERT INTO AUDIT_ARRIENDO (
            id_audit, nro_propiedad, numrut_cli,
            fecini_arriendo_old, fecini_arriendo_new,
            fecter_arriendo_old, fecter_arriendo_new,
            usuario, fecha_modificacion
        ) VALUES (
            seq_audit_arriendo.NEXTVAL,
            :OLD.nro_propiedad,
            :OLD.numrut_cli,
            :OLD.fecini_arriendo,
            :NEW.fecini_arriendo,
            :OLD.fecter_arriendo,
            :NEW.fecter_arriendo,
            NVL(USER,'UNKNOWN'),
            SYSDATE
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        SP_LOG_ERROR('TRG_AUDIT_ARRIENDO_AFTER_UPDATE','MEDIA','Error en trigger: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE('TRG_AUDIT_ARRIENDO_AFTER_UPDATE ERROR: ' || SQLERRM);
END;
/

-- 5) Scripts de prueba 

-- Antes de ejecutar las pruebas, asegúrate de habilitar DBMS_OUTPUT:
    SET SERVEROUTPUT ON SIZE 1000000
--
-- 5.1 Forzar NO_DATA_FOUND en F_GET_ANTIGUEDAD_ANIOS
 BEGIN
   DBMS_OUTPUT.PUT_LINE('antig: ' || F_GET_ANTIGUEDAD_ANIOS(999999999));
 END;
 /

-- 5.2 Forzar TOO_MANY_ROWS en F_GET_ANTIGUEDAD_ANIOS (solo en ambiente de prueba)
 INSERT INTO empleado (numrut_emp, fecing_emp, sueldo_emp) VALUES (77777777, DATE '2010-01-01', 100000);
 INSERT INTO empleado (numrut_emp, fecing_emp, sueldo_emp) VALUES (77777777, DATE '2011-02-02', 120000);
 BEGIN
   DBMS_OUTPUT.PUT_LINE('antig: ' || F_GET_ANTIGUEDAD_ANIOS(77777777));
 EXCEPTION
   WHEN OTHERS THEN
     NULL;
 END;
 /
DELETE FROM empleado WHERE numrut_emp = 77777777;
COMMIT;

-- 5.3 Forzar error en F_CALCULAR_COMISION (NO_DATA_FOUND o TOO_MANY_ROWS)
 SELECT F_CALCULAR_COMISION(999999) FROM dual;

-- 5.4 Probar trigger de auditoría (ajustar nro_propiedad a un valor real de prueba)
 SELECT * FROM arriendo_propiedad WHERE ROWNUM = 1;
 UPDATE arriendo_propiedad
 SET fecini_arriendo = fecini_arriendo + 1,
     fecter_arriendo = NVL(fecter_arriendo, SYSDATE) + 1
 WHERE ROWID IN (SELECT ROWID FROM arriendo_propiedad WHERE ROWNUM = 1);
 COMMIT;
 SELECT * FROM AUDIT_ARRIENDO ORDER BY fecha_modificacion DESC;

-- 5.5 Ejecutar P_DETECTAR_SOLAPAMIENTOS
 BEGIN
  P_DETECTAR_SOLAPAMIENTOS;
 END;
 /

-- 5.6 Ejecutar P_GENERAR_HABERES_MENSUALES para un mes de prueba
 BEGIN
   P_GENERAR_HABERES_MENSUALES(7, 2025);
 END;
 /
 SELECT * FROM HABERES_MENSUALES WHERE mes = 7 AND anno = 2025;


-- FIN DEL SCRIPT

