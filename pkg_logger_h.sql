CREATE OR REPLACE PACKAGE pkg_logger
/***************************************************************************************************************/
/* 機能名       : Log出力コントローラー                                                                            */
/* 概要         : 引数にログの出力レベルを指定し、ログメッセージをコントロールする。                                   */
/* 備考         : ログレベルはFATAL,ERROR,WARN,INFO,DEBUG                                                         */
/*                引数の一番最後に、開始時にはS,継続時にはC,終了時にはFを指定する。                                      */
/* 作成者       : NOMOS) k_yoshida                                                                              */
/*                                                                                                             */
/* 使い方       : 作成したソースにlogger(プログラム名,実行者ID,ログレベル,メッセージ,アウトプットモードを指定するだけ)        */
/*               １、ログレベルには文字列形式でFATAL,ERROR,WARN,INFO,DEBUGを指定する。                                */
/*               ２、アウトプットモードにはS,C,Fのいずれかを指定する。S = start, C = continue, F = finishの意で、       */
/*                   SとFはそのプログラム内で必ず一回だけ呼び出さなければならない。                                      */
/*                   SとFはログ出力のための開始処理と終了処理を呼び出すためのものである。                                 */
/*                   Cは単純にログを出力するためのモードである。                                                      */
/*               ３、ログレベル、アウトプットモードの大文字・小文字どちらでも指定できる。                                  */
/***************************************************************************************************************/

IS

/******************************************************************************/
/*	【設定】                                                                   */
/*	  １、OUTPUT_OVER_THIS_LEVEL定数のレベルを変更することで、ログの出力レベルを      */
/*	     変更することが出来ます。                                                 */
/*	     デフォルトでは'0'が設定されており、全てのログが表示されます。                  */
/*	  ２、LOGFILE_OUTPUT_PATHのファイルパス上にログファイルを出力します。             */
/******************************************************************************/


	/***************************************/
	/* この定数より高いレベルのログが出力されます */
	/* 5:FATAL                             */
	/* 4:ERROR                             */
	/* 3:WARN                              */
	/* 2:INFO                              */
	/* 1:DEBUG                             */
	/***************************************/
	OUTPUT_OVER_THIS_LEVEL CONSTANT CHAR(1) := '0';

	/* 各機能ごとのログファイル出力先を設定します */
	LOGFILE_OUTPUT_PATH CONSTANT VARCHAR2(128) := '';

/** --この行以降、変更非推奨--　************************************************************************************/

	/* スタートモード呼び出しチェックカウンター */
	called_counter NUMBER := 0;

	/* 書き込みモード */
	logfile_writing_mode    CONSTANT CHAR(1)  := 'w'; /* 新規作成 */
	logfile_append_mode     CONSTANT CHAR(1)  := 'a'; /* 上書き  */
	logfile_error_mode      CONSTANT CHAR(1)  := 'e'; /* エラーの場合  */

	/* ログ表示用文字 */
	LOGOUTPUT_CHAR_SPACE    CONSTANT CHAR(2)  := ' ';
	LOGOUTPUT_CHAR_SLASH    CONSTANT CHAR(2)  := '/';
	LOGOUTPUT_CHAR_COLON    CONSTANT CHAR(8) := ' : ';
	LOGOUTPUT_CHAR_NO       CONSTANT CHAR(8) := 'No.';

	/* ユーザー定義例外 */
	setwritemode_err_logfilehundle EXCEPTION; /* logfile書き込みのエラー */

	/* エラー時のメッセージ */
	ERR_LOG_MESSAGE_WRITING  CONSTANT VARCHAR2(128) := '[ERROR] PLLOGGERで書き込み例外が発生しました。';
	SETWRITEMODE_ERR_LOGFILE CONSTANT VARCHAR2(128) := '[ERROR] LOGFILEのファイルパス検索時にエラーが発生しました。';

	/* UTL_FILE.FOPENで利用するMAX_LINESIZE */
	CON_MAX_LINESIZE CONSTANT PLS_INTEGER := 32767;

	/* 改行コード(Windowsプラットホーム CHR(13)||CHR(10), Linux系プラットホーム CHR(10)) */
	CON_RETURN_CODE	CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);


	/****************************************************************************/
	/* 概要 : 受け取った文字列形式のログレベルを数値に変換する　　　　　                   */
	/* 引数 : in_program_id,in_loglevel_char 　　   　　　　　　                    */
	/* 戻値 : 数値に変換したログレベル  　                                           */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	FUNCTION ReplaceCHARtoNum(
		in_program_id    IN VARCHAR2,    /* 処理中のプログラムID,プログラム名 */
		in_user_id       IN VARCHAR2,    /* 実行者ID、実行者名              */
		in_loglevel_char IN VARCHAR2	 /* ログの出力れべる */
	)RETURN CHAR;

	/****************************************************************************/
	/* 概要 : ログ出力に伴って、初期処理を行う　　　　　　　　　　　　                   */
	/* 引数 : in_program_id,in_output_mode　　　　　　　　　　　　　                 */
	/* 戻値 : なし                  　                                            */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	FUNCTION InitLogOutPut(
		in_program_id     IN VARCHAR2,       /* 処理中のプログラムID,プログラム名 */
		in_user_id        IN VARCHAR2       /* 実行者ID、実行者名              */
	)RETURN VARCHAR2;


	/****************************************************************************/
	/* 概要 : 指定したレベルに応じてログを出力する　　　　　　　　　　　                   */
	/* 引数 : in_program_id,in_user_id,in_loglevel,in_message,in_output_mode     */
	/* 戻値 : なし                  　                                            */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	PROCEDURE LogOutPut(
		in_program_id     IN VARCHAR2,       /* 処理中のプログラムID,プログラム名  */
		in_user_id        IN VARCHAR2,       /* 実行者ID、実行者名               */
		in_loglevel       IN VARCHAR2,       /* ログの出力レベル                 */
		in_message        IN VARCHAR2,       /* 出力したいログメッセージ          */
		in_logfile_name   IN VARCHAR2        /* ファイルハンドル名               */
	);

	/****************************************************************************/
	/* 概要 : このシステム自体のログメッセージを表示する　　　　　　　　                  */
	/* 引数 : in_program_id,in_user_id,in_message　　　　　　　　　　　　　　　　     */
	/* 戻値 : なし                  　                                            */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	PROCEDURE plLogger_logOutPut(
		in_program_id  IN VARCHAR2,  /* 処理中のプログラムID,プログラム名 */
		in_user_id     IN VARCHAR2,  /* 実行者ID、実行者名               */
		in_message     IN VARCHAR2  /* 出力したいログメッセージ          */
	);


	/****************************************************************************/
	/* 概要 : 指定したファイルパスの先にログファイルがすでに存在しているかを確認する　 */
	/* 引数 : in_logfile_path                                                    */
	/* 戻値 : 'a','w'                                                            */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	FUNCTION setLogFileWriteMode(
		in_program_id   IN VARCHAR2,     /* 処理中のプログラムID,プログラム名 */
		in_user_id      IN VARCHAR2,     /* 実行者ID、実行者名              */
		in_logfile_path IN VARCHAR2,     /* ログファイルディレクトリ         */
		in_logfile_name IN VARCHAR2      /* ログファイル名　　　　　　　　　　 */
	)RETURN CHAR;


	/****************************************************************************/
	/* 概要 : 処理を振り分けるための支配人　　　　　　　　　　　　　　　                   */
	/* 引数 : in_program_id,in_user_id,in_loglevel,in_message,in_output_mode     */
	/* 戻値 : なし                  　                                            */
	/* 備考 :                      　                                            */
	/****************************************************************************/

	PROCEDURE Logger(
		in_program_id  IN VARCHAR2,  /* 処理中のプログラムID,プログラム名 */
		in_user_id     IN VARCHAR2,  /* 実行者ID、実行者名               */
		in_loglevel    IN VARCHAR2,  /* ログの出力レベル                 */
		in_message     IN VARCHAR2  /* 出力したいログメッセージ          */
	);

END pkg_logger;
