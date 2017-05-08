prompt
prompt Creating package MASIVAS_PKG
prompt ============================
prompt
CREATE OR REPLACE PACKAGE ELEGGE.MASIVAS_PKG IS

PROCEDURE ELIMINA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER);

PROCEDURE PROCESA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER);

PROCEDURE INSERTA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER,
                               P_CLI_ID      IN NUMBER,
                               P_ACC_ID      IN NUMBER,
                               P_BUSQUEDA    IN VARCHAR2,
                               P_DETALLE     IN VARCHAR2,
                               P_USER        IN VARCHAR2,
                               P_TIPO        IN VARCHAR2);
                               
PROCEDURE CAMPANAS   (P_SESSION in number,
                      P_CLI_ID  IN NUMBER,
                      P_ACC_ID  IN NUMBER,
                      P_GST_SN  IN VARCHAR2,
                      P_EST_ID  IN NUMBER,
                      P_EST_SN  IN VARCHAR2,
                      P_VCL_ID  IN NUMBER,
                      P_PDT_ID  IN NUMBER,
                      P_ASI_DESDE IN NUMBER,
                      P_ASI_HASTA IN NUMBER,
                      P_FECHA_DESDE IN DATE,
                      P_FECHA_HASTA IN DATE,
                      P_IMP_DESDE IN NUMBER,
                      P_IMP_HASTA IN NUMBER,
                      P_EDO_ID  IN VARCHAR2,
                      P_USUARIO IN VARCHAR2,
                      P_GESTOR IN VARCHAR2,
                      P_SECUENCIA IN OUT NUMBER);

PROCEDURE PROCESA_CAMPANA (P_CMC_ID IN NUMBER,
                           P_USUARIO IN VARCHAR2,
                           P_GESTOR  IN VARCHAR2,
                           P_ACCION  IN VARCHAR2);
                           
END MASIVAS_PKG;
/
prompt
prompt Creating package body MASIVAS_PKG
prompt =================================
prompt
CREATE OR REPLACE PACKAGE BODY ELEGGE.MASIVAS_PKG IS

PROCEDURE ELIMINA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER) IS

BEGIN
    BEGIN
      DELETE TEM_GST_MASIVAS XGM
       WHERE XGM.XGM_SESSION = P_XGM_SESSION;
    EXCEPTION
            WHEN OTHERS THEN
                NULL;
    END;

END;

PROCEDURE PROCESA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER) IS

 CURSOR ADM IS
      SELECT XGM.XGM_ACC_ID, XGM.XGM_DETALLE, ACC_PES_ID, XGM_USUARIO, XGM_CLI_ID, PES.PES_TIPO, PES.PES_ARCHIVO
        FROM TEM_GST_MASIVAS XGM,
             PAR_ACCIONES ACC,
             PAR_ESCRITOS PES
        WHERE XGM.XGM_SESSION = P_XGM_SESSION
          AND XGM_ACC_ID = ACC.ACC_ID
          AND XGM.XGM_MARCA = 'S'
          AND ACC.ACC_PES_ID = PES.PES_ID(+)
     GROUP BY XGM.XGM_ACC_ID, XGM.XGM_DETALLE, ACC_PES_ID, XGM_USUARIO, XGM_CLI_ID, PES.PES_TIPO, PES.PES_ARCHIVO;

 CURSOR GST (P_ACC_ID IN NUMBER) IS
        SELECT XGM.XGM_PRS_ID, XGM.XGM_OBN_ID, XGM.XGM_ACC_ID, XGM.XGM_DETALLE, XGM.XGM_USUARIO, ACC.ACC_PES_ID
          FROM TEM_GST_MASIVAS XGM,
               PAR_ACCIONES ACC
         WHERE XGM.XGM_SESSION = P_XGM_SESSION
           AND XGM_ACC_ID = ACC.ACC_ID
           AND XGM.XGM_MARCA = 'S'
           AND XGM.XGM_ACC_ID = P_ACC_ID;

v_acc_id PAR_ACCIONES.ACC_ID%TYPE;
v_pes_id PAR_ESCRITOS.PES_ID%TYPE;
v_detalle GESTIONES.GST_DETALLE%TYPE;
v_gst_id GESTIONES.GST_ID%TYPE;
v_avs_id AVISOS.AVS_ID%TYPE;
v_cli_id PAR_CLIENTES.CLI_ID%TYPE;

BEGIN

    FOR X IN ADM LOOP
          v_acc_id := x.XGM_ACC_ID;
          v_pes_id := x.ACC_PES_ID;
          v_detalle := x.XGM_DETALLE;
          v_cli_id  := X.XGM_CLI_ID;


      IF v_pes_id is not null then

         v_avs_id := ESCRITOS_PKG.ARMA_ESCRITO_CAB(X.XGM_USUARIO,
                                                   SYSDATE,
                                                   v_acc_id,
                                                   v_cli_id,
                                                   v_pes_id);
      END IF;

        FOR A IN GST (v_acc_id) LOOP

             v_gst_id := GESTIONES_PKG.INSERTA_GESTION (A.XGM_PRS_ID,
                                                        A.XGM_OBN_ID,
                                                        v_cli_id,
                                                        v_acc_id,
                                                        sysdate,
                                                        A.XGM_DETALLE,
                                                        A.XGM_USUARIO,
                                                        NULL,
                                                        NULL,
                                                        'M');

          if v_avs_id > 0 and v_pes_id is not null then
             ESCRITOS_PKG.ARMA_ESCRITO_DET(v_avs_id, v_pes_id, A.XGM_PRS_ID,A.XGM_OBN_ID, v_gst_id, 'M', NULL);
           end if;
         
           if X.PES_TIPO <> 4 then
             null;
             --ESCRITOS_PKG.ESCRITO_DOC(v_avs_id, v_pes_id, A.XGM_PRS_ID, A.XGM_OBN_ID, v_gst_id, 'M',A.XGM_DETALLE, X.PES_ARCHIVO);
           end if;
            

        END LOOP;

    END LOOP;

    COMMIT;
END;


PROCEDURE INSERTA_MASIVAS_MAN (P_XGM_SESSION IN NUMBER,
                               P_CLI_ID      IN NUMBER,
                               P_ACC_ID      IN NUMBER,
                               P_BUSQUEDA    IN VARCHAR2,
                               P_DETALLE     IN VARCHAR2,
                               P_USER        IN VARCHAR2,
                               P_TIPO        IN VARCHAR2) IS

/* 
P_TIPO: C = CODIGO DE BARRAS
        E = EXPEDIENTE
        D = DOCUMENTO
        O = OBLIGACION
*/   
                            
BEGIN

IF P_TIPO IN ('C', 'E') THEN

 IF LENGTH(P_BUSQUEDA) = 20 THEN

        BEGIN
           INSERT INTO tem_gst_masivas (XGM_SESSION,
                                        XGM_ID,
                                        XGM_OBN_ID,
                                        XGM_OBN_MONTO,
                                        XGM_OBN_NUMERO,
                                        XGM_OBN_ADICIONAL,
                                        XGM_PRS_ID,
                                        XGM_PRS_NUMERO,
                                        XGM_APELLIDO,
                                        XGM_ACC_ID,
                                        XGM_ACC_DESCRIPCION,
                                        XGM_CLI_ID,
                                        XGM_CLI_DESCRIPCION,
                                        XGM_DETALLE,
                                        XGM_USUARIO)
              (SELECT P_XGM_SESSION,
                      SEQ_XGM.NEXTVAL,
                      obn_id,
                      OBN.MONTO_ACTUAL,
                      OBN.OBN_NUMERO,
                      OBN.OBN_ADICIONAL,
                      OBN.PRS_ID,
                      OBN.DOC_NUMERO,
                      OBN.APELLIDO_NOMBRE,
                      P_ACC_ID,
                      NULL,
                      OBN.CLI_ID,
                      OBN.CLI_ABREVIATURA,
                      P_DETALLE,
                      P_USER
                 FROM vw_obn_resumen OBN
                WHERE     prs_id = TO_NUMBER (SUBSTR (P_BUSQUEDA, 1, 10))
                      AND obn_id = TO_NUMBER (SUBSTR (P_BUSQUEDA, 11, 10))
                      AND cli_id = P_CLI_ID
                      AND NOT EXISTS
                                 (SELECT 1
                                    FROM tem_gst_masivas
                                   WHERE XGM_prs_id =
                                            TO_NUMBER (SUBSTR (P_BUSQUEDA, 1, 10))
                                         AND XGM_obn_id =
                                                TO_NUMBER (
                                                   SUBSTR (P_BUSQUEDA, 11, 10))
                                         AND XGM_session = P_XGM_SESSION));
        END;
 ELSE
        BEGIN
           INSERT INTO tem_gst_masivas (XGM_SESSION,
                                        XGM_ID,
                                        XGM_OBN_ID,
                                        XGM_OBN_MONTO,
                                        XGM_OBN_NUMERO,
                                        XGM_OBN_ADICIONAL,
                                        XGM_PRS_ID,
                                        XGM_PRS_NUMERO,
                                        XGM_APELLIDO,
                                        XGM_ACC_ID,
                                        XGM_ACC_DESCRIPCION,
                                        XGM_CLI_ID,
                                        XGM_CLI_DESCRIPCION,
                                        XGM_DETALLE,
                                        XGM_USUARIO)
              (SELECT P_XGM_SESSION,
                      SEQ_XGM.NEXTVAL,
                      JUI_OBN_ID,
                      0, --OBN.MONTO_ACTUAL,
                      JUI_EXPEDIENTE, --OBN.OBN_NUMERO,
                      NULL,
                      JUI_PRS_ID,
                      NULL,
                      APELLIDO_NOMBRE,
                      P_ACC_ID,
                      NULL,
                      CLI_ID,
                      CLI_ABREVIATURA,
                      P_DETALLE,
                      P_USER
                FROM vw_juicios jui
                WHERE     JUI.JUI_EXPEDIENTE = P_BUSQUEDA
                AND NOT EXISTS
                                 (SELECT 1
                                    FROM tem_gst_masivas
                                   WHERE XGM_prs_id =
                                            TO_NUMBER (SUBSTR (P_BUSQUEDA, 1, 10))
                                         AND XGM_obn_id =
                                                TO_NUMBER (
                                                   SUBSTR (P_BUSQUEDA, 11, 10))
                                         AND XGM_session = P_XGM_SESSION));
                      
        END;

 END IF;

ELSIF P_TIPO = 'D' THEN
    
        BEGIN
           INSERT INTO tem_gst_masivas (XGM_SESSION,
                                        XGM_ID,
                                        XGM_OBN_ID,
                                        XGM_OBN_MONTO,
                                        XGM_OBN_NUMERO,
                                        XGM_OBN_ADICIONAL,
                                        XGM_PRS_ID,
                                        XGM_PRS_NUMERO,
                                        XGM_APELLIDO,
                                        XGM_ACC_ID,
                                        XGM_ACC_DESCRIPCION,
                                        XGM_CLI_ID,
                                        XGM_CLI_DESCRIPCION,
                                        XGM_DETALLE,
                                        XGM_USUARIO)
              (SELECT P_XGM_SESSION,
                      SEQ_XGM.NEXTVAL,
                      obn_id,
                      OBN.MONTO_ACTUAL,
                      OBN.OBN_NUMERO,
                      OBN.OBN_ADICIONAL,
                      OBN.PRS_ID,
                      OBN.DOC_NUMERO,
                      OBN.APELLIDO_NOMBRE,
                      P_ACC_ID,
                      NULL,
                      OBN.CLI_ID,
                      OBN.CLI_ABREVIATURA,
                      P_DETALLE,
                      P_USER
                 FROM vw_obn_resumen OBN
                WHERE     DOC_NUMERO = TO_NUMBER (P_BUSQUEDA)
                      AND cli_id = P_CLI_ID
                      AND NOT EXISTS
                                 (SELECT 1
                                    FROM tem_gst_masivas
                                   WHERE XGM_PRS_NUMERO  = TO_NUMBER (P_BUSQUEDA)
                                     AND XGM_session = P_XGM_SESSION));
        END;

ELSE

        BEGIN
           INSERT INTO tem_gst_masivas (XGM_SESSION,
                                        XGM_ID,
                                        XGM_OBN_ID,
                                        XGM_OBN_MONTO,
                                        XGM_OBN_NUMERO,
                                        XGM_OBN_ADICIONAL,
                                        XGM_PRS_ID,
                                        XGM_PRS_NUMERO,
                                        XGM_APELLIDO,
                                        XGM_ACC_ID,
                                        XGM_ACC_DESCRIPCION,
                                        XGM_CLI_ID,
                                        XGM_CLI_DESCRIPCION,
                                        XGM_DETALLE,
                                        XGM_USUARIO)
              (SELECT P_XGM_SESSION,
                      SEQ_XGM.NEXTVAL,
                      obn_id,
                      OBN.MONTO_ACTUAL,
                      OBN.OBN_NUMERO,
                      OBN.OBN_ADICIONAL,
                      OBN.PRS_ID,
                      OBN.DOC_NUMERO,
                      OBN.APELLIDO_NOMBRE,
                      P_ACC_ID,
                      NULL,
                      OBN.CLI_ID,
                      OBN.CLI_ABREVIATURA,
                      P_DETALLE,
                      P_USER
                 FROM vw_obn_resumen OBN
                WHERE     OBN_NUMERO = P_BUSQUEDA
                      AND cli_id = P_CLI_ID
                      AND NOT EXISTS
                                 (SELECT 1
                                    FROM tem_gst_masivas
                                   WHERE XGM_OBN_NUMERO = P_BUSQUEDA
                                         AND XGM_session = P_XGM_SESSION));
        END;


END IF;

commit;


END;

PROCEDURE CAMPANAS   (P_SESSION in number,
                      P_CLI_ID  IN NUMBER,
                      P_ACC_ID  IN NUMBER,
                      P_GST_SN  IN VARCHAR2,
                      P_EST_ID  IN NUMBER,
                      P_EST_SN  IN VARCHAR2,
                      P_VCL_ID  IN NUMBER,
                      P_PDT_ID  IN NUMBER,
                      P_ASI_DESDE IN NUMBER,
                      P_ASI_HASTA IN NUMBER,
                      P_FECHA_DESDE IN DATE,
                      P_FECHA_HASTA IN DATE,
                      P_IMP_DESDE IN NUMBER,
                      P_IMP_HASTA IN NUMBER,
                      P_EDO_ID  IN VARCHAR2,
                      P_USUARIO IN VARCHAR2,
                      P_GESTOR IN VARCHAR2,
                      P_SECUENCIA IN OUT NUMBER) IS

v_secuencia number(10);
V_NADA VARCHAR2(1);
v_filtro varchar2(500);
v_cant number(10) := 0;
V_FECHA_DESDE DATE;
V_FECHA_HASTA DATE;
v_cli_desc varchar2(100);
v_acc_desc varchar2(100);
v_vcl_desc varchar2(100);
v_edo_desc varchar2(100);
v_pdt_desc varchar2(100);
v_asi_desde varchar2(12);
v_asi_hasta varchar2(12);

BEGIN                         
   
   
   begin select cli_descripcion into v_cli_desc from par_clientes where cli_id = P_CLI_ID; end;
   V_FILTRO := 'Acreedor: '||v_cli_desc;
 
   if P_GST_SN = 'S' THEN
       V_FILTRO := V_FILTRO || 'Con ';
    else
       V_FILTRO := V_FILTRO || 'Sin ';
   end if;
   
   IF P_ACC_ID IS NOT NULL THEN
      begin select acc_descripcion into v_acc_desc from par_acciones where acc_id = P_ACC_ID; end;
      V_FILTRO := V_FILTRO || 'Acción: '||v_acc_desc;
   END IF;

   IF P_FECHA_DESDE IS NOT NULL THEN
      V_FILTRO := V_FILTRO || ' - Fecha Desde: '||TO_CHAR(P_FECHA_DESDE,'DD-MM-RRRR');
      V_FECHA_DESDE := P_FECHA_DESDE;
   ELSE
      V_FECHA_DESDE := TO_DATE ('01012000','DDMMRRRR');
   END IF;
   
   IF P_FECHA_HASTA IS NOT NULL THEN
      V_FILTRO := V_FILTRO || ' - Fecha Hasta: '||TO_CHAR(P_FECHA_HASTA,'DD-MM-RRRR');
      V_FECHA_HASTA := P_FECHA_HASTA;
   ELSE
      V_FECHA_HASTA := TO_DATE ('31122050','DDMMRRRR');
   END IF;   
  
 IF P_VCL_ID IS NOT NULL THEN
      begin select vcl_descripcion into v_vcl_desc from par_vinculos where vcl_id = P_VCL_ID; end;
      V_FILTRO := V_FILTRO || ' - Vínculo: '||v_vcl_desc;
   END IF;
   
   IF P_IMP_DESDE IS NOT NULL THEN
      V_FILTRO := V_FILTRO || ' - Monto Desde: $'||round(P_IMP_DESDE,2);
   END IF;
   
   IF P_IMP_HASTA IS NOT NULL THEN
      V_FILTRO := V_FILTRO || ' - Monto Hasta: $'||round(P_IMP_HASTA,2);
   END IF;
   
   IF P_GESTOR IS NOT NULL THEN
      V_FILTRO := V_FILTRO || ' - Gestor: '||P_GESTOR;
   END IF;   

   IF P_EDO_ID IS NOT NULL THEN
      begin select edo_descripcion into v_edo_desc from par_estados where edo_id = P_EDO_ID; end;
      V_FILTRO := V_FILTRO || ' - Estado: '||v_edo_desc;
   END IF;

   IF P_PDT_ID IS NOT NULL THEN
      begin select pdt_descripcion into v_pdt_desc from par_productos where pdt_id = P_PDT_ID; end;
      V_FILTRO := V_FILTRO || ' - Producto: '||v_pdt_desc;
   END IF;

   IF P_ASI_DESDE IS NOT NULL THEN
      begin select to_char(mig_fecha,'dd/mm/rrrr') into v_asi_desde from migracion_cab where mig_id = P_ASI_DESDE; end;
      V_FILTRO := V_FILTRO || ' - Asig. Desde: '||v_asi_desde;
   END IF;
   
   IF P_ASI_HASTA IS NOT NULL THEN
      begin select to_char(mig_fecha,'dd/mm/rrrr') into v_asi_hasta from migracion_cab where mig_id = P_ASI_HASTA; end;
      V_FILTRO := V_FILTRO || ' - Asig. Hasta: '||v_asi_hasta;
   END IF;
   
   p_secuencia := nvl(p_secuencia,0);

if p_secuencia = 0 then   
   delete tem_campanas_cab
    where cac_session = P_SESSION;
   
   delete tem_campanas
    where cam_session = P_SESSION;

  if P_ACC_ID       is null and
     P_FECHA_DESDE  is null and
     P_FECHA_HASTA  is null and
     P_GESTOR       is null then
     v_nada := null;
  else
     v_nada := 'S';
  end if;

 /*                                 
   begin
        select max(cac_secuencia)
           into v_secuencia
           from tem_campanas_cab
          where cac_session = p_session;
    end;
*/
begin
        INSERT INTO TEM_CAMPANAS (CAM_SESSION, CAM_SECUENCIA, CAM_CLI_ID, 
                     CAM_OBN_ID, CAM_PRS_ID, CAM_VCL_ID, CAM_VCL_ABREVIATURA, CAM_PDT_ID, CAM_PDT_ABREVIATURA,
                     CAM_OBN_NUMERO, CAM_OBN_ADICIONAL, CAM_PRS_NUMERO, CAM_APELLIDO_NOMBRE,
                     CAM_EDO_ID, CAM_EDO_ABREVIATURA, CAM_EDO_COLOR, CAM_MONTO_ACTUAL, CAM_OBN_SEGMENTO,
                     CAM_MIG_ID, CAM_EST_ID, CAM_EST_ABREVIATURA, CAM_FEC_ASIGNACION)
                (SELECT P_SESSION,
                       0,
                       ent.ent_cli_id,
                       obn.obn_id,
                       PRS.prs_id,
                       POB.pob_vcl_id,
                       VCL.vcl_ABREVIATURA,
                       pdt.pdt_id,
                       INITCAP (PDT.pdt_ABREVIATURA),
                       obn.obn_numero,
                       null, --obn_adicional,
                       PRS.prs_NUMERO,
                       DECODE (prs.prs_nombres,
                       NULL, prs.prs_apellidos,
                       prs.prs_apellidos || ', ' || prs.prs_nombres),
                       edo.edo_id,
                       INITCAP (EDO.edo_DESCRIPCION),
                       EDO.edo_COLOR,
                       obligaciones_pkg.monto_actual (obn_id, NULL)  MONTO_ACTUAL,
                       obn_segmento,
                       mig.mig_id,
                       est.est_id,
                       EST.EST_ABREVIATURA,
                       MIG.MIG_FECHA
                  from obligaciones obn,
                       prs_obligacion pob,
                       personas prs,
                       par_vinculos vcl,
                       par_estados edo,
                       par_productos pdt,
                       par_entidades ent,
                       migracion_cab mig,
                       par_estudios est
                 where OBN.obn_id = POB.pob_obn_id
                   and POB.pob_prs_id = PRS.prs_id
                   and OBN.obn_pdt_id = PDT.pdt_id
                   and POB.pob_vcl_id = VCL.vcl_id
                   and OBN.obn_edo_id = EDO.edo_id
                   and obn.obn_mig_id = MIG.mig_id
                   and obn.obn_est_id = est.est_id
                   and edo.edo_id = decode(P_EDO_ID, null, edo.edo_id, P_EDO_ID)
                   and obn.obn_ent_id = ent.ent_id
                   and ent.ent_cli_id = P_CLI_ID 
                   AND vcl.vcl_id = NVL (P_VCL_ID, vcl.vcl_id)
                   AND OBN.obn_pdt_id = NVL (P_PDT_ID, OBN.obn_pdt_id)
                   And ((obn.obn_est_id = P_EST_ID AND P_EST_SN = 'S')
                       OR (obn.obn_est_id <> P_EST_ID AND P_EST_SN = 'N')
                       or P_EST_ID IS NULL)
                   AND obn.obn_est_id in (select eus_est_id from est_usuarios where eus_usuario = P_USUARIO)
                   and Obn.obn_mig_id BETWEEN nvl(p_asi_desde, 0) and nvl(p_asi_hasta,99999999)
                   AND obligaciones_pkg.monto_actual (obn_id, NULL) BETWEEN NVL (P_IMP_DESDE,-999999999999.99) 
                                                                        AND NVL (P_IMP_HASTA, 999999999999.99)
                   AND ((p_gst_sn ='S' and (EXISTS
                                      (SELECT 1
                                         FROM gestiones gst
                                        WHERE 1 = 1 --obn.interno = gst.int_prestamo 
                                              AND prs.prs_id = gst.gst_prs_id
                                              AND trunc(GST.gst_FECHA) BETWEEN V_FECHA_DESDE AND V_FECHA_HASTA
                                              AND GST.gst_USUARIO = NVL (P_GESTOR, GST.gst_USUARIO)
                                              AND GST.gst_acc_id = NVL (P_ACC_ID, GST.gst_acc_id)
                                              AND GST.gst_FECHA_BAJA IS NULL 
                                              and V_NADA IS NOT NULL)))
                                  or (p_gst_sn ='N' and (not EXISTS
                                      (SELECT 1
                                         FROM gestiones gst
                                        WHERE 1 = 1 --obn.interno = gst.int_prestamo 
                                              AND prs.prs_id = gst.gst_prs_id
                                              AND trunc(GST.gst_FECHA) BETWEEN V_FECHA_DESDE AND V_FECHA_HASTA
                                              AND GST.gst_USUARIO = NVL (P_GESTOR, GST.gst_USUARIO)
                                              AND GST.gst_acc_id = NVL (P_ACC_ID, GST.gst_acc_id)
                                              AND GST.gst_FECHA_BAJA IS NULL 
                                              and V_NADA IS NOT NULL)))
                                 or V_NADA is null));
                 
     v_cant := SQL%ROWCOUNT;

    if v_cant > 0 then
    begin
        insert into TEM_CAMPANAS_CAB (CAC_SESSION, CAC_SECUENCIA, CAC_FILTRO, CAC_USUARIO, CAC_CANTIDAD)
             values (p_session, p_secuencia, v_filtro, p_usuario, v_cant);
    exception
    when others then
         RAISE_APPLICATION_ERROR(-20021, 'Error Insertando TEM_CAMPANAS_CAB. - '
                                  ||SQLERRM, TRUE);
    end;
    end if;

end;

else

   select max(cac_secuencia) + 1
     into p_secuencia
     from tem_campanas_cab
    where cac_session = P_SESSION;   

begin

    INSERT INTO TEM_CAMPANAS (CAM_SESSION, CAM_SECUENCIA, CAM_CLI_ID, 
             CAM_OBN_ID, CAM_PRS_ID, CAM_VCL_ID, CAM_VCL_ABREVIATURA, CAM_PDT_ID, CAM_PDT_ABREVIATURA,
             CAM_OBN_NUMERO, CAM_OBN_ADICIONAL, CAM_PRS_NUMERO, CAM_APELLIDO_NOMBRE,
             CAM_EDO_ID, CAM_EDO_ABREVIATURA, CAM_EDO_COLOR, CAM_MONTO_ACTUAL, CAM_OBN_SEGMENTO,
             CAM_MIG_ID, CAM_EST_ID, CAM_EST_ABREVIATURA, CAM_FEC_ASIGNACION)
    (select CAM_SESSION, p_secuencia , CAM_CLI_ID, 
                 CAM_OBN_ID, CAM_PRS_ID, CAM_VCL_ID, CAM_VCL_ABREVIATURA, CAM_PDT_ID, CAM_PDT_ABREVIATURA,
                 CAM_OBN_NUMERO, CAM_OBN_ADICIONAL, CAM_PRS_NUMERO, CAM_APELLIDO_NOMBRE,
                 CAM_EDO_ID,CAM_EDO_ABREVIATURA, CAM_EDO_COLOR, CAM_MONTO_ACTUAL, CAM_OBN_SEGMENTO,
                 CAM_MIG_ID, CAM_EST_ID, CAM_EST_ABREVIATURA, CAM_FEC_ASIGNACION
      from tem_campanas
     where CAM_PDT_ID = nvl(P_PDT_ID, CAM_PDT_ID)
       and CAM_EDO_ID = decode(P_EDO_ID, null, CAM_EDO_ID, P_EDO_ID)
       and CAM_VCL_ID = nvl(P_VCL_ID, CAM_VCL_ID)
       and CAM_MONTO_ACTUAL BETWEEN NVL(P_IMP_DESDE,-999999999999.99) AND NVL(P_IMP_HASTA,999999999999.99)
       And ((CAM_EST_ID = P_EST_ID AND P_EST_SN = 'S')
            OR (CAM_EST_ID <> P_EST_ID AND P_EST_SN = 'N')
        or P_EST_ID IS NULL)
       AND CAM_EST_ID in (select EUS_EST_ID from est_usuarios where EUS_USUARIO = P_USUARIO)
       and CAM_SESSION = P_SESSION
       AND CAM_SECUENCIA = p_SECUENCIA - 1
       AND ((p_gst_sn ='S' and (EXISTS
                                      (SELECT 1
                                         FROM GESTIONES gst
                                        WHERE 1 = 1 
                                              --AND cam_obn_id = nvl(gst.INT_PRESTAMO,cam_obn_id) 
                                              AND cam_prs_id = gst.GST_PRS_ID
                                              AND trunc(GST.GST_FECHA) BETWEEN V_FECHA_DESDE AND V_FECHA_HASTA
                                              AND GST.GST_USUARIO = NVL (P_GESTOR, GST.GST_USUARIO)
                                              AND GST.GST_ACC_ID = NVL (P_ACC_ID, GST.GST_ACC_ID)
                                              AND GST.GST_CLI_ID = P_CLI_ID
                                              AND GST.GST_FECHA_BAJA IS NULL)))
                                  or (p_gst_sn ='N' and (not EXISTS
                                      (SELECT 1
                                         FROM GESTIONES gst
                                        WHERE 1 = 1 --cam_obn_id = gst.INT_PRESTAMO 
                                              --AND cam_obn_id = nvl(gst.INT_PRESTAMO,cam_obn_id)
                                              AND cam_prs_id = gst.GST_PRS_ID
                                              AND trunc(GST.GST_FECHA) BETWEEN V_FECHA_DESDE AND V_FECHA_HASTA
                                              AND GST.GST_USUARIO = NVL (P_GESTOR, GST.GST_USUARIO)
                                              AND GST.GST_ACC_ID = NVL (P_ACC_ID, GST.GST_ACC_ID)
                                              AND GST.GST_CLI_ID = P_CLI_ID
                                              AND GST.GST_FECHA_BAJA IS NULL)))));

    v_cant := SQL%ROWCOUNT;

   if v_cant > 0 then
         begin
            insert into TEM_CAMPANAS_CAB (CAC_SESSION, CAC_SECUENCIA, CAC_FILTRO, CAC_USUARIO, CAC_CANTIDAD)
                 values (p_session, p_secuencia, v_filtro, p_usuario, v_cant);
        exception
        when others then
             RAISE_APPLICATION_ERROR(-20021, 'Error Insertando TEM_CAMPANAS_CAB. - '
                                      ||SQLERRM, TRUE);
        end;
   end if;
        
end;
end if;

if v_cant > 0  then
P_SECUENCIA := P_SECUENCIA + 1;
end if;

END;
PROCEDURE PROCESA_CAMPANA (P_CMC_ID  IN NUMBER,
                           P_USUARIO IN VARCHAR2,
                           P_GESTOR  IN VARCHAR2,
                           P_ACCION  IN VARCHAR2) IS
                    
begin
IF P_ACCION = 'T' THEN
  
   BEGIN
    update CAMPANAS_CAB
       SET CMC_USUARIO = P_USUARIO,
           CMC_GESTOR  = P_GESTOR
     WHERE CMC_ID      = P_CMC_ID;
   END;

ELSE

   BEGIN
    Insert into CAMPANAS_CAB
   (CMC_ID, CMC_CLI_ID, CMC_USUARIO, CMC_GESTOR, CMC_FECHA, CMC_ESTADO, CMC_TITULO)
    (SELECT SEQ_CMC.NEXTVAL, CMC_CLI_ID, P_USUARIO, P_GESTOR, SYSDATE, 'A', 'R'||P_CMC_ID||' :'||CMC_TITULO
       FROM CAMPANAS_CAB
      WHERE CMC_ID = P_CMC_ID);
   END;

    BEGIN
    Insert into CAMPANAS_DET
       (CMD_ID, CMD_CMC_ID, CMD_OBN_ID, CMD_PRS_ID, CMD_VCL_ID, CMD_VCL_ABREVIATURA, CMD_PDT_ID, CMD_PDT_ABREVIATURA, CMD_OBN_NUMERO, CMD_PRS_NUMERO, CMD_APELLIDO_NOMBRE, CMD_EDO_ID, CMD_EDO_ABREVIATURA, CMD_EDO_COLOR, CMD_MONTO_ACTUAL, CMD_FINALIZADO, CMD_MARCA)
    (SELECT 
       SEQ_CMD.NEXTVAL, SEQ_CMC.CURRVAL, CMD_OBN_ID, CMD_PRS_ID, CMD_VCL_ID, CMD_VCL_ABREVIATURA, CMD_PDT_ID, CMD_PDT_ABREVIATURA, CMD_OBN_NUMERO, CMD_PRS_NUMERO, CMD_APELLIDO_NOMBRE, CMD_EDO_ID, CMD_EDO_ABREVIATURA, CMD_EDO_COLOR, CMD_MONTO_ACTUAL, 'N', 'N'
       FROM CAMPANAS_DET
      WHERE CMD_CMC_ID = P_CMC_ID
        AND CMD_MARCA = 'S');
    END;

    UPDATE CAMPANAS_DET
       SET CMD_MARCA  = 'N'
     WHERE CMD_CMC_ID = P_CMC_ID;

END IF;

COMMIT;

end;

END MASIVAS_PKG;
/
