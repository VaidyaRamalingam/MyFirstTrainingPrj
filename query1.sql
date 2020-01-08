/********************************************************************************/
/*FILENAME = Intg_POShortclose_LoadStgTbl_SP.SQL																					*/
/********************************************************************************/
/* PROCEDURE   Intg_POShortclose_LoadStgTbl_SP	   																					*/
/* DESCRIPTION																																					*/
/********************************************************************************/
/* PROJECT        Ramco integration																													*/
/* VERSION        1.0																																				*/
/********************************************************************************/
/* REFERENCED																																					*/
/* TABLES																																								*/
/********************************************************************************/
/* DEVELOPMENT HISTORY																																*/
/********************************************************************************/
/* AUTHOR : Chitra R		  																																	*/
/* DATE       : 	03-Sep-2019																																	*/
/* DESC																																									*/
/********************************************************************************/
ALTER PROCEDURE DBO.Intg_POShortclose_LoadStgTbl_SP
	@CtxtOuinstance_In 			udd_ctxt_ouinstance,
	@InterfaceId_In					udd_touchid,
	@MessageId_In					udd_guid,
	@TranID_In							udd_TransactionId,
	@Processflag_In					udd_flag
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @V_XmlData							XML
		
	/*Declare the local varaibles*/
	DECLARE	@hDoc									Udd_Int
	DECLARE	@V_RecProcessStatusP		Udd_Recstatus
	DECLARE	@V_DefaultDate					udd_datetime1
	DECLARE	@V_SourceName					udd_IntgSourceName
	DECLARE    @V_DestinationName			udd_IntgDestinationName
	DECLARE    @V_InterfaceDesc					UDD_TXT150

	SELECT	@V_DefaultDate					=  DBO.RAS_GETDATE(@CtxtOuinstance_In)
	SELECT	@V_RecProcessStatusP		=	DBO.Int_Get_Parameter_Value(@CtxtOuinstance_In,'All','RECEXISTSFLAG','INPROCESS')

	SELECT @V_InterfaceDesc				=	InterfaceDesc
	FROM DBO.Intg_Interface_Master WITH(NOLOCK)
	WHERE InterfaceId							=	@InterfaceId_In
	
	/*Assign the XML data to the local variable*/
	SELECT @V_XmlData	 = XmlData
	FROM DBO.Intg_POShortclose_Inb_InterfaceTbl WITH (NOLOCK)
	WHERE Ouinstance		= @CtxtOuinstance_In
	AND	Interfaceid			= @InterfaceId_In
	AND	MsgId					= @MessageId_In
	AND	@Processflag_In= 'New'

	SELECT	@V_SourceName				= SourceName,
					@V_DestinationName		= DestinationName
	FROM		DBO.Intg_Interface_master WITH (NOLOCK)
	WHERE	Interfaceid					= @InterfaceId_In

	EXEC sp_xml_preparedocument @hDoc OUTPUT, @V_XmlData

	BEGIN TRY	
	/*Insert header level data */
	INSERT INTO DBO.Intg_POShortclose_Hdr(
		PONumber,			RecProcessStatus,		Ouinstance,				TransactionId,		MsgId,	
		SourceName,					DestinationName,		CreatedDate,			SrcCreatedDate, Interfaceid, 
		POReason, Validpoflag
	)	
	SELECT 
		A.PONumber,			@V_RecProcessStatusP,	@CtxtOuinstance_In,		@TranID_In,			@MessageId_In,				
		@V_SourceName,				@V_DestinationName,		GETDATE(),				CONVERT(VARCHAR(23),@V_DefaultDate,121),@InterfaceId_In,
		A.POReason, 'Y'
	FROM OPENXML(@hDoc, '//CancelPurchaseorder/PurchaseorderInfo')
	WITH 
	(
		PONumber			udd_documentno		'PurchaseOrderNo',
		POReason			varchar(100)		'POReason'
	)A
	LEFT JOIN dbo.Intg_POShortclose_Hdr Hdr WITH(NOLOCK)
	ON  HDR.PONumber	= A.PONumber
	AND HDR.Ouinstance		= @CtxtOuinstance_In
	AND	HDR.MsgId			= @MessageId_In
	WHERE HDR.PONumber IS NULL

	
	-- Data Validation - Starts 
	--Error log for Invalid PO and empty Reason 
	INSERT INTO  DBO.Intg_ErrorLog
	(
			InterfaceId,		RowId,			TransactionId,		KeyValue,
			ErrorSource,		ErrorCode,		ErrorType,			CreatedDate,
			ErrorResolveby,		ErrorMsg,		Ouinstance,			MsgId
	)
	SELECT @InterfaceId_In,		Rowid,			@TranID_In,			PONumber,
			'PONumber',			'POSC001',	'BE',				GETDATE(),
			'BU',				'Invalid PO Number',@CtxtOuinstance_In,	@MessageId_In
	FROM	DBO.Intg_POShortclose_Hdr p WITH(NOLOCK)
			LEFT OUTER JOIN
			DBO.po_pohdr_po_header pohdr WITH(NOLOCK)
	ON		p.PONumber		=	pohdr.POHDR_PO_NO
	WHERE	p.MsgId			=	 @MessageId_In
	AND		p.Interfaceid	=	 @InterfaceId_In
	AND		pohdr.POHDR_PO_NO  IS NULL 

	INSERT INTO  DBO.Intg_ErrorLog
	(
			InterfaceId,		RowId,			TransactionId,		KeyValue,
			ErrorSource,		ErrorCode,		ErrorType,			CreatedDate,
			ErrorResolveby,		ErrorMsg,		Ouinstance,			MsgId
	)
	SELECT @InterfaceId_In,	 RowId,			@TranID_In,			PONumber,
			'POReason',		'POSC002',	'BE',				GETDATE(),
			'BU',			'PO Reason is Empty',@CtxtOuinstance_In,	@MessageId_In
	FROM	DBO.Intg_POShortclose_Hdr WITH (NOLOCK)
	WHERE	MsgId		= @MessageId_In
	AND		Interfaceid =  @InterfaceId_In
	AND		POReason	IS NULL

	INSERT INTO  DBO.Intg_ErrorLog
	(
			InterfaceId,		RowId,			TransactionId,		KeyValue,
			ErrorSource,		ErrorCode,		ErrorType,			CreatedDate,
			ErrorResolveby,		ErrorMsg,		Ouinstance,			MsgId
	)
	SELECT @InterfaceId_In,	 RowId,			@TranID_In,			PONumber,
			'POStatus',		'POSC003',	'BE',				GETDATE(),
			'BU',			'Given PO is already Cancelled / Short Closed in Ramco',@CtxtOuinstance_In,	@MessageId_In
	FROM	DBO.Intg_POShortclose_Hdr p WITH (NOLOCK)
			JOIN
			DBO.po_pohdr_po_header pohdr WITH(NOLOCK)
	ON		p.PONumber		=	pohdr.POHDR_PO_NO
	WHERE	MsgId			=	@MessageId_In
	AND		Interfaceid		=	@InterfaceId_In
	AND		pohdr.POHDR_PO_STATUS IN ('CA','S')

		UPDATE	p
		SET		Validpoflag		=	CASE WHEN EL.ErrorCode = 'POSC001' THEN 'N' ELSE 'Y' END,
				RecProcessStatus =	'E',
				SuccessErrorMsg	=	EL.ErrorMsg,
				ModifiedDate	=	GETDATE()
		FROM	Intg_POShortclose_Hdr p
		JOIN	DBO.Intg_ErrorLog	 el WITH(NOLOCK)
		ON		p.rowid			=	el.rowid
		AND		p.msgid			=	el.msgid
		AND		p.TransactionId	=	el.TransactionId
		WHERE	p.MsgId			=	@MessageId_In
		AND		p.Interfaceid		=	@InterfaceId_In
				
		UPDATE p
		SET		POAmendNo = POHDR_AMEND_NO,
				POTimestamp = ROUND(POHDR_TIMESTAMP,0),
				PODate = POHDR_PO_DATE
		FROM	Intg_POShortclose_Hdr p
		JOIN	po_pohdr_po_header hdr		WITH(NOLOCK)
		ON		p.PONumber		=	hdr.POHDR_PO_NO
		AND		p.Ouinstance	=	hdr.POHDR_OUINSTANCE
		WHERE	p.MsgId			=	@MessageId_In
		AND		p.Interfaceid	=	@InterfaceId_In
		AND		p.Validpoflag = 'Y'

		EXEC sp_xml_removedocument @hDoc		
		
		RETURN 0

	END TRY
	BEGIN CATCH
		INSERT INTO DBO.Intg_ErrorLog
		(
			InterfaceId,		RowId,			TransactionId,		KeyValue,
			ErrorSource,		ErrorCode,		ErrorType,			CreatedDate,
			ErrorResolveby,		ErrorMsg,		Ouinstance,			MsgId
		)
		SELECT	
			@InterfaceId_In,	-915,			@TranID_In,			@V_InterfaceDesc,
			'SP',				ERROR_NUMBER(),	'TE',				GETDATE(),
			'BU',				'UnExpected SQL Exception in SP: '+ERROR_PROCEDURE()+ ERROR_MESSAGE(),
												@CtxtOuinstance_In,	@MessageId_In
		
		EXEC sp_xml_removedocument @hDoc
		
		RETURN 1

	END CATCH	
	
	SET NOCOUNT OFF
END












