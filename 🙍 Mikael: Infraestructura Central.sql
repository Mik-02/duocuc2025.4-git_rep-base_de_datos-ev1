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

