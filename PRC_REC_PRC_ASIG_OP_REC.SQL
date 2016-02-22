CREATE OR REPLACE PROCEDURE RECOBROSFAM.REC_PRC_ASIG_OP_REC (
                                                            v_nro_rad in number --PARAMETRO DE ENTRADA NUMERO DE RADICADO
                                                            )
IS
/******************************************************************************
   NAME:       REC_PRC_ASIG_OP_REC 
   PURPOSE:    este procedimiento MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DE LIQUIDAR EL RECOBRO y/o ENTIDAD RESPONSABLE DEL FISICO
               en la tabla NEPS_NOPOS_CTAS_ESTUDIO, esto es solo valido para pre auditoria, anteriormente si el n.NCE_ENTIDAD_RESP_FISICO= NULL 
               se dejaba el operador que tenia anteriormente  ahora se obliga a pasar por las reglas de asignacion de prioridades
   
   Parametros IN: numero de radicado de las cuenta identificada como de reingreso segun el campo NOV_PAR_CODIGO_ESTADO de la tabla sei.novedad_cta
   
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        16/02/2016   Erick Johan Bonilla       1. Created this procedure. REQ 1078

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     REC_PRC_ASIG_OP_REC
      Sysdate:         16/02/2016
      Date and Time:   16/02/2016, 09:36:16 a.m., and 16/02/2016 09:36:16 a.m.
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/     
       -------------------------------------------------------------------------------------------------------------------------
       -----------MARCAR LA ENTIDAD U OPERADOR RESPONSABLE DE LIQUIDAR EL RECOBRO y/o ENTIDAD RESPONSABLE DEL FISICO------------
              N_ENT_RESPREC      NUMBER;
              N_ENT_RESPFIS      NUMBER;
              dtfech_vigencia       DATE;
              v_comp_consul       VARCHAR2(500); -- variable para el complemento de la consulta req 1078

           -- eSTE CURSOR ES PARA EXTRAER UN REGISTROS SEGUN PARAMETROS DE ENTRADA CUYO STATUS SEA "ESTUDIO"
           CURSOR c_ent_resp_rec
           IS
              SELECT N.NCE_FIPS_NRORADICA, N.NCE_CTAFIL_CONSATEN, N.NCE_SUC_NUMERO, N.NCE_SUC_PRE_CODIGO, trunc(N.NCE_FIPS_FECHARADICA) NCE_FIPS_FECHARADICA, 
                     MIN(trunc(N.NCE_CTAFIL_FECHA_INI)) NCE_CTAFIL_FECHA_INI,
                     N.NCE_FIPS_VALORIPS, SUM(nvl(NCE_VLR_SUCEP_RECOBRO,0)) VLR_SUCEP, n.NCE_USU_RESP_LIQ, n.NCE_ENTIDAD_RESP_LIQ, 
                     n.NCE_FIPS_PAR_CODIGO_TPC, n.NCE_FIPS_CANT_ATEN
              FROM recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO n
              where N.NCE_FIPS_NRORADICA = v_nro_rad
              GROUP BY N.NCE_FIPS_NRORADICA, N.NCE_CTAFIL_CONSATEN,  N.NCE_SUC_NUMERO, N.NCE_SUC_PRE_CODIGO, trunc(N.NCE_FIPS_FECHARADICA), N.NCE_FIPS_VALORIPS,
              n.NCE_USU_RESP_LIQ, n.NCE_ENTIDAD_RESP_LIQ, n.NCE_FIPS_PAR_CODIGO_TPC, n.NCE_FIPS_CANT_ATEN;


        TYPE ent_resp_rec_TT IS TABLE OF c_ent_resp_rec%ROWTYPE INDEX BY BINARY_INTEGER;
        r_ent_resp ent_resp_rec_TT;       
 BEGIN         

        BEGIN
            -- BUSCA LA MAYOR FECHA DE VIGENCIA
            SELECT MAX(ERR_INI_VIGEN)
              INTO dtfech_vigencia
             FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO;


            --------dbms_output.put_line ('1');
            OPEN  c_ent_resp_rec;
            LOOP
                 FETCH c_ent_resp_rec BULK COLLECT
                  INTO r_ent_resp LIMIT 500;
                 EXIT WHEN c_ent_resp_rec%NOTFOUND AND r_ent_resp.COUNT = 0;

                 FOR er IN r_ent_resp.FIRST .. r_ent_resp.LAST LOOP

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
                      and e.ERR_NIT_IPS = r_ent_resp(er).NCE_SUC_PRE_CODIGO
                      and r_ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
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
                      WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                      and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;

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
                          FROM recobrosfam.NEPS_ENTIDAD_RESP_RECOBRO e
                          where e.ERR_PRIORIDAD in (2)
                          and e.ERR_NIT_IPS = r_ent_resp(er).NCE_SUC_PRE_CODIGO
                          and r_ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                          and e.ERR_RESP_LIQ = r_ent_resp(er).NCE_ENTIDAD_RESP_LIQ
                          -- fILTRO AÑADIDO PARA CUMPLIR REGLA DEL REQ 1078 DE FECHA 18/02/2016 BY ERICK BONILLA
                          and r_ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
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
                            WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                            and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
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
                              and e.ERR_NIT_IPS = r_ent_resp(er).NCE_SUC_PRE_CODIGO
                              -----and ent_resp(er).NCE_FIPS_VALORIPS >= e.ERR_VLR_FACTURA (Se elimina criterio de acuerdo a las nuevas reglas Caso 3020211)
                              and r_ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                              -----and ent_resp(er).NCE_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                              and r_ent_resp(er).NCE_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                              -----and ent_resp(er).NCE_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                              and r_ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO
                              and e.ERR_RESP_LIQ = r_ent_resp(er).NCE_ENTIDAD_RESP_LIQ
                              and e.ERR_INI_VIGEN = dtfech_vigencia
                              ----- Filtro para el req 1078 16/02/2015
                              AND e.ERR_SUCURSAL = r_ent_resp(er).NCE_SUC_NUMERO
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
                                    WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                    and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
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
                                      and r_ent_resp(er).NCE_FIPS_CANT_ATEN = 1
                                      and r_ent_resp(er).NCE_FIPS_VALORIPS >= e.ERR_VLR_FACTURA
                                      and r_ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO
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
                                        WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                        and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
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
                                              and r_ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
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
                                              WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                              and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
                                              
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
                                                    and e.ERR_NIT_IPS = r_ent_resp(er).NCE_SUC_PRE_CODIGO
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
                                                    WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                                    and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
                                                    
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
                                                          and r_ent_resp(er).VLR_SUCEP >= 15000
                                                          and r_ent_resp(er).VLR_SUCEP <= e.ERR_VLR_RECOBRO
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
                                                          WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                                          and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
                                                          
                                                    ELSE
                                                          UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                                                            SET r.NCE_ENTIDAD_RESP_REC = 0
                                                            WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA
                                                            and r.NCE_CTAFIL_CONSATEN = r_ent_resp(er).NCE_CTAFIL_CONSATEN;
                                                            
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
                        and e.ERR_NIT_IPS = r_ent_resp(er).NCE_SUC_PRE_CODIGO
                        and r_ent_resp(er).NCE_FIPS_FECHARADICA >= e.ERR_FECHA_INI
                        ---and ent_resp(er).NCE_CTAFIL_FECHA_INI >= e.ERR_FECHA_INI
                        and r_ent_resp(er).NCE_FIPS_FECHARADICA <= e.ERR_FECHA_FIN
                        ---and ent_resp(er).NCE_CTAFIL_FECHA_INI <= e.ERR_FECHA_FIN
                        -----and ent_resp(er).VLR_SUCEP >= e.ERR_VLR_RECOBRO para el responsable del fisico no se tiene en cuenta el valor
                        and e.ERR_RESP_LIQ = r_ent_resp(er).NCE_ENTIDAD_RESP_LIQ
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
                                WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA;
                                
                       END IF ;

                   IF r_ent_resp(er).NCE_ENTIDAD_RESP_LIQ in ('IQ', 'EPS') OR  r_ent_resp(er).NCE_USU_RESP_LIQ like '%USR_NVA_EPS%' then

                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 8
                        WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA;
                        

                   elsif r_ent_resp(er).NCE_ENTIDAD_RESP_LIQ = 'UNIDAD OPERATIVA' then

                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 10
                        WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA;
                        
                   else
                       UPDATE recobrosfam.NEPS_NOPOS_CTAS_ESTUDIO r
                        SET r.NCE_ENTIDAD_RESP_FISICO = 0
                        WHERE r.NCE_FIPS_NRORADICA = r_ent_resp(er).NCE_FIPS_NRORADICA;
                        
                   END IF ;

                 END LOOP;
              COMMIT;
            END LOOP;
            close c_ent_resp_rec;
        END;
 END;
 /