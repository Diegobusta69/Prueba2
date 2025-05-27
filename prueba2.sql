--tabla sin datos

select * from detalle_asignacion_mes;

select * from resumen_mes_profesion;

select * from errores_proceso;





--EJECUTAMOS DESDE AQUÍ HACIA EL FIN

--VARIABLES BIND

VARIABLE v_mes_proceso NUMBER;

VARIABLE v_anno_proceso NUMBER;

VARIABLE v_valor_max_beneficio NUMBER;



--ASIGNAMOS EL VALOR PARA LAS VARIABLES BIND

EXEC :v_mes_proceso := 07;

EXEC :v_anno_proceso := 2021;

EXEC :v_valor_max_beneficio := 300000;



--SEQUENCE DROP Y CREATE

DROP SEQUENCE SQ_ERROR;

CREATE SEQUENCE SQ_ERROR;





--DECLARAMOS EL BLOQUE 

DECLARE

    --DECLARAMOS EL CURSOR

    CURSOR CUR_ASESORIA IS 

       SELECT 

        P.NUMRUN_PROF || '-' || P.DVRUN_PROF AS RUN_PROFESIONAL,

        P.NOMBRE || ' ' || P.APPATERNO || ' ' || P.APMATERNO AS NOMBRE,

        PR.NOMBRE_PROFESION,

        NVL(P.SUELDO, 0) AS SUELDO,

        NVL(CANT_ASESORIAS.CANTIDAD, 0) AS CANTIDAD_ASESORIAS,

        C.NOM_COMUNA,

        NVL(P.PUNTAJE, 0) AS PUNTAJE,

        NVL(CANT_ASESORIAS.TOTAL_HONORARIO, 0) AS HONORARIO

    FROM PROFESIONAL P

    JOIN PROFESION PR ON P.COD_PROFESION = PR.COD_PROFESION

    JOIN COMUNA C ON P.COD_COMUNA = C.COD_COMUNA

    LEFT JOIN (

        SELECT 

            NUMRUN_PROF,

            COUNT(*) AS CANTIDAD,

            SUM(NVL(HONORARIO, 0)) AS TOTAL_HONORARIO

        FROM ASESORIA

        GROUP BY NUMRUN_PROF

    ) CANT_ASESORIAS ON CANT_ASESORIAS.NUMRUN_PROF = P.NUMRUN_PROF;



    TYPE T_ASESORIA IS RECORD(

        V_RUN_PROFESIONAL       VARCHAR2(15),

        V_NOMBRE                VARCHAR2(60),

        V_PROFESION             PROFESION.NOMBRE_PROFESION%TYPE,

        V_SUELDO                PROFESIONAL.SUELDO%TYPE,

        V_CANTIDAD_ASESORIAS    NUMBER,

        V_NOMBRE_COMUNA         COMUNA.NOM_COMUNA%TYPE,

        V_PUNTAJE               PROFESIONAL.PUNTAJE%TYPE,

        V_HONORARIO             ASESORIA.HONORARIO%TYPE

    );

    

    --DECLARAMOS EL ARRAY PARA LOS VALORES DE PUNTAJE

    TYPE T_ARRAY IS VARRAY(3) OF NUMBER;

    

    --DECLARAMOS LA VARIABLE PARA UTILIZAR EL ARRAY

    V_ARRAY T_ARRAY;

    

    --Variable tipo compuesto

    V_ASESORIA T_ASESORIA;

    

    --VARIABLES GENERALES

    V_MONTO_MOVIL_EXTRA         NUMBER:=0;

    V_MONTO_ASIG_TIPOCONT       NUMBER:=0; --ZONA

    V_MONTO_ASIG_PROFESION      NUMBER:=0; --ASIG PUNTAJE

    V_MONTO_TOTAL_ASIGNACIONES  NUMBER:=0; 

    

    --SUMAS TOTALES

    V_TOTAL_ASESORIAS           NUMBER:=0;

    V_TOTAL_HONORARIOS          NUMBER:=0;

    V_TOTAL_MOVIL_EXTRA         NUMBER:=0;

    V_TOTAL_ASIG_TIPOCONT       NUMBER:=0;

    V_TOTAL_ASIG_PROFESION      NUMBER:=0;

    V_TOTAL_ASIGNACIONES        NUMBER:=0;

    

    V_DESCRIPCION_ERROR         VARCHAR(200);

    

BEGIN

    DELETE FROM DETALLE_ASIGNACION_MES;

    DELETE FROM RESUMEN_MES_PROFESION;

    DELETE FROM ERRORES_PROCESO;

    

    --LE DAMOS LOS VALORES DEL PORCENTAJE AL ARRAY

    V_ARRAY := T_ARRAY(0.04, 0.08, 0.12);

    --ABRIMOS EL CURSOR CREADO ANTERIORMENTE

    OPEN CUR_ASESORIA;

        LOOP    

            FETCH CUR_ASESORIA INTO V_ASESORIA;

            EXIT WHEN CUR_ASESORIA%NOTFOUND;

                BEGIN

                    IF V_ASESORIA.V_HONORARIO IS NOT NULL THEN

                    

                        --BONIFICACION BDM REGLA DE NEGOCIO

                        IF V_ASESORIA.V_CANTIDAD_ASESORIAS BETWEEN 1 AND 2 THEN

                            V_MONTO_MOVIL_EXTRA := ROUND(V_ASESORIA.V_HONORARIO * 0.03);

                        ELSIF V_ASESORIA.V_CANTIDAD_ASESORIAS BETWEEN 3 AND 4 THEN

                            V_MONTO_MOVIL_EXTRA := ROUND(V_ASESORIA.V_HONORARIO * 0.06);

                        ELSIF V_ASESORIA.V_CANTIDAD_ASESORIAS >=5 THEN

                            V_MONTO_MOVIL_EXTRA := ROUND(V_ASESORIA.V_HONORARIO * 0.1);

                        ELSE

                            V_MONTO_MOVIL_EXTRA :=0;

                        END IF;

                    ELSE

                        V_MONTO_MOVIL_EXTRA := 0;

                    END IF;

                    

                    --REGLA DE NEGOCIO POR COMUNA

                    IF V_ASESORIA.V_NOMBRE_COMUNA = 'Puente Alto' THEN

                        V_MONTO_ASIG_TIPOCONT := 15000;

                    ELSIF V_ASESORIA.V_NOMBRE_COMUNA = 'San Bernardo' THEN

                        V_MONTO_ASIG_TIPOCONT := 20000;

                     ELSIF V_ASESORIA.V_NOMBRE_COMUNA = 'Maipú' THEN

                        V_MONTO_ASIG_TIPOCONT := 20000;

                    ELSIF V_ASESORIA.V_NOMBRE_COMUNA = 'Peñalolén' THEN

                        V_MONTO_ASIG_TIPOCONT := 22000;

                    ELSE

                        V_MONTO_ASIG_TIPOCONT := 10000;

                        

                    END IF;

                    

                    --BONIFICACION POR PUNTAJE REGLA DE NEGOCIO

                    IF V_ASESORIA.V_PUNTAJE BETWEEN 0 AND 69 THEN

                        V_MONTO_ASIG_PROFESION := V_ASESORIA.V_SUELDO * 0;

                    ELSIF V_ASESORIA.V_PUNTAJE BETWEEN 70 AND 79 THEN

                        V_MONTO_ASIG_PROFESION := V_ASESORIA.V_SUELDO * V_ARRAY(1);

                    ELSIF V_ASESORIA.V_PUNTAJE BETWEEN 80 AND 89 THEN

                        V_MONTO_ASIG_PROFESION := V_ASESORIA.V_SUELDO * V_ARRAY(2);

                    ELSIF V_ASESORIA.V_PUNTAJE BETWEEN 90 AND 100 THEN

                        V_MONTO_ASIG_PROFESION := V_ASESORIA.V_SUELDO * V_ARRAY(3);

                    ELSE 

                        V_MONTO_ASIG_PROFESION := 0;

                    END IF;

                    

                    

                    --SUMA DEL TOTAL DE LAS ASIGNACIONES REGLA DE NEGOCIO

                    V_MONTO_TOTAL_ASIGNACIONES:= V_MONTO_MOVIL_EXTRA + V_MONTO_ASIG_TIPOCONT + V_MONTO_ASIG_PROFESION;

                    

                    -- TOPE MÁXIMO DE BENEFICIO MENSUAL 300000

                    IF V_MONTO_TOTAL_ASIGNACIONES > 300000 THEN

                        V_MONTO_TOTAL_ASIGNACIONES := 300000;

                        

                        --MANEJO DE ERROR POR EXCESO DE MONTO DEL TOTAL DE ASIGNACIONES

                        V_DESCRIPCION_ERROR := 'El monto total de asignaciones excedió los 300.000 pesos.';  

                        INSERT INTO errores_proceso (

                            ERROR_ID,

                            MENSAJE_ERROR_ORACLE,

                            MENSAJE_ERROR_USR

                        )VALUES (

                            SQ_ERROR.NEXTVAL,  

                            V_DESCRIPCION_ERROR,   

                            USER  

                        ); 

                    END IF;

                    

                    IF V_ASESORIA.V_HONORARIO IS NULL THEN

                        V_ASESORIA.V_HONORARIO := 0;

                    END IF;

                  

                    --TOTALES SEGUNDO INSERT (CALCULOS DE RESUMEN MES PROFESION)

                    V_TOTAL_ASESORIAS := V_TOTAL_ASESORIAS + V_ASESORIA.V_CANTIDAD_ASESORIAS;

                    V_TOTAL_HONORARIOS := V_TOTAL_HONORARIOS + V_ASESORIA.V_HONORARIO;

                    V_TOTAL_MOVIL_EXTRA := V_TOTAL_MOVIL_EXTRA + V_MONTO_MOVIL_EXTRA;

                    V_TOTAL_ASIG_TIPOCONT := V_TOTAL_ASIG_TIPOCONT + V_MONTO_ASIG_TIPOCONT;

                    V_TOTAL_ASIG_PROFESION := V_TOTAL_ASIG_PROFESION + V_MONTO_ASIG_PROFESION;

                    V_TOTAL_ASIGNACIONES := V_TOTAL_ASIGNACIONES + V_MONTO_TOTAL_ASIGNACIONES;

                    

                    

                   --INSERTAMOS EN LA TABLA DETALLE_ASIGNACION_MES

                    INSERT INTO detalle_asignacion_mes (

                        mes_proceso,

                        anno_proceso,

                        run_profesional,

                        nombre_profesional,

                        profesion,

                        nro_asesorias,

                        monto_honorarios,

                        monto_movil_extra,

                        monto_asig_tipocont,

                        monto_asig_profesion,

                        monto_total_asignaciones

                    ) VALUES ( :v_mes_proceso,

                               :v_anno_proceso,

                               V_ASESORIA.V_RUN_PROFESIONAL,

                               V_ASESORIA.V_NOMBRE,

                               V_ASESORIA.V_PROFESION,

                               ROUND(v_ASESORIA.V_CANTIDAD_ASESORIAS,0),

                               ROUND(V_ASESORIA.V_HONORARIO, 0),

                               ROUND(V_MONTO_MOVIL_EXTRA, 0),

                               ROUND(V_MONTO_ASIG_TIPOCONT, 0),

                               ROUND(V_MONTO_ASIG_PROFESION, 0),

                               ROUND(V_MONTO_TOTAL_ASIGNACIONES, 0)

                               );

                         

                

                --PRINCIPALES PROBLEMAS ENCONTRADOS: 

                --La tabla al tener como primary key 2 columnas (anno_mes_proceso y profesion)

                --Cuando intentamos insertar el problema es que si se repiten algunos registros

                --de esas 2 llaves primarias juntas el insert se va a caer por que al ser primary key

                --no va a dejar insertar registros duplicados

                

                --Siguiente problema:

                --Al parecer algunos registros de los totales exceden el largo del tipo de dato number

                --EJ: el total de monto honorario tiene de largo 6 osea un number(6,0) eso daria como maximo

                --999.999 lo cual si algún total de las variables trabajadas excede los 6 numeros de largo tal como seria

                --1.000.000 el insert terminaría cayendose y por ende el proceso también.

                

                --INSERT RESUMEN MES 

                    INSERT INTO resumen_mes_profesion (

                        anno_mes_proceso,

                        profesion,

                        total_asesorias,

                        monto_total_honorarios,

                        monto_total_movil_extra,

                        monto_total_asig_tipocont,

                        monto_total_asig_prof,

                        monto_total_asignaciones

                    ) VALUES ( :v_mes_proceso||'-'||:v_anno_proceso,

                               V_ASESORIA.V_PROFESION,

                               V_TOTAL_ASESORIAS,

                               V_TOTAL_HONORARIOS,

                               V_TOTAL_MOVIL_EXTRA,

                               V_TOTAL_ASIG_TIPOCONT,

                               V_TOTAL_ASIG_PROFESION,

                               V_TOTAL_ASIGNACIONES);

                    

                    

                --CAPTURA DE ERRORES

                EXCEPTION

                    WHEN OTHERS THEN

                        V_DESCRIPCION_ERROR := SQLERRM;  

                        INSERT INTO errores_proceso (

                            ERROR_ID,

                            MENSAJE_ERROR_ORACLE,

                            MENSAJE_ERROR_USR

                        )VALUES (

                            SQ_ERROR.NEXTVAL,  

                            V_DESCRIPCION_ERROR,   

                            USER  

                        ); 

                END;

        END LOOP;

    CLOSE CUR_ASESORIA;

END;