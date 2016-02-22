CREATE OR REPLACE PROCEDURE RECOBROSFAM.PRC_NEPS_CTASNOPOS_ENEST (vcerror   IN OUT   VARCHAR2)
IS
      /**********************************************************************************************************************************************************
       APLICACIÓN: CUENTAS MEDICAS
       PARAMETROS:
                  ENTRADA: Ninguna
       CASO: 3010563

       PRERREQUISITOS:
         1- Tabla vigencias actualizada (RECOBROS.MAPIISS_RECOBROS)

       HISTORIA DE LAS MODIFICACIONES
       1-)10 ENERO 2013, Gissete Gil: Creacion procedimiento para generar la identificacion de cuentas con servicios NOPOS en estado estudio y novedad de recobros
       2-)24 ENERO 2013, Gissete Gil: Actualizar el ítem de la identificación diaria NOPOS con el ID_NCE de las cuentas identificadas en estado EST y novedad
                                      de recobro, gestionadas por cuentas medicas.
       3-)04 FEBRERO 2013, Gissete Gil: Se modifica cursor principal agregando comentario a la condicion NOV_PAR_CODIGO_ESTADO = 'RECOBROS', solicitud del Ing. Oscar
                                      y definido en el comite de Recobros. Se agrega campo NCE_NOV_CTA donde se almacena 'RECOBROS' si la cuenta tiene esta novedad.
       4-)28 FEBRERO 2013, Gissete Gil: Caso 3012833: Se ajusta proceso en general según requerimiento con número de caso 3012833. Se ajusta tabla parámetros
                                        recobros.NEPS_ENTIDAD_RESP_RECOBRO para la asignación de entidades responsables, para esto se crea una vigencia en dicha tabla.
       5-)04 MARZO 2013, Gissete Gil: Caso 3013239: Se ajusta la parametrización de la Entidad Responsable de Recobro, dentro del proceso de Pre auditoria.
       6-)02 JULIO 2013, Gissete Gil: Caso 3018239: Se ajusta para llamar el procedimiento (PRC_NEPS_CTASNOPOS_REING) que valida la cuentas que han reingresado
       7-)23 SEPTIEMBRE 2013, Gissete Gil: Caso 3020211: Modificacion reglas de asignacion - Procesos No POS Diario y Preauditoria (Se genera Nueva Vigencia)
       8-)26 Febrero 2014, Gissete Gil: Caso 300766: Actualizar reglas de asignacion - Procesos No POS Diario y Preauditoria (Se genera Nueva Vigencia)
                                        Alcance: 27/02/2014 No tener en cuenta el tipo de cuenta en el campo NIN_TIPO_CUENTA para la prioridad 1
       9-)Febrero 4 2016, Erick Bonilla: Req 1073, se le agrego el cursor para buscar en el filtro si esta o no la cuenta medica en estudio
                                         en caso que no este la envia a la tabla filtro  
       10-) Febrero 16 2016, Erick Bonilla: Req 1078, se agregaron parametros de asignación
       ***********************************************************************************************************************************************************/

      vc_DX_CODIGO          VARCHAR2 (9);
      vc_DX_NOMBRE          VARCHAR2 (2000);
      vc_NUM_AUTORIZACION   VARCHAR2 (15);
      vc_TIPANEXO_AUTORIZ   VARCHAR2 (80);
      vc_ENTIDAD_RESP_LIQ   VARCHAR2 (80);
      vc_AMBITO_SERVICIO    VARCHAR2 (15);
      vc_USU_RESP_LIQ       VARCHAR2 (300);
      vc_RESP_AUDITORIA     VARCHAR2 (50);
      vc_CTM_OBS            VARCHAR2(2000);
      dt_CTM_FECHA          DATE;
      v_errorcode           INTEGER; -- codigo del error
      v_errortext           VARCHAR2(500); -- texto del error
      vc_nov_cta            VARCHAR2 (15);
      dtfech_vigencia       DATE;
      vc_NRORADICADO        INTEGER;  --variable par almacenar el numero de radicado req 1073
      vc_FOUND            BOOLEAN;   -- variable para alamcenar si encontro o no un registro  req 1073
	  v_comp_consul       VARCHAR2(500); -- variable para el complemento de la consulta req 1078

      ------- cursor para verificar si el numero de radicado existe en la tabla filtro del dia  REC_FILT_CTAS_C_FACT
      ------- devuelve 1 si lo encuentra 0 en caso contrario. Req 1073
           CURSOR CPK5_FACTXIPS(VAR_NIN_FIPS_NRORADICA NUMBER,VAR_F_PCT_CTAFIL_CONSATEN NUMBER) IS
           SELECT 1
           FROM   RECOBROSFAM.REC_FILT_CTAS_C_FACT
           WHERE  F_NIN_FIPS_NRORADICA = VAR_NIN_FIPS_NRORADICA
           and F_PCT_CTAFIL_CONSATEN = VAR_F_PCT_CTAFIL_CONSATEN
           and F_STATUS_CTAS_C_FACT <> 1;
       ------  
     ---Cursor para buscar las cuentas en estudio---
      CURSOR rad_nopos
      IS
         SELECT SEQ_NEPS_CTASNOPOS_EST.NEXTVAL NCE_ID,
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
               P.pct_valor_pagar_op,
               P.pct_valor_glosa_eps,
               P.pct_valor_glosa_ips,
               P.pct_valor_glosa_pendiente,
               P.pct_valor_glosa_pertinencia,
               P.pct_valor_glosa_tarifa,
               (nvl(P.PCT_CANTIDAD_IPS, 0) * nvl(P.pct_valorips, 0)) VLR_SUCEP,
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
          FROM sei.FACTXIPS f, sei.ctasxafil c, sei.PRO_CTA P, RECOBROSfam.MAPIISS_RECOBROS  m, eps.afiliado a
           WHERE trunc(f.fips_fecharadica) >= TO_DATE('01/01/2013', 'DD/MM/YYYY')
              and f.FIPS_PAR_CODIGO_ESTADO in ('EST')
              and f.FIPS_PAR_CODIGO_TPC not in ('NI', 'NCR', 'NDB' )
              -----and exists (select 'x' from novedad_cta where NOV_FIPS_NRORADICA = f.fips_nroradica and NOV_PAR_CODIGO_ESTADO = 'RECOBROS')
              -----and f.fips_nroradica = 13484083
              AND f.fips_nroradica = c.ctafil_fips_nroradica
              AND P.pct_ctafil_fips_nroradica = c.ctafil_fips_nroradica
              AND P.pct_ctafil_consaten = c.ctafil_consaten
              and nvl(P.PCT_CANTIDAD_IPS, 0) > 0
              and nvl(P.pct_valorips, 0) > 0
              and P.pct_map_mapiiss = m.MR_COD_MAPIISS
              and trunc(c.CTAFIL_FECHA_INI) BETWEEN m.MR_FECHA_INI and m.MR_FECHA_FIN
              AND m.MR_CODIGO_TIPOPLAN = 'PRO_NOPOS'
              and c.ctafil_afi_tid_codigo = a.afi_tid_codigo
              and c.ctafil_afi_identific = a.afi_identific
              and not exists (select 'x'
                              from recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                              where r.NCE_fips_nroradica = f.fips_nroradica
                              and r.NCE_CTAFIL_CONSATEN = c.ctafil_consaten) ;


        TYPE t_rad_nopos IS TABLE OF rad_nopos%ROWTYPE INDEX BY BINARY_INTEGER;
        nopos t_rad_nopos;
        --id_row                     DBMS_SQL.urowid_table;

BEGIN

      delete from eps.objetos_error
      where err_objeto = 'PRC_NEPS_CTASNOPOS_ENEST';
      COMMIT;

      BEGIN
        DBMS_STATS.GATHER_TABLE_STATS (
          OwnName        => 'RECOBROSfam'
         ,TabName        => 'NEPS_NOPOS_CTAS_ESTUDIO'
         ,Cascade        => TRUE);
      END;

      OPEN  rad_nopos;
      LOOP
         FETCH rad_nopos BULK COLLECT
          INTO nopos LIMIT 500;
         EXIT WHEN rad_nopos%NOTFOUND AND nopos.COUNT = 0;
         FOR er IN nopos.FIRST .. nopos.LAST LOOP

            vc_DX_CODIGO          := NULL;
            vc_DX_NOMBRE          := NULL;
            vc_NUM_AUTORIZACION   := NULL;
            vc_TIPANEXO_AUTORIZ   := NULL;
            vc_ENTIDAD_RESP_LIQ   := NULL;
            vc_AMBITO_SERVICIO    := NULL;
            vc_USU_RESP_LIQ       := NULL;
            vc_RESP_AUDITORIA     := NULL;
            vc_CTM_OBS            := NULL;
            dt_CTM_FECHA          := NULL;
            vc_nov_cta            := NULL;

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
                WHERE t.TUS_FIPS_NRORADICA = nopos(er).fips_nroradica;
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

            BEGIN
                select NOV_PAR_CODIGO_ESTADO
                into vc_nov_cta
                from sei.novedad_cta
                where NOV_FIPS_NRORADICA = nopos(er).fips_nroradica
                and NOV_PAR_CODIGO_ESTADO = 'RECOBROS'
                and rownum = 1;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  vc_nov_cta    := NULL;
            END;


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

          -------------- IDENTIFICAR OBSERVACION GLOSA CUENTA MEDICA --------------
            BEGIN
                SELECT replace( REGEXP_REPLACE (cd.CTM_OBS, '[^[:print:]]',''), ';', '') , cd.CTM_FECHA
                  into vc_CTM_OBS, dt_CTM_FECHA
                FROM sei.ctm_devxcta cd
                WHERE cd.ctm_ctafil_fips_nroradica = nopos(er).fips_nroradica
                  AND cd.ctm_ctafil_consaten = nopos(er).ctafil_consaten
                  AND cd.ctm_pct_map_mapiss = nopos(er).pct_map_mapiiss
                  and cd.ctm_motivo_devolucion in (SELECT MAX(d.ctm_motivo_devolucion)
                                                   FROM ctm_devxcta d
                                                  WHERE d.ctm_ctafil_fips_nroradica = cd.ctm_ctafil_fips_nroradica)
                  AND cd.CTM_FUENTE = 'EPS'
                  AND ROWNUM = 1;
             EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                    vc_CTM_OBS    := NULL;
                    dt_CTM_FECHA  := NULL;
            END;
            -------- busca en la tabla filtro dirario si ya existe el NROderadicado y su consecutivo si no existe lo inserta al filtro diario. req 1073
            OPEN  CPK5_FACTXIPS(nopos(er).fips_nroradica,nopos(er).ctafil_consaten );
             FETCH CPK5_FACTXIPS INTO vc_NRORADICADO;
             vc_FOUND := CPK5_FACTXIPS%FOUND;
             CLOSE CPK5_FACTXIPS;
             IF NOT vc_FOUND THEN
                INSERT INTO RECOBROSFAM.REC_FILT_CTAS_C_FACT (F_NIN_ID,F_NIN_FIPS_NRORADICA,F_STATUS_CTAS_C_FACT,F_PCT_CTAFIL_CONSATEN,F_NIN_PCT_MAP_MAPIISS  ) 
                                                         VALUES 
                                                                 (nopos(er).NCE_ID,
                                                                  nopos(er).fips_nroradica ,
                                                                  0 ,
                                                                  nopos(er).ctafil_consaten,
                                                                  nopos(er).pct_map_mapiiss
                                                                  );
                
                vc_NRORADICADO :=NULL;
             END IF;

          INSERT INTO recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
          (NCE_ID, NCE_FIPS_FECHARADICA, NCE_FIPS_NRORADICA, NCE_FIPS_NROFACT, NCE_SUC_PRE_CODIGO, NCE_SUC_NUMERO, NCE_FIPS_PAR_CODIGO_ESTADO, NCE_FIPS_VALORIPS,
           NCE_FIPS_VALOR_GLOSA, NCE_FIPS_PAR_CODIGO_TPC, NCE_CTAFIL_CONSATEN, NCE_AFI_TID_CODIGO, NCE_AFI_IDENTIFIC, NCE_CTAFIL_FECHA_INI, NCE_CTAFIL_FECHA_FIN,
           NCE_CTAFIL_COPAGO_EPS, NCE_CTAFIL_CMO_EPS, NCE_CTAFIL_PAR_CODIGO_EST, NCE_CTAFIL_VALORIPS, NCE_CTAFIL_URGENCIA, NCE_PCT_MAP_MAPIISS, NCE_PCT_EDICION_MAPIISS,
           NCE_PCT_CANTIDAD_IPS, NCE_PCT_VALORIPS, NCE_PCT_CANTIDAD_EPS, NCE_PCT_VALOREPS, NCE_PCT_VALOR_PAGAR_OP, NCE_PCT_VALOR_GLOSA_EPS, NCE_PCT_VALOR_GLOSA_IPS,
           NCE_PCT_VALOR_GLOSA_PEND, NCE_PCT_VALOR_GLOSA_PERT, NCE_PCT_VALOR_GLOSA_TARIFA, NCE_VLR_SUCEP_RECOBRO, NCE_AFI_TIPCOTIZA, NCE_AFI_PAF_CODIGO, NCE_AFI_SEXO, NCE_AFI_APELLIDO1,
           NCE_AFI_APELLIDO2, NCE_AFI_NOMBRES, NCE_AFI_FECHAFIL, NCE_AFI_FECHANACI, NCE_DX_CODIGO, NCE_DX_NOMBRE,
           NCE_AXA_NUM_AUTORIZACION, NCE_TIPANEXO_AUTORIZACION, NCE_ENTIDAD_RESP_LIQ, NCE_AMBITO_SERVICIO, NCE_USU_RESP_LIQ,
           NCE_MAPIISS_DESCRIPCION, NCE_FECHA_INSERCION, NCE_RESP_AUDITORIA, NCE_CTM_OBS, NCE_CTM_FECHA, NCE_NOV_CTA, NCE_FIPS_CANT_ATEN)
          VALUES ( nopos(er).NCE_ID,
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
               nopos(er).VLR_SUCEP,
               nopos(er).afi_tipcotiza ,
               nopos(er).afi_paf_codigo ,
               nopos(er).afi_sexo ,
               nopos(er).afi_apellido1 ,
               nopos(er).afi_apellido2 ,
               nopos(er).afi_nombres ,
               nopos(er).AFI_FECHAFIL ,
               nopos(er).AFI_FECHANACI,
               vc_DX_CODIGO, vc_DX_NOMBRE,
               vc_NUM_AUTORIZACION, vc_TIPANEXO_AUTORIZ,
               vc_ENTIDAD_RESP_LIQ,
               vc_AMBITO_SERVICIO,
               vc_USU_RESP_LIQ,
               nopos(er).MR_DESCRIPCION,
               TRUNC(sysdate),
               vc_RESP_AUDITORIA,
               vc_CTM_OBS,
               dt_CTM_FECHA,
               vc_nov_cta,
               nopos(er).FIPS_CANT_ATEN);
         COMMIT;
         END LOOP;
      END LOOP;
      close rad_nopos;

      ------------------Identificar cuentas que Reingresaron-----------------------------------
      BEGIN
          recobrosfam.PRC_NEPS_CTASNOPOS_REING;
      END;

      BEGIN
        DBMS_STATS.GATHER_TABLE_STATS (
          OwnName        => 'RECOBROSfam'
         ,TabName        => 'NEPS_NOPOS_CTAS_ESTUDIO'
         ,Cascade        => TRUE);
      END;

       -------------------------------------------------------------------------------------------------------------------------
       -----------MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DE LIQUIDAR EL RECOBRO y/o ENTIDAD RESPONSABLE DEL FISICO------------

       BEGIN
          DECLARE

              N_ENT_RESPREC      NUMBER;
              N_ENT_RESPFIS      NUMBER;


           CURSOR ent_resp_rec
           IS
              SELECT N.NCE_FIPS_NRORADICA, N.NCE_CTAFIL_CONSATEN, N.NCE_SUC_NUMERO, N.NCE_SUC_PRE_CODIGO, trunc(N.NCE_FIPS_FECHARADICA) NCE_FIPS_FECHARADICA, 
			         MIN(trunc(N.NCE_CTAFIL_FECHA_INI)) NCE_CTAFIL_FECHA_INI,
                     N.NCE_FIPS_VALORIPS, SUM(nvl(NCE_VLR_SUCEP_RECOBRO,0)) VLR_SUCEP, n.NCE_USU_RESP_LIQ, n.NCE_ENTIDAD_RESP_LIQ, 
					 n.NCE_FIPS_PAR_CODIGO_TPC, n.NCE_FIPS_CANT_ATEN
              FROM recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO n
              where n.NCE_ENTIDAD_RESP_FISICO is null
              GROUP BY N.NCE_FIPS_NRORADICA, N.NCE_CTAFIL_CONSATEN, N.NCE_SUC_NUMERO, N.NCE_SUC_PRE_CODIGO, trunc(N.NCE_FIPS_FECHARADICA), N.NCE_FIPS_VALORIPS,
			  n.NCE_USU_RESP_LIQ, n.NCE_ENTIDAD_RESP_LIQ, n.NCE_FIPS_PAR_CODIGO_TPC, n.NCE_FIPS_CANT_ATEN;


        TYPE t_ent_resp_rec IS TABLE OF ent_resp_rec%ROWTYPE INDEX BY BINARY_INTEGER;
        ent_resp t_ent_resp_rec;

        BEGIN

            SELECT MAX(ERR_INI_VIGEN)
              INTO dtfech_vigencia
             FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO;


            --------dbms_output.put_line ('1');
            OPEN  ent_resp_rec;
            LOOP
                 FETCH ent_resp_rec BULK COLLECT
                  INTO ent_resp LIMIT 500;
                 EXIT WHEN ent_resp_rec%NOTFOUND AND ent_resp.COUNT = 0;

                 FOR er IN ent_resp.FIRST .. ent_resp.LAST LOOP

                  N_ENT_RESPREC := 0;
                  N_ENT_RESPFIS := 0;

                ---------dbms_output.put_line ('2');
				----- Filtro para el req 1078 16/02/2015 Erick Bonilla
				v_comp_consul := '4,6,7,9,10,32';

                  ---------------------------
                  -------PRIORIDAD 1  -------
                  BEGIN
                      SELECT 
					    ----- Filtro para el req 1078 16/02/2015
						CASE 
						  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
						  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
						  ELSE e.ERR_OPR_COD_ENTIDAD
						END					  
                      into N_ENT_RESPREC
                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                      where e.ERR_PRIORIDAD in (1)
                      and e.ERR_NIT_IPS = ent_resp(er).NCE_SUC_PRE_CODIGO
                      ----and e.ERR_RESP_LIQ = ent_resp(er).NCE_ENTIDAD_RESP_LIQ (Se elimina criterio de acuerdo a las nuevas reglas Caso 3020211)
                      ----and e.ERR_TIPO_CTA = ent_resp(er).NCE_FIPS_PAR_CODIGO_TPC (Caso 300766 no tener en cuenta el tipo de cuenta en el campo NIN_TIPO_CUENTA)
                      and ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                      and e.ERR_INI_VIGEN = dtfech_vigencia and to_char( e.ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                     EXCEPTION
                        WHEN no_data_found
                        THEN
                           N_ENT_RESPREC := 0;
                        WHEN others
                        THEN null;
                  END;

                  IF N_ENT_RESPREC > 0 THEN

                    UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                      SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NCE_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                      WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                      and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN;

                  else
                    ---------------------------
                    -------PRIORIDAD 2  -------
                     BEGIN
                        SELECT ----- Filtro para el req 1078 16/02/2015
							CASE 
							  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
							  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
							  ELSE e.ERR_OPR_COD_ENTIDAD
							END
                          into N_ENT_RESPREC
                          FROM recobros.NEPS_ENTIDAD_RESP_RECOBRO e
                          where e.ERR_PRIORIDAD in (2)
                          and e.ERR_NIT_IPS = ent_resp(er).NCE_SUC_PRE_CODIGO
                          and ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                          and e.ERR_RESP_LIQ = ent_resp(er).NCE_ENTIDAD_RESP_LIQ
						  -- fILTRO AÑADIDO PARA CUMPLIR REGLA DEL REQ 1078 DE FECHA 18/02/2016 BY ERICK BONILLA
						  and ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
                          and e.ERR_INI_VIGEN = dtfech_vigencia
						  ----- Filtro para el req 1078 16/02/2015
						  and to_char( e.ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                         EXCEPTION
                            WHEN no_data_found
                            THEN
                               N_ENT_RESPREC := 0;
                            WHEN others
                            THEN null;
                     END;

                        IF N_ENT_RESPREC > 0 THEN

                          UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                            SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NCE_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                            WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                            and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN;
                        else
                            ---------------------------
                            -------PRIORIDAD 3 -------
							--------------------------
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
                              and e.ERR_NIT_IPS = ent_resp(er).NCE_SUC_PRE_CODIGO
                              -----and ent_resp(er).NCE_FIPS_VALORIPS >= e.ERR_VLR_FACTURA (Se elimina criterio de acuerdo a las nuevas reglas Caso 3020211)
                              and ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                              -----and ent_resp(er).NCE_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                              and ent_resp(er).NCE_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                              -----and ent_resp(er).NCE_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                              and ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO
                              and e.ERR_RESP_LIQ = ent_resp(er).NCE_ENTIDAD_RESP_LIQ
                              and e.ERR_INI_VIGEN = dtfech_vigencia
							  ----- Filtro X SUCURSAL para el req 1078 16/02/2015
							  AND e.ERR_SUCURSAL = ent_resp(er).NCE_SUC_NUMERO
							  ----- Filtro para el req 1078 16/02/2015
						      and to_char( e.ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                               EXCEPTION
                                  WHEN no_data_found
                                  THEN
                                     N_ENT_RESPREC := 0;
                                  WHEN others
                                  THEN null;
                            END;

                              IF N_ENT_RESPREC > 0 THEN

                                  UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                    SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NCE_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                                    WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                    and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN;
                              else
                                  ---------------------------
                                  -------PRIORIDAD 4 --------
                                  BEGIN
                                      SELECT ----- Filtro para el req 1078 16/02/2015
										CASE 
										  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
										  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
										  ELSE e.ERR_OPR_COD_ENTIDAD
										END
                                      into N_ENT_RESPREC
                                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                      where e.ERR_PRIORIDAD in (4)
                                      and ent_resp(er).NCE_FIPS_CANT_ATEN = 1
                                      and ent_resp(er).NCE_FIPS_VALORIPS >= e.ERR_VLR_FACTURA
                                      and ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO
                                      and e.ERR_INI_VIGEN = dtfech_vigencia
									  ----- Filtro para el req 1078 16/02/2015
						              and to_char( e.ERR_OPR_COD_ENTIDAD) not in( v_comp_consul);

                                    EXCEPTION
                                        WHEN no_data_found
                                        THEN
                                           N_ENT_RESPREC := 0;
                                        WHEN others
                                        THEN null;
                                  END;

                                    IF N_ENT_RESPREC > 0 THEN

                                      UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                        SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC, r.NCE_ENTIDAD_RESP_FISICO = N_ENT_RESPREC
                                        WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                        and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN;
                                    ELSE
                                        ---------------------------
                                        -------PRIORIDAD 5 -------
                                        BEGIN
                                            SELECT  ----- Filtro para el req 1078 16/02/2015
											CASE 
											  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
											  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
											  ELSE e.ERR_OPR_COD_ENTIDAD
											END
                                            into N_ENT_RESPREC
                                            FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                            where e.ERR_PRIORIDAD in (5)
                                              and ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
                                              and e.ERR_INI_VIGEN = dtfech_vigencia
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

                                            UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                              SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                              WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                              and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN
                                              and r.NCE_ENTIDAD_RESP_REC is null;
                                          ELSE
                                              ---------------------------
                                              -------PRIORIDAD 6 --------
                                              BEGIN
                                                  SELECT  ----- Filtro para el req 1078 16/02/2015
													CASE 
													  WHEN e.ERR_OPR_COD_ENTIDAD IN (17,18,19) THEN 33
													  WHEN e.ERR_OPR_COD_ENTIDAD IN (13,14,15,16,21,22,23,24) THEN 30
													  ELSE e.ERR_OPR_COD_ENTIDAD
													END
                                                  into N_ENT_RESPREC
                                                  FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                                                  where e.ERR_PRIORIDAD in (6)
                                                    and e.ERR_NIT_IPS = ent_resp(er).NCE_SUC_PRE_CODIGO
                                                    and e.ERR_INI_VIGEN = dtfech_vigencia
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

                                                  UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                                    SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                                    WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                                    and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN
                                                    and r.NCE_ENTIDAD_RESP_REC is null;
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
                                                          and ent_resp(er).VLR_SUCEP >= 15000
                                                          and ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
                                                          and e.ERR_INI_VIGEN = dtfech_vigencia
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
            
                                                        UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                                          SET r.NCE_ENTIDAD_RESP_REC = N_ENT_RESPREC
                                                          WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                                          and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN
                                                          and r.NCE_ENTIDAD_RESP_REC is null;
                                                    ELSE
                                                          UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                                            SET r.NCE_ENTIDAD_RESP_REC = 0
                                                            WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                                            and r.NCE_CTAFIL_CONSATEN = ent_resp(er).NCE_CTAFIL_CONSATEN
                                                            and r.NCE_ENTIDAD_RESP_REC is null;
                                                    END IF;      
                                                END IF ;
                                          END IF ;
                                    END IF ;
                              END IF ;
                        END IF ;
                  END IF ;

                  ----------MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DEL FISICO DE LA CUENTA------------
                   BEGIN

                      SELECT e.ERR_OPR_COD_ENTIDAD
                      into N_ENT_RESPFIS
                      FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                      where e.ERR_PRIORIDAD in (3)
                        and e.ERR_NIT_IPS = ent_resp(er).NCE_SUC_PRE_CODIGO
                        and ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                        ---and ent_resp(er).NCE_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                        and ent_resp(er).NCE_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                        ---and ent_resp(er).NCE_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                        -----and ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO para el responsable del fisico no se tiene en cuenta el valor
                        and e.ERR_RESP_LIQ = ent_resp(er).NCE_ENTIDAD_RESP_LIQ
                        and e.ERR_INI_VIGEN = dtfech_vigencia;

                     EXCEPTION
                        WHEN no_data_found
                        THEN
                           N_ENT_RESPFIS := 0;
                        WHEN others
                        THEN
                           null;
                    END;

                       IF N_ENT_RESPFIS > 0 THEN

                              UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                SET r.NCE_ENTIDAD_RESP_FISICO = N_ENT_RESPFIS
                                WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                                and r.NCE_ENTIDAD_RESP_FISICO is null;
                       END IF ;

                   IF ent_resp(er).NCE_ENTIDAD_RESP_LIQ in ('IQ', 'EPS') OR  ent_resp(er).NCE_USU_RESP_LIQ like '%USR_NVA_EPS%' then

                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 8
                        WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                        AND r.NCE_ENTIDAD_RESP_FISICO  is null;

                   elsif ent_resp(er).NCE_ENTIDAD_RESP_LIQ = 'UNIDAD OPERATIVA' then

                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 10
                        WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                        AND r.NCE_ENTIDAD_RESP_FISICO  is null;
                   else
                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 0
                        WHERE r.NCE_FIPS_NRORADICA = ent_resp(er).NCE_FIPS_NRORADICA
                        AND r.NCE_ENTIDAD_RESP_FISICO  is null;
                   END IF ;

                 END LOOP;
              COMMIT;
            END LOOP;
            close ent_resp_rec;
        END;
       END;


       ------------------------------------------------------------------------------------------------------------------------------------
EXCEPTION
   WHEN OTHERS THEN
   v_errorcode := SQLCODE;
   v_errortext := substr(SQLERRM(v_errorcode), 1, 200);
   vcerror := dbms_utility.format_error_backtrace || '.' || substr(v_errortext, 1, 250);
   ----vcerror := substr('Error: ' || ' ' || SQLERRM,0,3980);
   INSERT INTO eps.objetos_error VALUES ('PRC_NEPS_CTASNOPOS_ENEST', USER, v_errorcode, vcerror);
   COMMIT;


END ;
/