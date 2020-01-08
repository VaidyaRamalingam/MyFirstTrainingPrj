/********************************************************************************/
/*FILENAME = Intg_POShortclose_XML_Gen_Inb_FN.SQL								*/
/********************************************************************************/
/* PROCEDURE      Intg_POShortclose_XML_Gen_Inb_FN																			*/
/* DESCRIPTION																																					*/
/********************************************************************************/
/* PROJECT        Ramco Integration																													*/
/* VERSION        1.0																																				*/
/********************************************************************************/
/* REFERENCED																																					*/
/* TABLES																																								*/
/********************************************************************************/
/* DEVELOPMENT HISTORY																																*/
/********************************************************************************/
/* AUTHOR		  Chitra R																																	*/
/* DATE           6 sep 2019																																	*/
/* DESC																																									*/
/********************************************************************************/
ALTER FUNCTION DBO.Intg_POShortclose_XML_Gen_Inb_FN
(
@CtxtOuinstance_In			[udd_ctxt_ouinstance] ,
@MessageId_In					[udd_guid]
)			
RETURNS XMl
AS
BEGIN

		DECLARE @V_XmlText						XML
		DECLARE @V_CtxtOuinstance		udd_ctxt_ouinstance
		DECLARE @V_CtxtUser					udd_ctxt_user
		DECLARE @V_CtxtRole					udd_ctxt_role
		DECLARE @V_CtxtLanguageId		udd_ctxt_language
		DECLARE @V_CtxtSecurityToken	udd_ctxt_ouinstance
		DECLARE @V_CtxtIsTesting			udd_ctxt_ouinstance
		DECLARE @V_Dateformatint			udd_format
		DECLARE @V_RequestId					udd_datetime1
		DECLARE @V_Modeflag					udd_modeflag
		DECLARE	@V_InterfaceID			udd_interfaceid
		DECLARE @V_Fromdate					UDD_DATETIME1        
		DECLARE @V_Todate						UDD_DATETIME1
		
		SELECT @V_CtxtOuinstance			=	@CtxtOuinstance_In	

		SELECT @V_InterfaceID					=	'INT-PO-2'
		
		SELECT @V_CtxtUser						=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'Username',NULL)
		
		SELECT @V_CtxtRole						=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'RoleName',NULL)

		SELECT @V_CtxtLanguageId			=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'LanguageId',NULL)

		SELECT @V_CtxtSecurityToken		=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'SecurityToken',NULL)

		SELECT @V_CtxtIsTesting				=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'isTesting',NULL)

		SELECT @V_Dateformatint				=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'Dtformatint',NULL)

		SELECT @V_Modeflag						=	DBO.Int_Get_Parameter_Value(@V_CtxtOuinstance,	@V_InterfaceID,'Modeflag',NULL)
		
		SELECT @V_RequestId					=	CONVERT(varchar,GETDATE(),112)

		SELECT @V_Fromdate		=  '1900-01-01T00:00:00.000'    
  
		SELECT @V_Todate			= '9999-01-01T00:00:00.000'    
	
	IF EXISTS(SELECT 'X' FROM DBO.Intg_POShortclose_Hdr WITH(NOLOCK) WHERE MsgId	=  @MessageId_In)
	BEGIN
	;WITH XMLNAMESPACES (   'http://baspo.purchaseorderinfo.ramcoservices.com/1' as ns,
							'http://baspo.purchaseorderinfo.ramcoservices.com/1/dc' as dc,
							'http://baspo.purchaseorderinfo.ramcoservices.com/1/sc' as sc) 	

	SELECT @V_XmlText = (SELECT(SELECT (SELECT	@V_CtxtUser			"sc:User",
												@V_CtxtOuinstance										"sc:OrganizationalUnit",
												@V_CtxtRole														"sc:Role",
												@V_CtxtLanguageId										"sc:LanguageID",
			 									@V_CtxtSecurityToken									"sc:SecurityToken",
												@V_RequestId													"sc:RequestID",
												@V_CtxtIsTesting												"sc:isTesting"
					FOR XML PATH ('dc:ServiceContext') , TYPE),					
					( SELECT DISTINCT
						''									"dc:Buyergroupfilter" ,
						''									"dc:Createdby1" ,
					   	''									"dc:Designparamcode02" ,
					   ''									"dc:Designparamcode03" ,
					   ''									"dc:Designparamcode04" ,
						@V_Dateformatint		"dc:Dtformatint" ,
						''									"dc:Pocategory" ,
						@V_Fromdate			"dc:Podatefrom" ,
						@V_Todate				"dc:Podateto" ,
						''									"dc:Ponofilter" ,
						''									"dc:Pouserstatusfilter" ,
						 ''									"dc:Srcmpnmfrpartno1",
						 ''									"dc:Vendorcodefilter"
		FOR  XML PATH ('dc:Po_sclpo_ser_sub_Sseg_In'), TYPE),
		(SELECT ( SELECT DISTINCT	
					''														"dc:Designparamcode10" , 
					@V_Modeflag								"dc:Modeflag" ,
					POAmendNo									"dc:Poamendmentno" ,
					PODate											"dc:Podate",
					PONumber										"dc:Ponomlt",
					''														"dc:Postatusmlt",
					''														"dc:Pouserstatusmlt",
					POReason										"dc:Reason",
					''														"dc:Suppliercode",
					POTimestamp								"dc:Timestampint",
					''														"dc:Vendname"
		FROM	DBO.Intg_POShortclose_Hdr HDR WITH(NOLOCK)
		WHERE	HDR.MsgId			=  @MessageId_In
		AND		HDR.Validpoflag = 'Y'
		AND		HDR.RecProcessStatus  =	'P'	
		FOR  XML PATH ('dc:Po_sclpo_ser_sub__mlt_mseg_In'), TYPE)
		FOR  XML PATH ('dc:Po_sclpo_ser_sub__mlt_mseg_Ins'), TYPE)
		FOR  XML PATH ('ns:getPo_sclpo_ser_subRequest'), TYPE)
		FOR  XML PATH ('ns:GetPo_sclpo_ser_sub'), TYPE)
	END

		IF @V_XmlText IS NULL
		BEGIN
			SELECT @V_XmlText = 'Y'
		END

			RETURN @V_XmlText

END














