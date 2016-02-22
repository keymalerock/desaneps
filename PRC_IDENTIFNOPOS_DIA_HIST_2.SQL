CREATE OR REPLACE PROCEDURE RECOBROSFAM.PRC_IDENTIFNOPOS_DIA_HIST_2 (vcerror   IN OUT   VARCHAR2)
IS
      /******************************************************************************************************************************************************
       APLICACIÓN: CUENTAS MEDICAS
       PARAMETROS:
                  ENTRADA: Ninguna
       CASO: 1736225

       PRERREQUISITOS:
         1- Tabla vigencias actualizada (RECOBROS.MAPIISS_RECOBROS)

       HISTORIA DE LAS MODIFICACIONES
       1-)06/04/2015, Diana Rodriguez: Migracion recobros: Se crea tabla de filtro con solo el campo del numero de radicacion y direccionando el proceso a esa tabla.
       2-)20/01/2016  Erick Johan; se modifico el bloque donde se graba en la tabla NEPS_IDENTIFNOPOS_DAILY_HIST para evitar que ingresen registros cuyas
                                   cuentas ya han sido eliminadas en FAMISANA, el filtro que se coloco es para ir comparando si los registros diarios NOPOS
                                   estan emparentados. en caso que no este en la tabla filtro, no se dejara ingresar ese registro ya que se asume huerfano sin cuenta
                                   medica activa. req 1073
		3-)febrero 18 2016 Erick Bonilla: se incluyeron nuevas parametrizaciones para las reglas de asignacion de operadores segun req 1078, se excluye del proceso
                                          de Identificacion NoPoS la regla del menor valor.		
      *******************************************************************************************************************************************************/
      nm_ord_numero         NUMBER;
      vc_ORDMES             VARCHAR2 (2);
      vc_ORDANO             VARCHAR2 (4);
      vc_DX_CODIGO          VARCHAR2 (9);
      vc_DX_NOMBRE          VARCHAR2 (2000);
      vc_NUM_AUTORIZACION   VARCHAR2 (15);
      vc_TIPANEXO_AUTORIZ   VARCHAR2 (80);
      vc_ENTIDAD_RESP_LIQ   VARCHAR2 (80);
      vc_AMBITO_SERVICIO    VARCHAR2 (15);
      vc_USU_RESP_LIQ       VARCHAR2 (300);
      vc_RANGO_VLRFACTURA   VARCHAR2 (50);
      vc_ESTADO_RECOBRO     VARCHAR2 (50);
      vc_RESP_AUDITORIA     VARCHAR2 (50);
      dtfech_vigencia       DATE;
      v_errorcode           INTEGER; -- codigo del error
      v_errortext           VARCHAR2(500); -- texto del error
      vc_NRORADICADO        INTEGER;  --variable par almacenar el numero de radicado req 1073
      vc_FOUND            BOOLEAN;   -- variable para alamcenar si encontro o no un registro req 1073
	  v_comp_consul       VARCHAR2(500); -- variable para el complemento de la consulta req 1078
      ------- cursor para verificar si el numero de radicado existe en la tabla filtro del dia  REC_FILT_CTAS_C_FACT
      ------- devuelve 1 si lo encuentra 0 en caso contrario, REQ 1073
           CURSOR CPK5_FACTXIPS(VAR_NIN_FIPS_NRORADICA NUMBER,VAR_F_PCT_CTAFIL_CONSATEN NUMBER) IS
           SELECT 1
           FROM   RECOBROSFAM.REC_FILT_CTAS_C_FACT
           WHERE  F_NIN_FIPS_NRORADICA = VAR_NIN_FIPS_NRORADICA
           and F_PCT_CTAFIL_CONSATEN = VAR_F_PCT_CTAFIL_CONSATEN
           and F_STATUS_CTAS_C_FACT <> 1;
       ------  

      CURSOR rad_nopos
      IS
         SELECT /*+ INDEX(A P_AFILIADO) */  SEQ_NEPS_INOPOS.NEXTVAL NUM_id,
               f.fips_fecharadica, f.fips_nroradica,
               f.fips_nrofact, f.fips_cont_suc_pre_codigo,
               f.fips_cont_suc_numero, f.FIPS_PAR_CODIGO_ESTADO,
               f.FIPS_VALORIPS, f.FIPS_VALOR_GLOSA, f.FIPS_PAR_CODIGO_TPC, f.FIPS_CANT_ATEN,
               --------Datos Cuenta-------------
               c.ctafil_consaten, c.ctafil_afi_tid_codigo,
               c.ctafil_afi_identific,
               C.CTAFIL_FECHA_INI ,
               c.CTAFIL_FECHA_FIN ,
               c.ctafil_copago_eps , c.CTAFIL_CMO_eps,
               c.CTAFIL_PAR_CODIGO_EST ,
               c.CTAFIL_VALORIPS,
               c.CTAFIL_URGENCIA,
               ----------Datos procedimiento-----------
               P.pct_map_mapiiss ,
               P.PCT_EDICION_MAPIISS,
               P.PCT_CANTIDAD_IPS,
               P.pct_valorips,
               P.pct_cantidad_eps,
               P.pct_valoreps,
               nvl(P.pct_valor_pagar_op, 0) pct_valor_pagar_op,
               P.pct_valor_glosa_eps,
               P.pct_valor_glosa_ips,
               P.pct_valor_glosa_pendiente,
               P.pct_valor_glosa_pertinencia,
               P.pct_valor_glosa_tarifa,
               -------datos afiliado
               a.afi_tipcotiza ,
               a.afi_paf_codigo ,
               a.afi_sexo ,
               a.afi_apellido1 ,
               a.afi_apellido2 ,
               a.afi_nombres ,
               a.AFI_FECHAFIL ,
               a.AFI_FECHANACI,
               REPLACE(REGEXP_REPLACE(m.MR_DESCRIPCION,'[^[:print:]]',''),CHR(124), '') MR_DESCRIPCION
          FROM sei.FACTXIPS f, sei.ctasxafil c, sei.PRO_CTA P, RECOBROSFAM.MAPIISS_RECOBROS  m, eps.afiliado a
           WHERE f.fips_fecharadica >= TO_DATE('01/01/2014', 'DD/MM/YYYY')
              and f.FIPS_PAR_CODIGO_ESTADO in ('ORD', 'ORD_GLOSA')
              and f.FIPS_PAR_CODIGO_TPC not in ('NI', 'NCR', 'NDB' )
              -----and f.fips_nroradica = 18005546
              AND f.fips_nroradica = c.ctafil_fips_nroradica
              AND P.pct_ctafil_fips_nroradica = c.ctafil_fips_nroradica
              AND P.pct_ctafil_consaten = c.ctafil_consaten
              and P.pct_map_mapiiss = m.MR_COD_MAPIISS
              and trunc(c.CTAFIL_FECHA_INI) BETWEEN m.MR_FECHA_INI and m.MR_FECHA_FIN
              AND m.MR_CODIGO_TIPOPLAN = 'PRO_NOPOS'
              and c.ctafil_afi_tid_codigo = a.afi_tid_codigo
              and c.ctafil_afi_identific = a.afi_identific
              and not exists (select 'x'
                              from recobrosfam.NEPS_IDENTIF_FILTRO_DAILY r
                              where r.f_nin_fips_nroradica = f.fips_nroradica);

        ------tipos
        TYPE t_rad_nopos IS TABLE OF rad_nopos%ROWTYPE INDEX BY BINARY_INTEGER;
        nopos                      t_rad_nopos;
        id_row                     DBMS_SQL.urowid_table;

 BEGIN

      delete from objetos_error
      where err_objeto = 'PRC_IDENTIFNOPOS_DIA_HIST_2';
      COMMIT;

      BEGIN
        DBMS_STATS.GATHER_TABLE_STATS (
          OwnName        => 'RECOBROS'
         ,TabName        => 'NEPS_IDENTIFNOPOS_DAILY_HIST'
         ,Cascade        => TRUE);
      END;

      OPEN  rad_nopos;
      LOOP
         FETCH rad_nopos BULK COLLECT
          INTO nopos LIMIT 5000;
         EXIT WHEN rad_nopos%NOTFOUND AND nopos.COUNT = 0;
         FOR er IN nopos.FIRST .. nopos.LAST LOOP


            nm_ord_numero         := 0;
            vc_ORDMES             := NULL;
            vc_ORDANO             := NULL;
            vc_DX_CODIGO          := NULL;
            vc_DX_NOMBRE          := NULL;
            vc_NUM_AUTORIZACION   := NULL;
            vc_TIPANEXO_AUTORIZ   := NULL;
            vc_ENTIDAD_RESP_LIQ   := NULL;
            vc_AMBITO_SERVICIO    := NULL;
            vc_USU_RESP_LIQ       := NULL;
            vc_RANGO_VLRFACTURA   := NULL;
            vc_ESTADO_RECOBRO     := NULL;
            vc_RESP_AUDITORIA     := NULL;
            vc_NRORADICADO        := NULL; --inicializo la variale que me indica si existe en la tabla filtro de emparejamiento el nroderadicado req 1073

            BEGIN
              select o.ORD_NUMERO, o.ORD_MES_CONT, o.ORD_ANO_CONT
                into nm_ord_numero, vc_ORDMES, vc_ORDANO
               from sei.orden_pago o
               where o.ORD_FIPS_NRO_RADICA = nopos(er).fips_nroradica
               and o.par_codigo = 'ORDACT'
               and rownum = 1;
              EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  nm_ord_numero   := 0;
                  vc_ORDMES       := NULL;
                  vc_ORDANO       := NULL;
            END;

            BEGIN
              SELECT g.dx_codigo_diagnostico, g.DX_NOMBRE
              into vc_DX_CODIGO, vc_DX_NOMBRE
               FROM sei.DIAGXCTA d, sei.DIAGNOSTICOS g
               WHERE d.DCTA_CTAFIL_FIPS_NRORADICA = nopos(er).fips_nroradica
                AND d.CTAFIL_CONSATEN = nopos(er).ctafil_consaten
                AND d.dcta_dx_codigo_diagnostico = g.dx_codigo_diagnostico
                AND g.dx_edicion = 'EDI_10'
                AND d.DCTA_PRIMARIO_NRO = 1
                and rownum = 1;
              EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  vc_DX_CODIGO    := NULL;
                  vc_DX_NOMBRE    := NULL;
            END;

            BEGIN
              SELECT a.axa_numero_autorizacion, p.par_descripcion
                into vc_NUM_AUTORIZACION, vc_TIPANEXO_AUTORIZ
               FROM sei.AUTXAFIL a
                  INNER JOIN PROCXAUTO P ON ( a.axa_pai_codigo = P.pxa_axa_pai_codigo AND a.axa_numero = P.pxa_axa_numero)
                  LEFT OUTER JOIN autxafil_anexos au ON (a.axa_pai_codigo = au.axa_pai_codigo AND a.axa_numero = au.axa_numero AND au.axa_aplica = 1)
                  LEFT OUTER JOIN parametros p ON (p.par_tabla = 'AUT_ANEXOS' AND au.axa_tipo_anexo = p.par_codigo)
               where a.axa_ctafil_fips_nroradica = nopos(er).fips_nroradica
                and a.axa_ctafil_consaten = nopos(er).ctafil_consaten
                and a.AXA_PAR_CODIGO_ESTADO <> 'AUTANUL'
                and P.pxa_map_mapiiss = nopos(er).pct_map_mapiiss
                and P.pxa_edicion = nopos(er).PCT_EDICION_MAPIISS
                and rownum = 1;
                    EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  vc_NUM_AUTORIZACION   := NULL;
                  vc_TIPANEXO_AUTORIZ   := NULL;
            END;

            BEGIN
                SELECT p.PAR_DESCRIPCION, t.tus_us_codigo
                  INTO vc_ENTIDAD_RESP_LIQ, vc_USU_RESP_LIQ
                FROM TRAB_USUARIO_SALUD t
                  INNER JOIN USUARIO_SALUD u ON (t.tus_us_codigo = u.us_codigo)
                  INNER JOIN parametros p ON (p.par_codigo = u.US_ENTIDAD_RESP AND p.PAR_TABLA = 'ENTRESPDIG')
                WHERE t.TUS_FIPS_NRORADICA = nopos(er).fips_nroradica
                  and rownum = 1;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  vc_ENTIDAD_RESP_LIQ   := NULL;
                  vc_USU_RESP_LIQ       := NULL;
            END;

            BEGIN
                SELECT s.SER_PUCH_CODIGO
                 INTO vc_AMBITO_SERVICIO
                FROM sei.SERVICIOS s
                where s.SER_CODIGO = nopos(er).CTAFIL_URGENCIA;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  vc_AMBITO_SERVICIO    := NULL;
            END;

             ------------------- MARCAR RANGO VALOR FACTURA ---------------------
              BEGIN
                  select FN_RANGO_VLR_INF_REC(nopos(er).FIPS_VALORIPS)
                  into vc_RANGO_VLRFACTURA
                  from dual;
                EXCEPTION
                  WHEN OTHERS THEN
                    vc_RANGO_VLRFACTURA := NULL;
              END;

            ----------------------------------MARCAR ESTADO RECOBRO-------------------------------------
            IF nopos(er).FIPS_PAR_CODIGO_ESTADO in ('ORD', 'ORD_GLOSA') and  nopos(er).CTAFIL_PAR_CODIGO_EST in ('ORD', 'ORD_GLOSA') then

                   vc_ESTADO_RECOBRO := 'PROCESABLE';

              elsif nopos(er).FIPS_PAR_CODIGO_ESTADO in ('DEV', 'ANUL', 'ANUL_RESERVA', 'GLOSA_TOTAL') then

                   vc_ESTADO_RECOBRO := 'NO PROCESABLE';

              ELSE
                   vc_ESTADO_RECOBRO := 'EN TRAMITE';

            END IF;

            ---------------MARCAR ENTIDAD U OUTSOURCING RESPONSABLE DE LA AUDITORIA-----------------
            BEGIN
                select a.AUD_NOMBRE
                  INTO vc_RESP_AUDITORIA
                  from recobrosfam.TEMP_RESPONSABLE_AUDITORIAXIPS a
                where a.NIT_IPS = nopos(er).fips_cont_suc_pre_codigo
                and a.SUCURSAL_IPS = nopos(er).fips_cont_suc_numero
                and trunc(nopos(er).CTAFIL_FECHA_INI) BETWEEN a.AUD_SUC_FECHA_INI_RELACION and nvl(a.AUD_SUC_FECHA_FIN_RELACION, TO_DATE ('01/01/2999', 'dd/mm/yyyy'));
              EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                    vc_RESP_AUDITORIA  := NULL;
            END;
          -------- busca en la tabla filtro dirario si ya existe el NROderadicado y su consecutivo si no existe lo inserta al filtro diario req 1073
           OPEN  CPK5_FACTXIPS(nopos(er).fips_nroradica,nopos(er).ctafil_consaten );
             FETCH CPK5_FACTXIPS INTO vc_NRORADICADO;
             vc_FOUND := CPK5_FACTXIPS%FOUND;
             CLOSE CPK5_FACTXIPS;
             IF NOT vc_FOUND THEN
                INSERT INTO RECOBROSFAM.REC_FILT_CTAS_C_FACT (F_NIN_ID,F_NIN_FIPS_NRORADICA,F_STATUS_CTAS_C_FACT,F_PCT_CTAFIL_CONSATEN  ) 
                                                         VALUES 
                                                                 (nopos(er).NUM_id,
                                                                  nopos(er).fips_nroradica ,
                                                                  0 ,
                                                                  nopos(er).ctafil_consaten);
                
                vc_NRORADICADO :=NULL;
             END IF;

          INSERT INTO recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST
          (NIN_ID, NIN_FIPS_FECHARADICA, NIN_FIPS_NRORADICA, NIN_FIPS_NROFACT, NIN_SUC_PRE_CODIGO, NIN_SUC_NUMERO, NIN_FIPS_PAR_CODIGO_ESTADO, NIN_FIPS_VALORIPS,
           NIN_FIPS_VALOR_GLOSA, NIN_FIPS_PAR_CODIGO_TPC, NIN_CTAFIL_CONSATEN, NIN_AFI_TID_CODIGO, NIN_AFI_IDENTIFIC, NIN_CTAFIL_FECHA_INI, NIN_CTAFIL_FECHA_FIN,
           NIN_CTAFIL_COPAGO_EPS, NIN_CTAFIL_CMO_EPS, NIN_CTAFIL_PAR_CODIGO_EST, NIN_CTAFIL_VALORIPS, NIN_CTAFIL_URGENCIA, NIN_PCT_MAP_MAPIISS, NIN_PCT_EDICION_MAPIISS,
           NIN_PCT_CANTIDAD_IPS, NIN_PCT_VALORIPS, NIN_PCT_CANTIDAD_EPS, NIN_PCT_VALOREPS, NIN_PCT_VALOR_PAGAR_OP, NIN_PCT_VALOR_GLOSA_EPS, NIN_PCT_VALOR_GLOSA_IPS,
           NIN_PCT_VALOR_GLOSA_PEND, NIN_PCT_VALOR_GLOSA_PERT, NIN_PCT_VALOR_GLOSA_TARIFA, NIN_AFI_TIPCOTIZA, NIN_AFI_PAF_CODIGO, NIN_AFI_SEXO, NIN_AFI_APELLIDO1,
           NIN_AFI_APELLIDO2, NIN_AFI_NOMBRES, NIN_AFI_FECHAFIL, NIN_AFI_FECHANACI, NIN_ORD_NUMERO, NIN_ORD_MES_CONT, NIN_ORD_ANO_CONT, NIN_DX_CODIGO, NIN_DX_NOMBRE,
           NIN_AXA_NUM_AUTORIZACION, NIN_TIPANEXO_AUTORIZACION, NIN_ENTIDAD_RESP_LIQ, NIN_AMBITO_SERVICIO, NIN_USU_RESP_LIQ,
           NIN_RANGO_VLR_FACTURA, NIN_ESTADO_RECOBRO, NIN_MAPIISS_DESCRIPCION, NIN_FECHA_INSERCION, NIN_RESP_AUDITORIA, NIN_ESTADO_ITEM, NIN_COD_CAUSAL, NIN_FIPS_CANT_ATEN)
          VALUES (nopos(er).NUM_id,
               nopos(er).fips_fecharadica, nopos(er).fips_nroradica,
               nopos(er).fips_nrofact, nopos(er).fips_cont_suc_pre_codigo,
               nopos(er).fips_cont_suc_numero, nopos(er).FIPS_PAR_CODIGO_ESTADO,
               nopos(er).FIPS_VALORIPS, nopos(er).FIPS_VALOR_GLOSA, nopos(er).FIPS_PAR_CODIGO_TPC,
               nopos(er).ctafil_consaten, nopos(er).ctafil_afi_tid_codigo,
               nopos(er).ctafil_afi_identific,
               nopos(er).CTAFIL_FECHA_INI ,
               nopos(er).CTAFIL_FECHA_FIN ,
               nopos(er).ctafil_copago_eps , nopos(er).CTAFIL_CMO_eps,
               nopos(er).CTAFIL_PAR_CODIGO_EST ,
               nopos(er).CTAFIL_VALORIPS,
               nopos(er).CTAFIL_URGENCIA,
               nopos(er).pct_map_mapiiss ,
               nopos(er).PCT_EDICION_MAPIISS,
               nopos(er).PCT_CANTIDAD_IPS,
               nopos(er).pct_valorips,
               nopos(er).pct_cantidad_eps,
               nopos(er).pct_valoreps,
               nopos(er).pct_valor_pagar_op,
               nopos(er).pct_valor_glosa_eps,
               nopos(er).pct_valor_glosa_ips,
               nopos(er).pct_valor_glosa_pendiente,
               nopos(er).pct_valor_glosa_pertinencia,
               nopos(er).pct_valor_glosa_tarifa,
               nopos(er).afi_tipcotiza ,
               nopos(er).afi_paf_codigo ,
               nopos(er).afi_sexo ,
               nopos(er).afi_apellido1 ,
               nopos(er).afi_apellido2 ,
               nopos(er).afi_nombres ,
               nopos(er).AFI_FECHAFIL ,
               nopos(er).AFI_FECHANACI,
               nm_ord_numero, vc_ORDMES, vc_ORDANO,
               vc_DX_CODIGO, vc_DX_NOMBRE,
               vc_NUM_AUTORIZACION, vc_TIPANEXO_AUTORIZ,
               vc_ENTIDAD_RESP_LIQ,
               vc_AMBITO_SERVICIO,
               vc_USU_RESP_LIQ,
               vc_RANGO_VLRFACTURA,
               vc_ESTADO_RECOBRO,
               nopos(er).MR_DESCRIPCION,
               TRUNC(sysdate),
               vc_RESP_AUDITORIA,
               1, 0,
               nopos(er).FIPS_CANT_ATEN);
         COMMIT;
         /* linea comentada por no existir tabla en ambiente de desarrollo ni pruebas
         /*insert into recobrosfam.NEPS_REC_LOG_IDENTNOPOS
         (NIN_ID, NIN_FIPS_NRORADICA, NIN_CTAFIL_CONSATEN, NIN_PCT_MAP_MAPISS, NIN_AFI_TID_CODIGO, NIN_AFI_IDENTIFIC, NIN_FECHA_INSERCION)
         values (nopos(er).NUM_id,
               nopos(er).fips_nroradica,
               nopos(er).ctafil_consaten, 
               nopos(er).pct_map_mapiiss,
               nopos(er).ctafil_afi_tid_codigo,
               nopos(er).ctafil_afi_identific,
               sysdate);
         commit;   */
         END LOOP;
      END LOOP;
      close rad_nopos;


      BEGIN
        DBMS_STATS.GATHER_TABLE_STATS (
          OwnName        => 'RECOBROS'
         ,TabName        => 'NEPS_IDENTIFNOPOS_DAILY_HIST'
         ,Cascade        => TRUE);
      END;
       -------------------------------------------------------------------------------------------------------------------------
       -----------MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DE LIQUIDAR EL RECOBRO y/o ENTIDAD RESPONSABLE DEL FISICO------------

       BEGIN
          DECLARE

              N_ENT_RESPREC      NUMBER;
              N_ENT_RESPFIS      NUMBER;
              v_rango_vlr_rec    VARCHAR2(50 BYTE);

              TYPE t_NIN_ENTIDAD_RESP_REC IS TABLE OF NEPS_IDENTIFNOPOS_DAILY_HIST.NIN_ENTIDAD_RESP_REC%TYPE;
              TYPE t_NIN_ENTIDAD_RESP_FISICO IS TABLE OF NEPS_IDENTIFNOPOS_DAILY_HIST.NIN_ENTIDAD_RESP_FISICO%TYPE;

              id_row        DBMS_SQL.urowid_table;
              RESP_REC      t_NIN_ENTIDAD_RESP_REC;
              RESP_FISICO   t_NIN_ENTIDAD_RESP_FISICO;

           /*Caso 3020211---Asignar la misma entidad responsable de la preauditoria por radicado y atencion ya que se
            identificaron casos donde un servicio no estaba en la preauditoria pero si en la identificacion NOPOS
            si se toma como registro nuevo calcula erroneamente la entidad responsable*/

           /*Caso 300766---Se elimina regla definida en el caso 3020211*/
           /*Caso 304693---Se habilita nuevamente la regla definida en el caso 3020211*/

           CURSOR busq_ent_resp IS
               SELECT c.NCE_ENTIDAD_RESP_REC, c.NCE_ENTIDAD_RESP_FISICO, i.ROWID idrow
                  FROM recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST i, recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO c
                where i.NIN_FIPS_NRORADICA = c.NCE_FIPS_NRORADICA
                  and i.NIN_CTAFIL_CONSATEN = c.NCE_CTAFIL_CONSATEN
                  ---and i.NIN_PCT_MAP_MAPIISS = c.NCE_PCT_MAP_MAPIISS
                  and i.NIN_ENTIDAD_RESP_REC is null;

           CURSOR ent_resp_rec
           IS
              SELECT N.NIN_FIPS_NRORADICA, N.NIN_CTAFIL_CONSATEN, N.NIN_SUC_NUMERO, N.NIN_SUC_PRE_CODIGO, N.NIN_FIPS_FECHARADICA, MIN(N.NIN_CTAFIL_FECHA_INI) NIN_CTAFIL_FECHA_INI,
                     N.NIN_FIPS_VALORIPS, SUM(nvl(N.NIN_PCT_VALOR_PAGAR_OP,0)) VLR_NOPOS, n.NIN_USU_RESP_LIQ, n.NIN_ENTIDAD_RESP_LIQ, n.NIN_FIPS_PAR_CODIGO_TPC, n.NIN_FIPS_CANT_ATEN
              FROM recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST  n
              where n.NIN_ENTIDAD_RESP_REC is null
              GROUP BY N.NIN_FIPS_NRORADICA, N.NIN_CTAFIL_CONSATEN, N.NIN_SUC_NUMERO, N.NIN_SUC_PRE_CODIGO, N.NIN_FIPS_FECHARADICA, N.NIN_FIPS_VALORIPS, n.NIN_USU_RESP_LIQ, n.NIN_ENTIDAD_RESP_LIQ, n.NIN_FIPS_PAR_CODIGO_TPC, n.NIN_FIPS_CANT_ATEN;


        TYPE t_ent_resp_rec IS TABLE OF ent_resp_rec%ROWTYPE INDEX BY BINARY_INTEGER;
        ent_resp t_ent_resp_rec;

        BEGIN
            /*-------Caso 3020211-Mantener entidad responsable de la preauditoria------
            /*Caso 300766---Se elimina regla definida en el caso 3020211*/
            /*Caso 304693---Se habilita nuevamente la regla definida en el caso 3020211*/
             BEGIN
                OPEN busq_ent_resp;
                LOOP
                  FETCH busq_ent_resp
                  BULK COLLECT INTO RESP_REC, RESP_FISICO, id_row LIMIT 5000;

                  FORALL i IN 1 .. id_row.COUNT
                     UPDATE /*+ append nologging*/recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                        SET r.NIN_ENTIDAD_RESP_REC = RESP_REC(i),
                            r.NIN_ENTIDAD_RESP_FISICO = RESP_FISICO(i)
                      WHERE r.ROWID = id_row (i);
                  COMMIT;
                  EXIT WHEN busq_ent_resp%NOTFOUND;
                END LOOP;
               CLOSE busq_ent_resp;
             END;

          -------Seleccionar la maxima vigencia de los parametros de asignacion de operador----------
           SELECT MAX(ERR_INI_VIGEN)
            INTO dtfech_vigencia
           FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO;

		    ----- Filtro para el req 1078 16/02/2015 Erick Bonilla
				v_comp_consul := '4,6,7,9,10,32';
            --------dbms_output.put_line ('1');
            OPEN  ent_resp_rec;
            LOOP
                 FETCH ent_resp_rec BULK COLLECT
                  INTO ent_resp LIMIT 5000;
                 EXIT WHEN ent_resp_rec%NOTFOUND AND ent_resp.COUNT = 0;

                 FOR er IN ent_resp.FIRST .. ent_resp.LAST LOOP

                  N_ENT_RESPREC := 0;
                  N_ENT_RESPFIS := 0;
                  v_rango_vlr_rec := NULL;

                ---------dbms_output.put_line ('2');

                 ---------------------------
                 -------PRIORIDAD 1  -------
                  BEGIN
                      SELECT ----- Filtro para el req 1078 16/02/2015
						CASE 
						  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
						  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
						  ELSE e.ERR_OPR_COD_ENTIDAD
						END		
                      into N_ENT_RESPREC
                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                      where e.ERR_PRIORIDAD in (1)
                      and e.ERR_NIT_IPS = ent_resp(er).NIN_SUC_PRE_CODIGO
                      ----and e.ERR_RESP_LIQ = ent_resp(er).NIN_ENTIDAD_RESP_LIQ (Se elimina criterio de acuerdo a las nuevas reglas Caso 3020211)
                      ----and e.ERR_TIPO_CTA = ent_resp(er).NIN_FIPS_PAR_CODIGO_TPC (Caso 300766 no tener en cuenta el tipo de cuenta en el campo NIN_TIPO_CUENTA)
                      and ent_resp(er).NIN_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                      and e.ERR_INI_VIGEN = dtfech_vigencia
					  and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul) ----- Filtro para el req 1078 16/02/2015
					  and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12' ; --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016

                     EXCEPTION
                        WHEN no_data_found
                        THEN
                           N_ENT_RESPREC := 0;
                        WHEN others
                        THEN null;
                  END;

                  IF N_ENT_RESPREC > 0 THEN

                    UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                      SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NIN_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                      WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                      and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                      ---and r.NIN_ENTIDAD_RESP_REC is null
                      ;

                  else
                    ---------------------------
                    -------PRIORIDAD 2  -------
                     BEGIN
                        SELECT  ----- Filtro para el req 1078 16/02/2015
							CASE 
							  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
							  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
							  ELSE e.ERR_OPR_COD_ENTIDAD
							END
                          into N_ENT_RESPREC
                          FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                          where e.ERR_PRIORIDAD in (2)
                          and e.ERR_NIT_IPS = ent_resp(er).NIN_SUC_PRE_CODIGO
                          and ent_resp(er).NIN_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                          and e.ERR_RESP_LIQ = ent_resp(er).NIN_ENTIDAD_RESP_LIQ
                          and e.ERR_INI_VIGEN = dtfech_vigencia
						  -- fILTRO AÑADIDO PARA CUMPLIR REGLA DEL REQ 1078 DE FECHA 18/02/2016 BY ERICK BONILLA
						  and ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
						  ----- Filtro para el req 1078 16/02/2015
						  and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul)
						  and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12' ; --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016;

                         EXCEPTION
                            WHEN no_data_found
                            THEN
                               N_ENT_RESPREC := 0;
                            WHEN others
                            THEN null;
                     END;

                        IF N_ENT_RESPREC > 0 THEN

                          UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                            SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NIN_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                            WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                            and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                            ----and r.NIN_ENTIDAD_RESP_REC is null
                            ;
                        else
                            ---------------------------
                            -------PRIORIDAD 3 -------
                            BEGIN
                              SELECT  ----- Filtro para el req 1078 16/02/2015
								CASE 
								  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
								  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
								  ELSE e.ERR_OPR_COD_ENTIDAD
								END
                              into N_ENT_RESPREC
                              FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                              where e.ERR_PRIORIDAD in (3)
                              and e.ERR_NIT_IPS = ent_resp(er).NIN_SUC_PRE_CODIGO
                              -----and ent_resp(er).NCE_FIPS_VALORIPS >= e.ERR_VLR_FACTURA (Se elimina criterio de acuerdo a las nuevas reglas Caso 3020211)
                              and ent_resp(er).NIN_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                              ----and ent_resp(er).NIN_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                              and ent_resp(er).NIN_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                              ----and ent_resp(er).NIN_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                              and ent_resp(er).VLR_NOPOS >= e.ERR_VLR_RECOBRO
                              and e.ERR_RESP_LIQ = ent_resp(er).NIN_ENTIDAD_RESP_LIQ
                              and e.ERR_INI_VIGEN = dtfech_vigencia
							  and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12'  --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016
							  ----- Filtro X SUCURSAL para el req 1078 16/02/2015							  
							  AND e.ERR_SUCURSAL = ent_resp(er).NIN_SUC_NUMERO
							  ----- Filtro para el req 1078 16/02/2015
						      and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                               EXCEPTION
                                  WHEN no_data_found
                                  THEN
                                     N_ENT_RESPREC := 0;
                                  WHEN others
                                  THEN null;
                            END;

                              IF N_ENT_RESPREC > 0 THEN

                                  UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                    SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NIN_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                                    WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                    and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                    and r.NIN_ENTIDAD_RESP_REC is null;
                              else
                                  ---------------------------
                                  -------PRIORIDAD 4 --------
                                  BEGIN
                                      SELECT  ----- Filtro para el req 1078 16/02/2015
										CASE 
										  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
										  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
										  ELSE e.ERR_OPR_COD_ENTIDAD
										END
                                      into N_ENT_RESPREC
                                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                      where e.ERR_PRIORIDAD in (4)
                                      and ent_resp(er).NIN_FIPS_CANT_ATEN = 1
                                      and ent_resp(er).NIN_FIPS_VALORIPS >= e.ERR_VLR_FACTURA
                                      and ent_resp(er).VLR_NOPOS >= e.ERR_VLR_RECOBRO
                                      and e.ERR_INI_VIGEN = dtfech_vigencia
									  and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12'  --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016
									  ----- Filtro para el req 1078 16/02/2015
						              and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                                    EXCEPTION
                                        WHEN no_data_found
                                        THEN
                                           N_ENT_RESPREC := 0;
                                        WHEN others
                                        THEN null;
                                  END;

                                    IF N_ENT_RESPREC > 0 THEN

                                      UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                        SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NIN_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                                        WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                        and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                        and r.NIN_ENTIDAD_RESP_REC is null;
                                    ELSE
                                        ---------------------------
                                        -------PRIORIDAD 5 -------
                                        BEGIN
                                            SELECT ---- Filtro para el req 1078 16/02/2015
												CASE 
												  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
												  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
												  ELSE e.ERR_OPR_COD_ENTIDAD
												END
                                            into N_ENT_RESPREC
                                            FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                            where e.ERR_PRIORIDAD in (5)
                                              and ent_resp(er).VLR_NOPOS <= e.ERR_VLR_RECOBRO
                                              and e.ERR_INI_VIGEN = dtfech_vigencia
											  ----- Filtro para el req 1078 16/02/2015
						                      and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul)
											  and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12' ; --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016
                                          EXCEPTION
                                              WHEN no_data_found
                                              THEN
                                                 N_ENT_RESPREC := 0;
                                              WHEN others
                                              THEN null;
                                        END;
                                          IF N_ENT_RESPREC > 0 THEN

                                            UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                              SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                              WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                              and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                              and r.NIN_ENTIDAD_RESP_REC is null;
                                          ELSE
                                              ---------------------------
                                              -------PRIORIDAD 6 --------
                                              BEGIN
                                                  SELECT ----- Filtro para el req 1078 16/02/2015
													CASE 
													  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
													  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
													  ELSE e.ERR_OPR_COD_ENTIDAD
													END
                                                  into N_ENT_RESPREC
                                                  FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                                  where e.ERR_PRIORIDAD in (6)
                                                    and e.ERR_NIT_IPS = ent_resp(er).NIN_SUC_PRE_CODIGO
                                                    and e.ERR_INI_VIGEN = dtfech_vigencia
													----- Filtro para el req 1078 16/02/2015
						                            and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul)
													and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12' ; --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016
                                                EXCEPTION
                                                    WHEN no_data_found
                                                    THEN
                                                       N_ENT_RESPREC := 0;
                                                    WHEN others
                                                    THEN null;
                                              END;

                                                IF N_ENT_RESPREC > 0 THEN

                                                  UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                                    SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                                    WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                                    and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                                    and r.NIN_ENTIDAD_RESP_REC is null;
                                                ELSE
                                                      ---------------------------
                                                      -------PRIORIDAD 7 -------
                                                      BEGIN
                                                          SELECT  ----- Filtro para el req 1078 16/02/2015
																CASE 
																  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
																  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
																  ELSE e.ERR_OPR_COD_ENTIDAD
																END
                                                          into N_ENT_RESPREC
                                                          FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                                          where e.ERR_PRIORIDAD in (7)
                                                            and ent_resp(er).VLR_NOPOS >= 15000
                                                            and ent_resp(er).VLR_NOPOS <= e.ERR_VLR_RECOBRO
                                                            and e.ERR_INI_VIGEN = dtfech_vigencia
															----- Filtro para el req 1078 16/02/2015
						                                    and to_char( ERR_OPR_COD_ENTIDAD) not in( v_comp_consul)
															and to_char( e.ERR_OPR_COD_ENTIDAD) <> '12' ; --se esta excluyendo la regla del "MENOR VALOR" en el proc. de Identif NoPos REQ 1078 16/02/2016
                                                        EXCEPTION
                                                            WHEN no_data_found
                                                            THEN
                                                               N_ENT_RESPREC := 0;
                                                            WHEN others
                                                            THEN null;
                                                      END;
                                                      IF N_ENT_RESPREC > 0 THEN
              
                                                          UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                                            SET r.NIN_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                                            WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                                            and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                                            and r.NIN_ENTIDAD_RESP_REC is null;
                                                      ELSE
                                                          UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                                                            SET r.NIN_ENTIDAD_RESP_REC = 0
                                                            WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                                                            and r.NIN_CTAFIL_CONSATEN = ent_resp(er).NIN_CTAFIL_CONSATEN
                                                            and r.NIN_ENTIDAD_RESP_REC is null;
                                                      end if;      
                                                END IF ;
                                          END IF ;
                                    END IF ;
                              END IF ;
                        END IF ;
                  END IF ;

                -----------MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DEL FISICO DE LA CUENTA------------

                BEGIN

                      SELECT e.ERR_OPR_COD_ENTIDAD
                      into N_ENT_RESPFIS
                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                      where e.ERR_PRIORIDAD in (3)
                      and e.ERR_NIT_IPS = ent_resp(er).NIN_SUC_PRE_CODIGO
                      and ent_resp(er).NIN_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                      ---and ent_resp(er).NIN_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                      and ent_resp(er).NIN_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                      ---and ent_resp(er).NIN_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                      and e.ERR_RESP_LIQ = ent_resp(er).NIN_ENTIDAD_RESP_LIQ
                      and e.ERR_INI_VIGEN = dtfech_vigencia
                      -------and ent_resp(er).VLR_NOPOS >= e.ERR_VLR_RECOBRO /*Alcance del dia 07/03/2012, para el responsable del fisico no se tiene en cuenta el valor PRIORIDAD = 2*/
                      ;
                       EXCEPTION
                          WHEN no_data_found
                          THEN
                             N_ENT_RESPFIS := 0;
                          WHEN others
                          THEN
                             null;
                END;

                     IF N_ENT_RESPFIS > 0 THEN

                            UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                              SET r.NIN_ENTIDAD_RESP_FISICO = N_ENT_RESPFIS
                              WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                              and r.NIN_ENTIDAD_RESP_FISICO is null;
                     END IF ;


                 IF ent_resp(er).NIN_ENTIDAD_RESP_LIQ in ('IQ', 'EPS') OR ent_resp(er).NIN_USU_RESP_LIQ like '%USR_NVA_EPS%' then

                     UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                      SET r.NIN_ENTIDAD_RESP_FISICO = 8
                      WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                      AND r.NIN_ENTIDAD_RESP_FISICO  is null;

                 elsif ent_resp(er).NIN_ENTIDAD_RESP_LIQ = 'UNIDAD OPERATIVA' then

                     UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                      SET r.NIN_ENTIDAD_RESP_FISICO = 10
                      WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                      AND r.NIN_ENTIDAD_RESP_FISICO  is null;
                 else
                     UPDATE recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                      SET r.NIN_ENTIDAD_RESP_FISICO = 0
                      WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA
                      AND r.NIN_ENTIDAD_RESP_FISICO  is null;
                 END IF ;
                 --------------------------------------------------------------------------------------------------------------------------
                    -------------------MARCAR RANGO VALOR RECOBRO---------------------
                    begin
                        ------dbms_output.put_line ('2');
                        update recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                        set r.NIN_RANGO_VLR_NOPOS = FN_RANGO_VLR_INF_REC(ent_resp(er).VLR_NOPOS)
                        WHERE r.NIN_FIPS_NRORADICA = ent_resp(er).NIN_FIPS_NRORADICA;

                    EXCEPTION
                        WHEN OTHERS THEN
                            v_rango_vlr_rec := NULL;
                    end;


                 END LOOP;
                 COMMIT;
            END LOOP;
              close ent_resp_rec;
         END;
       END;

       -----------------------------IDENTIFICAR NOTA INTERNA----------------------------------------
       DECLARE
           ------tipos
           TYPE t_NI_NUMERO IS TABLE OF nota_interna.NI_NUMERO%TYPE;
           TYPE t_NI_RAD_CTAS IS TABLE OF nota_interna.NI_RAD_CTAS%TYPE;
           TYPE t_CG_VLR_SOPORTADO IS TABLE OF CONCILIA_GLOSA_PROCED.CG_VLR_SOPORTADO%TYPE;
           TYPE t_CG_VALOR_SOPORTADO_A IS TABLE OF concilia_glosa_atencion.CG_VALOR_SOPORTADO%TYPE;
           TYPE t_FIPS_FECHARADICA IS TABLE OF factxips.FIPS_FECHARADICA%TYPE;

           ------variables
           id_row                 DBMS_SQL.urowid_table;
           NI_NUMERO              t_NI_NUMERO;
           NI_RAD_CTAS            t_NI_RAD_CTAS;
           CG_VLR_SOPORTADO       t_CG_VLR_SOPORTADO;
           CG_VALOR_SOPORTADO_A   t_CG_VALOR_SOPORTADO_A;
           NI_FECHARADICA         t_FIPS_FECHARADICA;

           CURSOR nopos_auto
           IS
               select ni.NI_NUMERO, ni.NI_RAD_CTAS, sum(nvl(cgp.CG_VLR_SOPORTADO,0)) CG_VLR_SOPORTADO, fn.FIPS_FECHARADICA, r.ROWID idrow
                from recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r, concilia_glosa_orden cgo, concilia_glosa_factura cgf,
                     concilia_glosa_proced cgp,  nota_interna ni, factxips fn
                where cgf.cg_nro_rad = r.NIN_FIPS_NRORADICA
                and r.NIN_NUMERO_NI is null
                and cgo.cg_rad_concilia = cgf.cg_rad_concilia
                AND cgf.cg_nota_internaf = ni.ni_numero
                AND ni.ni_estado <> ('ANULADA')
                AND cgf.cg_estado_glosa <> 'ANULADA'
                AND cgo.cg_estado_concilia <> 'ANULADA'
                and cgf.cg_rad_concilia = cgp.CG_RAD_CONCILIA
                and cgp.CG_NRO_RAD = r.NIN_FIPS_NRORADICA
                and cgp.CG_CONSEC = r.NIN_CTAFIL_CONSATEN
                and cgp.CG_COD_PROC = r.NIN_PCT_MAP_MAPIISS
                and cgp.CG_VLR_SOPORTADO > 0
                and fn.fips_nroradica = ni.NI_RAD_CTAS
                and fn.FIPS_PAR_CODIGO_ESTADO <> ('ANUL')
                GROUP BY ni.NI_NUMERO, ni.NI_RAD_CTAS, fn.FIPS_FECHARADICA, r.ROWID;

           CURSOR nopos_ni
           IS
               select ni.NI_NUMERO, ni.NI_RAD_CTAS, sum(nvl(cgp.CG_VLR_SOPORTADO,0)) CG_VLR_SOPORTADO , fn.FIPS_FECHARADICA, r.ROWID idrow
                from  recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r, concilia_glosa_orden cgo, concilia_glosa_factura cgf,
                     concilia_glosa_proced cgp,  nota_interna ni, factxips fn
                where r.NIN_NUMERO_NI is null
                and cgf.cg_nro_rad = r.NIN_FIPS_NRORADICA
                and cgo.cg_rad_concilia = cgf.cg_rad_concilia
                AND cgo.cg_nota_interna = ni.ni_numero
                and ni.ni_estado NOT IN ('ANULADA')
                AND cgf.cg_estado_glosa <> 'ANULADA'
                AND cgo.cg_estado_concilia <> 'ANULADA'
                and cgf.cg_rad_concilia = cgp.CG_RAD_CONCILIA
                and cgp.CG_NRO_RAD = r.NIN_FIPS_NRORADICA
                and cgp.CG_CONSEC = r.NIN_CTAFIL_CONSATEN
                and cgp.CG_COD_PROC = r.NIN_PCT_MAP_MAPIISS
                and cgp.CG_VLR_SOPORTADO > 0
                and fn.fips_nroradica = ni.NI_RAD_CTAS
                and fn.FIPS_PAR_CODIGO_ESTADO NOT in ('ANUL')
                group by ni.NI_NUMERO, ni.NI_RAD_CTAS, fn.FIPS_FECHARADICA, r.ROWID;

        BEGIN
           OPEN nopos_auto;

           LOOP
              FETCH nopos_auto
              BULK COLLECT INTO NI_NUMERO, NI_RAD_CTAS, CG_VLR_SOPORTADO, NI_FECHARADICA, id_row LIMIT 5000;

              FORALL i IN 1 .. id_row.COUNT
                 UPDATE /*+ append nologging*/recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                    SET r.NIN_NUMERO_NI = NI_NUMERO(i),
                        r.NIN_FIPS_NRORADICA_NI = NI_RAD_CTAS(i),
                        r.NIN_VLR_SOPORTADO_NI = CG_VLR_SOPORTADO(i),
                        r.NIN_FIPS_FECHARADICA_NI = NI_FECHARADICA(i)
                  WHERE r.ROWID = id_row (i);
              COMMIT;
              EXIT WHEN nopos_auto%NOTFOUND;
           END LOOP;

           CLOSE nopos_auto;

           -----------------------------

           OPEN nopos_ni;

           LOOP
              FETCH nopos_ni
              BULK COLLECT INTO NI_NUMERO, NI_RAD_CTAS, CG_VALOR_SOPORTADO_A, NI_FECHARADICA, id_row LIMIT 5000;

              FORALL i IN 1 .. id_row.COUNT
                 UPDATE /*+ append nologging*/recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                    SET r.NIN_NUMERO_NI = NI_NUMERO(i),
                        r.NIN_FIPS_NRORADICA_NI = NI_RAD_CTAS(i),
                        r.NIN_VLR_SOPORTADO_NI = CG_VALOR_SOPORTADO_A(i),
                        r.NIN_FIPS_FECHARADICA_NI = NI_FECHARADICA(i)
                  WHERE r.ROWID = id_row (i);
              COMMIT;
              EXIT WHEN nopos_ni%NOTFOUND;
           END LOOP;

           CLOSE nopos_ni;
       END;
      ----------IDENTIFICAR EL ID DEL ITEM NOPOS CUANDO SE GESTIONO EN EL PROCESO DE CUENTAS MEDICAS EN EST CON NOVEDAD DE RECOBRO----------

       BEGIN
          DECLARE
             ------tipos
             TYPE t_NCE_ID IS TABLE OF NEPS_IDENTIFNOPOS_DAILY_HIST.NIN_NCE_ID%TYPE;

             NCE_ID       t_NCE_ID;
             id_row       DBMS_SQL.urowid_table;

             CURSOR busq_id IS
               SELECT max(c.NCE_ID), i.ROWID idrow
                FROM recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST i, recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO c
                where i.NIN_FIPS_NRORADICA = c.NCE_FIPS_NRORADICA
                and i.NIN_CTAFIL_CONSATEN = c.NCE_CTAFIL_CONSATEN
                and i.NIN_PCT_MAP_MAPIISS = c.NCE_PCT_MAP_MAPIISS
                and i.NIN_NCE_ID is null
                group by i.ROWID;

          BEGIN
             OPEN busq_id;
             LOOP
                FETCH busq_id
                BULK COLLECT INTO NCE_ID, id_row LIMIT 5000;

                FORALL i IN 1 .. id_row.COUNT
                   UPDATE /*+ append nologging*/ recobrosfam.NEPS_IDENTIFNOPOS_DAILY_HIST r
                      SET r.NIN_NCE_ID = NCE_ID(i)
                    WHERE r.ROWID = id_row (i);
                COMMIT;
                EXIT WHEN busq_id%NOTFOUND;
             END LOOP;

             CLOSE busq_id;

          END;
       END;
       ----------------------------------------------------------------------------------------------------------------------
EXCEPTION
   WHEN OTHERS THEN
   v_errorcode := SQLCODE;
   v_errortext := substr(SQLERRM(v_errorcode), 1, 200);
   vcerror := dbms_utility.format_error_backtrace || '.' || substr(v_errortext, 1, 250);
   ----vcerror := substr('Error: ' || ' ' || SQLERRM,0,3980);
   INSERT INTO objetos_error VALUES ('PRC_IDENTIFNOPOS_DIA_HIST_2', USER, v_errorcode, vcerror);
   COMMIT;


END ;
/