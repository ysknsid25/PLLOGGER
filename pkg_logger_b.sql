CREATE OR REPLACE PACKAGE BODY pkg_logger
/***************************************************************************************************************/
/* 機能名       : Log出力コントローラー                                                                            */
/* 概要         : 引数にログの出力レベルを指定し、ログメッセージをコントロールする。                                       */
/* 備考         : ログレベルはFATAL,ERROR,WARN,INFO,DEBUG                                                         */
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

	----------------------------------------------------------------------------
	-- PLLOGGERのログを表示する
	----------------------------------------------------------------------------

	PROCEDURE plLogger_logOutPut(
		in_program_id  IN VARCHAR2,  /* 処理中のプログラムID,プログラム名 */
		in_user_id     IN VARCHAR2,  /* 実行者ID、実行者名               */
		in_message     IN VARCHAR2  /* 出力したいログメッセージ          */
	)
    IS

        /* ログ出力システム自体のログ出力先ファイル名 */
    	PLLOGGER_LOGFILE_NAME CONSTANT VARCHAR2(32) := 'PLLOGGER_LOG.log';

        /* ログ出力システム自体のログファイル書き込みハンドラ */
	    pllogger_log_filehundle UTL_FILE.FILE_TYPE;

        /* メッセージセット */
        pl_logger_log_message VARCHAR2(32767) := '';

        /* 戻り値用変数 */
        pllogger_logfile_hundle_mode CHAR(1);

        /* エラーメッセージ */
        MESSAGE_plLogger_logOutPut CONSTANT VARCHAR2(128) := '[ERROR] PLLOGGER内部で不明なエラーが発生しました。';

    BEGIN

        /* ログファイルが存在しているか確認する */
        pllogger_logfile_hundle_mode := setLogFileWriteMode(in_program_id, in_user_id, LOGFILE_OUTPUT_PATH, PLLOGGER_LOGFILE_NAME);

        /* ログファイルの存在検索結果のチェック */
        IF pllogger_logfile_hundle_mode = logfile_error_mode THEN

            RAISE setwritemode_err_logfilehundle;

        END IF;

        /* ファイルオープン */
        pllogger_log_filehundle := UTL_FILE.FOPEN(LOGFILE_OUTPUT_PATH, PLLOGGER_LOGFILE_NAME, pllogger_logfile_hundle_mode);

        /* ログメッセージセット */
        pl_logger_log_message :=
            TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
            in_program_id                            || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
			in_user_id                               || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
	        in_message;

        /* ログ表示 */
        DBMS_OUTPUT.PUT_LINE(pl_logger_log_message);

        /* ログ書き込み */
        UTL_FILE.PUT(pllogger_log_filehundle, pl_logger_log_message || CON_RETURN_CODE);

        /* ログファイルを閉じる */
        UTL_FILE.FCLOSE_ALL;

    EXCEPTION

        WHEN setwritemode_err_logfilehundle THEN

            /* エラーメッセージセット */
            pl_logger_log_message :=
                TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_program_id                            || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_user_id                               || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                SETWRITEMODE_ERR_LOGFILE;

            /* ログ表示 */
            DBMS_OUTPUT.PUT_LINE(pl_logger_log_message);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;


        WHEN OTHERS THEN

            /* エラーメッセージセット */
            pl_logger_log_message :=
                TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_program_id                            || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_user_id                               || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                MESSAGE_plLogger_logOutPut;

            /* ログ表示 */
            DBMS_OUTPUT.PUT_LINE(pl_logger_log_message);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

    END plLogger_logOutPut;


	----------------------------------------------------------------------------
	-- loggerが引き取ったログレベルを数値に変換する
	----------------------------------------------------------------------------
    FUNCTION ReplaceCHARtoNum(
		in_program_id    IN VARCHAR2,    /* 処理中のプログラムID,プログラム名 */
		in_user_id       IN VARCHAR2,    /* 実行者ID、実行者名             */
		in_loglevel_char IN VARCHAR2   /* 数値に変換するログレベル        */
	)
    RETURN CHAR
    IS

        /* ログの出力レベル */
        LOG_FATAL CONSTANT VARCHAR2(5) := 'FATAL';
        LOG_ERROR CONSTANT VARCHAR2(5) := 'ERROR';
        LOG_WARN  CONSTANT VARCHAR2(5) := 'WARN';
        LOG_INFO  CONSTANT VARCHAR2(5) := 'INFO';
        LOG_DEBUG CONSTANT VARCHAR2(5) := 'DEBUG';

        /* 出力レベル置換用：レベル定数 */
        LOGLEVEL_FATAL CONSTANT CHAR(1) := '5';
        LOGLEVEL_ERROR CONSTANT CHAR(1) := '4';
        LOGLEVEL_WARN  CONSTANT CHAR(1) := '3';
        LOGLEVEL_INFO  CONSTANT CHAR(1) := '2';
        LOGLEVEL_DEBUG CONSTANT CHAR(1) := '1';

        /* 変換後ログレベル格納用変数 */
        exchanged_loglevel CHAR(1) := '0';

        /* 例外メッセージ */
       MESSAGE_ReplaceCHARtoNum CONSTANT VARCHAR2(64) := '[ERROR] ログレベルを数値に変換する際に例外が発生しました。';

    BEGIN

        IF    in_loglevel_char = LOG_FATAL THEN

            exchanged_loglevel := LOGLEVEL_FATAL;

        ELSIF in_loglevel_char = LOG_ERROR THEN

            exchanged_loglevel := LOGLEVEL_ERROR;

        ELSIF in_loglevel_char = LOG_WARN  THEN

            exchanged_loglevel := LOGLEVEL_WARN;

        ELSIF in_loglevel_char = LOG_INFO  THEN

            exchanged_loglevel := LOGLEVEL_INFO;

        ELSIF  in_loglevel_char = LOG_DEBUG THEN

            exchanged_loglevel := LOGLEVEL_DEBUG;

        END IF;

        RETURN exchanged_loglevel;

    EXCEPTION

        WHEN OTHERS THEN

            plLogger_logOutPut(in_program_id, in_user_id, MESSAGE_ReplaceCHARtoNum);
            RETURN exchanged_loglevel;

    END ReplaceCHARtoNum;


	----------------------------------------------------------------------------
	-- ログファイルが既存かどうかでファイルの開き方を変える
	----------------------------------------------------------------------------

	FUNCTION setLogFileWriteMode(
		in_program_id   IN VARCHAR2,     /* 処理中のプログラムID,プログラム名 */
		in_user_id      IN VARCHAR2,     /* 実行者ID、実行者名              */
		in_logfile_path IN VARCHAR2,     /* ログファイルディレクトリ         */
		in_logfile_name IN VARCHAR2      /* ログファイル名           */
	)
    RETURN CHAR
    IS

        /* 確認用ファイルハンドル */
        for_check_log_filehandle UTL_FILE.FILE_TYPE;

        /* 戻り値用変数 */
        system_logfile_hundle_mode CHAR(1);

        /* エラーメッセージ */
        ERR_LOG_MESSAGE_FinLogOutPut CONSTANT VARCHAR2(64) := '[ERROR] ログファイルの存在チェック中にエラーが発生しました。';

    BEGIN

        /* ファイルを一度上書きモードで開けるか確認する */
        for_check_log_filehandle := UTL_FILE.FOPEN(in_logfile_path, in_logfile_name, logfile_append_mode);
        UTL_FILE.FCLOSE(for_check_log_filehandle);

        /* すでにファイルが存在していれば開けるので追加モードで処理を返す */
        system_logfile_hundle_mode := logfile_append_mode;
        RETURN system_logfile_hundle_mode;

    EXCEPTION

        WHEN UTL_FILE.INVALID_PATH THEN

            /* チェック用ハンドラのファイルを閉じる */
            UTL_FILE.FCLOSE(for_check_log_filehandle);

            /* ファイルが存在していない場合のエラーなら新規作成モードを行うように処理を返す */
            system_logfile_hundle_mode := logfile_writing_mode;
            RETURN system_logfile_hundle_mode;

        WHEN OTHERS THEN

            /* チェック用ハンドラのファイルを閉じる */
            UTL_FILE.FCLOSE(for_check_log_filehandle);

            /* その他のエラーの場合はエラー終了させる */
            system_logfile_hundle_mode := logfile_error_mode;
            RETURN system_logfile_hundle_mode;

    END setLogFileWriteMode;

	----------------------------------------------------------------------------
	-- loggerの初期処理を行う
	----------------------------------------------------------------------------

    FUNCTION InitLogOutPut(
		in_program_id     IN VARCHAR2,        /* 処理中のプログラムID,プログラム名 */
		in_user_id        IN VARCHAR2        /* 実行者ID、実行者名              */
	)RETURN VARCHAR2
    IS

        /* ファイルハンドル */
        init_logfile_hundle UTL_FILE.FILE_TYPE;

	    /* logファイル名格納 */
		LogFileName VARCHAR2(64);

		/* ログファイルの拡張子 */
		logfile_extention CONSTANT CHAR(8) := '_LOG.log';

		/* ログメッセージを格納する */
		log_message VARCHAR2(32767) := '';

		/* 書き込みモード */
		logfile_hundle_mode CHAR(1);

		/* ログメッセージ */
		LOGOUTPUT_CHAR_BORDER         CONSTANT VARCHAR2(256) := '-----------------------------------------------------------------------------------------';
        INIT_LOG_MESSAGE              CONSTANT VARCHAR2(64) := '[PLLOGGER INIT PROCESS] PLLOGGERの初期処理が完了しました。';
        LOG_KINOU_NUM                 CONSTANT VARCHAR2(16) := '機能名: ';
        LOG_USER_ID                   CONSTANT VARCHAR2(16) := 'ユーザーID: ';
        ERR_LOG_MESSAGE_InitLogOutPut CONSTANT VARCHAR2(64) := '[ERROR] ロガーの初期処理中に例外が発生しました。';

    BEGIN

        /* 機能ごとのログファイル名を作成する */
        LogFileName := in_program_id || logfile_extention;

        /* その機能のログファイルがすでに存在しているかを確認する */
        logfile_hundle_mode := setLogFileWriteMode(in_program_id, in_user_id, LOGFILE_OUTPUT_PATH, LogFileName);

        /* ログファイル存在検索の結果をチェック:検索時に異常があればエラー */
        IF logfile_hundle_mode = logfile_error_mode THEN

            RAISE setwritemode_err_logfilehundle;

        END IF;

        /* ログファイルをオープンする */
        init_logfile_hundle := UTL_FILE.FOPEN(LOGFILE_OUTPUT_PATH, LogFileName, logfile_hundle_mode, CON_MAX_LINESIZE);

        /* コンソールにログを表示する */
        DBMS_OUTPUT.PUT_LINE(LOGOUTPUT_CHAR_BORDER);
        DBMS_OUTPUT.PUT_LINE(CON_RETURN_CODE);
        DBMS_OUTPUT.PUT_LINE(INIT_LOG_MESSAGE);
        DBMS_OUTPUT.PUT_LINE(LOG_KINOU_NUM || in_program_id);
        DBMS_OUTPUT.PUT_LINE(LOG_USER_ID   || in_user_id);
        DBMS_OUTPUT.PUT_LINE(CON_RETURN_CODE);

        /* ログファイルに書き込むログを作成する */
        log_message :=
            CON_RETURN_CODE       ||
            LOGOUTPUT_CHAR_BORDER || CON_RETURN_CODE ||
            CON_RETURN_CODE       ||
            INIT_LOG_MESSAGE      || CON_RETURN_CODE ||
            LOG_KINOU_NUM         || in_program_id   || CON_RETURN_CODE ||
            LOG_USER_ID           || in_user_id      || CON_RETURN_CODE ||
            CON_RETURN_CODE;

        /* 書き込み */
        UTL_FILE.PUT_LINE(init_logfile_hundle,log_message || CON_RETURN_CODE);

        /* ログファイルを閉じる */
        UTL_FILE.FCLOSE(init_logfile_hundle);

		/* ログファイル名を返す */
		RETURN LogFileName;

    EXCEPTION

        WHEN setwritemode_err_logfilehundle THEN

            /* エラーメッセージセット */
            log_message :=
                TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_program_id                            || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                in_user_id                               || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
                SETWRITEMODE_ERR_LOGFILE;

            /* ログ表示 */
            DBMS_OUTPUT.PUT_LINE(log_message);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

			/* エラーコードを戻す */
			LogFileName := logfile_error_mode;
			RETURN LogFileName;

        WHEN UTL_FILE.WRITE_ERROR THEN

            /* 書き込みエラーログ */
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_WRITING);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

			/* エラーコードを戻す */
			LogFileName := logfile_error_mode;
			RETURN LogFileName;

        WHEN OTHERS THEN

            /* 書き込みエラーログ */
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_InitLogOutPut);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

			/* エラーコードを戻す */
			LogFileName := logfile_error_mode;
			RETURN LogFileName;

    END InitLogOutPut;


	----------------------------------------------------------------------------
	-- ログファイルにログを出力する
	----------------------------------------------------------------------------

    PROCEDURE LogOutPut(
		in_program_id     IN VARCHAR2,       /* 処理中のプログラムID,プログラム名  */
		in_user_id        IN VARCHAR2,       /* 実行者ID、実行者名               */
		in_loglevel       IN VARCHAR2,       /* ログの出力レベル                 */
		in_message        IN VARCHAR2,       /* 出力したいログメッセージ          */
		in_logfile_name   IN VARCHAR2        /* ファイルハンドル名               */
	)
    IS

        /* ログレベルをログ表示用に加工した後の文字列 */
        after_loglevel_for_output CHAR(16);

		/* ログレベルに付け加えるカッコ */
		LOGOUTPUT_LEFT_BRACKETS CONSTANT CHAR(1) := '[';
		LOGOUTPUT_RIGHT_BRACKETS  CONSTANT CHAR(1) := ']';

		/* ログメッセージを格納する */
		log_message VARCHAR2(32767) := '';

        /* ファイルハンドル */
        logoutput_hundle UTL_FILE.FILE_TYPE;

        /* エラーメッセージ */
        ERR_LOG_MESSAGE_LogOutPut CONSTANT VARCHAR2(64) := '[ERROR] PLLOGGERで内部エラーが発生しました。';

    BEGIN

        /* ログファイルをオープンする */
        logoutput_hundle := UTL_FILE.FOPEN(LOGFILE_OUTPUT_PATH, in_logfile_name, logfile_append_mode, CON_MAX_LINESIZE);

        /* Loglevelを○○の形から[○○]の形に加工する */
        after_loglevel_for_output := LOGOUTPUT_LEFT_BRACKETS || in_loglevel || LOGOUTPUT_RIGHT_BRACKETS;

        /* ログファイルに書き込むログを作成する */
        log_message :=
            TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
            in_program_id                            || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
			in_user_id                               || LOGOUTPUT_CHAR_SPACE || LOGOUTPUT_CHAR_SLASH ||
	        LOGOUTPUT_CHAR_NO || called_counter || after_loglevel_for_output || LOGOUTPUT_CHAR_COLON || in_message;

        /* ログ表示 */
        DBMS_OUTPUT.PUT_LINE(log_message);

        /* ログ書き込み */
        UTL_FILE.PUT(logoutput_hundle, log_message || CON_RETURN_CODE);

        /* ログファイルを閉じる */
        UTL_FILE.FCLOSE(logoutput_hundle);

    EXCEPTION

        WHEN UTL_FILE.WRITE_ERROR THEN

            /* 書き込みエラーログ */
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_WRITING);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

        WHEN OTHERS THEN

            /* 書き込みエラーログ */
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_LogOutPut);

            /* ログファイルを閉じる */
            UTL_FILE.FCLOSE_ALL;

    END LogOutPut;


	----------------------------------------------------------------------------
	-- ロガー。主に処理を振り分ける役割をもつ。
	----------------------------------------------------------------------------

	PROCEDURE Logger(
		in_program_id  IN VARCHAR2,  /* 処理中のプログラムID,プログラム名 */
		in_user_id     IN VARCHAR2,  /* 実行者ID、実行者名               */
		in_loglevel    IN VARCHAR2,  /* ログの出力レベル                 */
		in_message     IN VARCHAR2  /* 出力したいログメッセージ          */
	)
    IS

        /* 大文字に変換した後のログレベル */
        after_upped_loglevel CHAR(5);

        /* 文字列から数値にログレベルを変換したもの */
        after_exchanged_loglevel CHAR(1);

        /* ログレベルエラーチェック用変数 */
        ERROR_CHECK_VAR CONSTANT CHAR(1) := '0';

		/* logファイル名格納 */
		LogFileName VARCHAR2(64);

		/* システムごとのログファイル書き込ハンドラー */
		log_filehandle UTL_FILE.FILE_TYPE;

        /* ユーザー定義例外: ログレベルの変換異常 */
        err_loglevel_exchange EXCEPTION;

		/* ユーザー定義例外: 初期処理の失敗 */
        err_init_process EXCEPTION;

        /* エラーメッセージ */
        ERR_LOG_MESSAGE_Logger   CONSTANT VARCHAR2(64) := '[ERROR] LOGGERで内部エラーが発生しました。';
        ERR_LOG_MESSAGE_Loglevel CONSTANT VARCHAR2(64) := '[ERROR] LOGLEVELの変換に失敗しました。';
		ERR_LOG_MESSAGE_Init     CONSTANT VARCHAR2(64) := '[ERROR] PLLOGGERの初期処理に失敗しました。';

    BEGIN

        /* ログレベルを大文字に変換する */
        after_exchanged_loglevel := UPPER(in_loglevel);

        /* ログレベルを数値に変換する */
        after_exchanged_loglevel := ReplaceCHARtoNum(in_program_id, in_user_id, after_exchanged_loglevel);

        /* ログレベルの変換結果チェック */
        IF after_exchanged_loglevel = ERROR_CHECK_VAR THEN

            RAISE err_loglevel_exchange;

        END IF;

        /* 1回目の呼び出しの時は初期処理を行う */
        IF called_counter = 0 THEN

            LogFileName := InitLogOutPut(in_program_id, in_user_id);

			/* 初期処理の異常チェック */
			IF LogFileName = logfile_error_mode THEN

				RAISE err_init_process;

			END IF;

            called_counter := called_counter + 1;

        END IF;

        /* ログレベルに応じて処理を切り分ける */
        IF after_exchanged_loglevel > OUTPUT_OVER_THIS_LEVEL THEN

            LogOutPut(in_program_id, in_user_id, in_loglevel, in_message, LogFileName);
            called_counter := called_counter + 1;

        ELSE

            NULL;

        END IF;

    EXCEPTION

        WHEN err_loglevel_exchange THEN

            DBMS_OUTPUT.PUT_LINE(ERR_LOG_MESSAGE_Loglevel);
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_Loglevel);

		WHEN err_init_process THEN

			DBMS_OUTPUT.PUT_LINE(ERR_LOG_MESSAGE_Init);
			plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_Init);

        WHEN OTHERS THEN

            DBMS_OUTPUT.PUT_LINE(ERR_LOG_MESSAGE_Logger);
            plLogger_logOutPut(in_program_id, in_user_id, ERR_LOG_MESSAGE_Logger);

    END Logger;

END pkg_logger;
