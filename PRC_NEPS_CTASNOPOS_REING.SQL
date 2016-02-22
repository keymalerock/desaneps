CREATE OR REPLACE PROCEDURE RECOBROSFAM.PRC_NEPS_CTASNOPOS_REING  AS
    /***********************************************************************************************************************************************
       APLICACIÓN: CUENTAS MEDICAS
       PARAMETROS:
       ENTRADA: Ninguna
       CASO: 3018239

       PRERREQUISITOS:
         1- Tabla vigencias actualizada (RECOBROS.MAPIISS_RECOBROS)

       HISTORIA DE LAS MODIFICACIONES
       1-)21 JUNIO 2013, Gissete Gil: Creacion procedimiento para generar la identificacion de cuentas con servicios NOPOS que hayan reingresado
       2-)02 JULIO 2013, Gissete Gil: Paso a produccion
       3-)23 SEPTIEMBRE 2013, Gissete Gil: Caso 3020211: Modificacion reglas de asignacion - Procesos No POS Diario y Preauditoria, contempla agregar campo
                                            NCE_FIPS_CANT_ATEN en la tabla recobros.NEPS_NOPOS_CTAS_ESTUDIO
       4-)febrero 17 2016, Erick Bonilla: Req 1078: Modificacion y Actualizacion de reglas de asignacion, PARA REINGRESOS
                                          ahora se vuelve asigan operador uan vez hecho el reingreso
        
    ************************************************************************************************************************************************/
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
      dt_fech_nov           DATE;
      vc_marca_reing_r      VARCHAR2(20);
      dt_fech_nov_r         DATE;
      vcerror               VARCHAR2(300);


      CURSOR rad_reing
      IS
          select distinct r.NCE_fips_nroradica --se quito el distinct y se añadio un campo mas
            from recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r, sei.novedad_cta n
          where r.NCE_fips_nroradica = n.NOV_FIPS_NRORADICA
           and n.NOV_PAR_CODIGO_ESTADO IN ('REING', 'REING_PTO')
           and r.NCE_IDENTIF_REING in (NULL,'','REINGRESO') -- Antiguo codigo 16/02/2016 and r.NCE_IDENTIF_REING = 'REINGRESO'
           and trunc(r.NCE_FECHNOV_REING) < trunc(n.NOV_FECHA_INICIO);
           
           /* this chunk of code to be comment for optimized*/
          /*union
          select distinct r.NCE_fips_nroradica
            from recobros.NEPS_NOPOS_CTAS_ESTUDIO r, sei.novedad_cta n
          where r.NCE_fips_nroradica = n.NOV_FIPS_NRORADICA
           and n.NOV_PAR_CODIGO_ESTADO IN ('REING', 'REING_PTO')
           and r.NCE_IDENTIF_REING is null
           and trunc(r.NCE_FECHA_INSERCION) < trunc(n.NOV_FECHA_INICIO);*/

      CURSOR rad_nopos_reing(n_radicado number)
      IS
          SELECT f.fips_fecharadica, f.fips_nroradica,
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
                and f.fips_nroradica = n_radicado;


      TYPE t_rad_nopos_reing IS TABLE OF rad_nopos_reing%ROWTYPE INDEX BY BINARY_INTEGER;
      nopos t_rad_nopos_reing;
      id_row   DBMS_SQL.urowid_table;

BEGIN

      delete from eps.objetos_error
      where err_objeto = 'PRC_NEPS_CTASNOPOS_REING';
      COMMIT;

      FOR xx IN rad_reing LOOP
          OPEN  rad_nopos_reing(xx.NCE_fips_nroradica);
          LOOP
             FETCH rad_nopos_reing BULK COLLECT
              INTO nopos LIMIT 500;
             EXIT WHEN rad_nopos_reing%NOTFOUND AND nopos.COUNT = 0;
             FOR er IN nopos.FIRST .. nopos.LAST LOOP

              dt_fech_nov := null;
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
              dt_fech_nov           := NULL;
              vc_marca_reing_r      := NULL;
              dt_fech_nov_r         := NULL;

              -------------Buscar datos adicionales--------------

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
                    FROM ctm_devxcta cd
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

              ---------------------------------------------------
              select trunc(MAX(NOV_FECHA_INICIO))
                into dt_fech_nov
              from sei.novedad_cta
              where nov_fips_nroradica = nopos(er).fips_nroradica and NOV_PAR_CODIGO_ESTADO IN ('REING', 'REING_PTO');

              select trunc(max(NCE_FECHNOV_REING))
                into dt_fech_nov_r
              from recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
              where NCE_FIPS_NRORADICA = nopos(er).fips_nroradica;

              IF dt_fech_nov_r is null THEN

                 update recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                 set NCE_IDENTIF_REING = 'REGISTRO ANTERIOR'
                 WHERE NCE_FIPS_NRORADICA = nopos(er).fips_nroradica
                 and NCE_IDENTIF_REING  is null;

                 INSERT INTO recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                  (NCE_ID, NCE_FIPS_FECHARADICA, NCE_FIPS_NRORADICA, NCE_FIPS_NROFACT, NCE_SUC_PRE_CODIGO, NCE_SUC_NUMERO, NCE_FIPS_PAR_CODIGO_ESTADO, NCE_FIPS_VALORIPS,
                   NCE_FIPS_VALOR_GLOSA, NCE_FIPS_PAR_CODIGO_TPC, NCE_CTAFIL_CONSATEN, NCE_AFI_TID_CODIGO, NCE_AFI_IDENTIFIC, NCE_CTAFIL_FECHA_INI, NCE_CTAFIL_FECHA_FIN,
                   NCE_CTAFIL_COPAGO_EPS, NCE_CTAFIL_CMO_EPS, NCE_CTAFIL_PAR_CODIGO_EST, NCE_CTAFIL_VALORIPS, NCE_CTAFIL_URGENCIA, NCE_PCT_MAP_MAPIISS, NCE_PCT_EDICION_MAPIISS,
                   NCE_PCT_CANTIDAD_IPS, NCE_PCT_VALORIPS, NCE_PCT_CANTIDAD_EPS, NCE_PCT_VALOREPS, NCE_PCT_VALOR_PAGAR_OP, NCE_PCT_VALOR_GLOSA_EPS, NCE_PCT_VALOR_GLOSA_IPS,
                   NCE_PCT_VALOR_GLOSA_PEND, NCE_PCT_VALOR_GLOSA_PERT, NCE_PCT_VALOR_GLOSA_TARIFA, NCE_VLR_SUCEP_RECOBRO, NCE_AFI_TIPCOTIZA, NCE_AFI_PAF_CODIGO, NCE_AFI_SEXO, NCE_AFI_APELLIDO1,
                   NCE_AFI_APELLIDO2, NCE_AFI_NOMBRES, NCE_AFI_FECHAFIL, NCE_AFI_FECHANACI, NCE_DX_CODIGO, NCE_DX_NOMBRE,
                   NCE_AXA_NUM_AUTORIZACION, NCE_TIPANEXO_AUTORIZACION, NCE_ENTIDAD_RESP_LIQ, NCE_AMBITO_SERVICIO, NCE_USU_RESP_LIQ,
                   NCE_MAPIISS_DESCRIPCION, NCE_FECHA_INSERCION, NCE_RESP_AUDITORIA, NCE_CTM_OBS, NCE_CTM_FECHA, NCE_NOV_CTA, NCE_IDENTIF_REING, NCE_FECHNOV_REING, NCE_FIPS_CANT_ATEN)
                  VALUES (SEQ_NEPS_CTASNOPOS_EST.NEXTVAL,
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
                       'REINGRESO',
                       dt_fech_nov,
                       nopos(er).FIPS_CANT_ATEN);

              ELSIF dt_fech_nov_r < dt_fech_nov THEN

                 update recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                  set NCE_IDENTIF_REING = 'REGISTRO ANTERIOR'
                 WHERE NCE_FIPS_NRORADICA = nopos(er).fips_nroradica
                 AND NCE_IDENTIF_REING = 'REINGRESO'
                 and NCE_IDENTIF_REING <> 'REGISTRO ANTERIOR';

                 INSERT INTO recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                  (NCE_ID, NCE_FIPS_FECHARADICA, NCE_FIPS_NRORADICA, NCE_FIPS_NROFACT, NCE_SUC_PRE_CODIGO, NCE_SUC_NUMERO, NCE_FIPS_PAR_CODIGO_ESTADO, NCE_FIPS_VALORIPS,
                   NCE_FIPS_VALOR_GLOSA, NCE_FIPS_PAR_CODIGO_TPC, NCE_CTAFIL_CONSATEN, NCE_AFI_TID_CODIGO, NCE_AFI_IDENTIFIC, NCE_CTAFIL_FECHA_INI, NCE_CTAFIL_FECHA_FIN,
                   NCE_CTAFIL_COPAGO_EPS, NCE_CTAFIL_CMO_EPS, NCE_CTAFIL_PAR_CODIGO_EST, NCE_CTAFIL_VALORIPS, NCE_CTAFIL_URGENCIA, NCE_PCT_MAP_MAPIISS, NCE_PCT_EDICION_MAPIISS,
                   NCE_PCT_CANTIDAD_IPS, NCE_PCT_VALORIPS, NCE_PCT_CANTIDAD_EPS, NCE_PCT_VALOREPS, NCE_PCT_VALOR_PAGAR_OP, NCE_PCT_VALOR_GLOSA_EPS, NCE_PCT_VALOR_GLOSA_IPS,
                   NCE_PCT_VALOR_GLOSA_PEND, NCE_PCT_VALOR_GLOSA_PERT, NCE_PCT_VALOR_GLOSA_TARIFA, NCE_VLR_SUCEP_RECOBRO, NCE_AFI_TIPCOTIZA, NCE_AFI_PAF_CODIGO, NCE_AFI_SEXO, NCE_AFI_APELLIDO1,
                   NCE_AFI_APELLIDO2, NCE_AFI_NOMBRES, NCE_AFI_FECHAFIL, NCE_AFI_FECHANACI, NCE_DX_CODIGO, NCE_DX_NOMBRE,
                   NCE_AXA_NUM_AUTORIZACION, NCE_TIPANEXO_AUTORIZACION, NCE_ENTIDAD_RESP_LIQ, NCE_AMBITO_SERVICIO, NCE_USU_RESP_LIQ,
                   NCE_MAPIISS_DESCRIPCION, NCE_FECHA_INSERCION, NCE_RESP_AUDITORIA, NCE_CTM_OBS, NCE_CTM_FECHA, NCE_NOV_CTA, NCE_IDENTIF_REING, NCE_FECHNOV_REING, NCE_FIPS_CANT_ATEN)
                  VALUES (SEQ_NEPS_CTASNOPOS_EST.NEXTVAL,
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
                       'REINGRESO',
                       dt_fech_nov,
                       nopos(er).FIPS_CANT_ATEN);

              ELSIF dt_fech_nov_r = dt_fech_nov THEN

                 update recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                 set NCE_IDENTIF_REING = 'REGISTRO ANTERIOR'
                 WHERE NCE_FIPS_NRORADICA = nopos(er).fips_nroradica
                 and NCE_IDENTIF_REING  is null;

                 INSERT INTO recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO
                  (NCE_ID, NCE_FIPS_FECHARADICA, NCE_FIPS_NRORADICA, NCE_FIPS_NROFACT, NCE_SUC_PRE_CODIGO, NCE_SUC_NUMERO, NCE_FIPS_PAR_CODIGO_ESTADO, NCE_FIPS_VALORIPS,
                   NCE_FIPS_VALOR_GLOSA, NCE_FIPS_PAR_CODIGO_TPC, NCE_CTAFIL_CONSATEN, NCE_AFI_TID_CODIGO, NCE_AFI_IDENTIFIC, NCE_CTAFIL_FECHA_INI, NCE_CTAFIL_FECHA_FIN,
                   NCE_CTAFIL_COPAGO_EPS, NCE_CTAFIL_CMO_EPS, NCE_CTAFIL_PAR_CODIGO_EST, NCE_CTAFIL_VALORIPS, NCE_CTAFIL_URGENCIA, NCE_PCT_MAP_MAPIISS, NCE_PCT_EDICION_MAPIISS,
                   NCE_PCT_CANTIDAD_IPS, NCE_PCT_VALORIPS, NCE_PCT_CANTIDAD_EPS, NCE_PCT_VALOREPS, NCE_PCT_VALOR_PAGAR_OP, NCE_PCT_VALOR_GLOSA_EPS, NCE_PCT_VALOR_GLOSA_IPS,
                   NCE_PCT_VALOR_GLOSA_PEND, NCE_PCT_VALOR_GLOSA_PERT, NCE_PCT_VALOR_GLOSA_TARIFA, NCE_VLR_SUCEP_RECOBRO, NCE_AFI_TIPCOTIZA, NCE_AFI_PAF_CODIGO, NCE_AFI_SEXO, NCE_AFI_APELLIDO1,
                   NCE_AFI_APELLIDO2, NCE_AFI_NOMBRES, NCE_AFI_FECHAFIL, NCE_AFI_FECHANACI, NCE_DX_CODIGO, NCE_DX_NOMBRE,
                   NCE_AXA_NUM_AUTORIZACION, NCE_TIPANEXO_AUTORIZACION, NCE_ENTIDAD_RESP_LIQ, NCE_AMBITO_SERVICIO, NCE_USU_RESP_LIQ,
                   NCE_MAPIISS_DESCRIPCION, NCE_FECHA_INSERCION, NCE_RESP_AUDITORIA, NCE_CTM_OBS, NCE_CTM_FECHA, NCE_NOV_CTA, NCE_IDENTIF_REING, NCE_FECHNOV_REING, NCE_FIPS_CANT_ATEN)
                  VALUES (SEQ_NEPS_CTASNOPOS_EST.NEXTVAL,
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
                       'REINGRESO',
                       dt_fech_nov,
                       nopos(er).FIPS_CANT_ATEN);
              END IF ;

             COMMIT;             
             END LOOP;
             /*Segun req 1078 procedimiento para asignar operadores a registros de reingreso 17/02/2016
             anteriormente si el n.NCE_ENTIDAD_RESP_FISICO= NULL se dejaba el operador que tenia anteriormente
             ahora se obliga a pasar por las reglas de asignacion de prioridades
             */
             RECOBROSFAM.REC_PRC_ASIG_OP_REC (xx.NCE_fips_nroradica);
          END LOOP;
          CLOSE  rad_nopos_reing;
      END LOOP;

      BEGIN
        DBMS_STATS.GATHER_TABLE_STATS (
          OwnName        => 'RECOBROS'
         ,TabName        => 'NEPS_NOPOS_CTAS_ESTUDIO'
         ,Cascade        => TRUE);
      END;

    ------------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------------    
 
    ------------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------------
EXCEPTION
   WHEN OTHERS THEN
   v_errorcode := SQLCODE;
   v_errortext := substr(SQLERRM(v_errorcode), 1, 200);
   vcerror := dbms_utility.format_error_backtrace || '.' || substr(v_errortext, 1, 250);
   INSERT INTO eps.objetos_error VALUES ('PRC_NEPS_CTASNOPOS_REING', USER, v_errorcode, vcerror);
   COMMIT;
END;
/