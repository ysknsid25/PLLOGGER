CREATE OR REPLACE PACKAGE pkg_logger
/***************************************************************************************************************/
/* �@�\��       : Log�o�̓R���g���[���[                                                                            */
/* �T�v         : �����Ƀ��O�̏o�̓��x�����w�肵�A���O���b�Z�[�W���R���g���[������B                                   */
/* ���l         : ���O���x����FATAL,ERROR,WARN,INFO,DEBUG                                                         */
/*                �����̈�ԍŌ�ɁA�J�n���ɂ�S,�p�����ɂ�C,�I�����ɂ�F���w�肷��B                                      */
/* �쐬��       : NOMOS) k_yoshida                                                                              */
/*                                                                                                             */
/* �g����       : �쐬�����\�[�X��logger(�v���O������,���s��ID,���O���x��,���b�Z�[�W,�A�E�g�v�b�g���[�h���w�肷�邾��)        */
/*               �P�A���O���x���ɂ͕�����`����FATAL,ERROR,WARN,INFO,DEBUG���w�肷��B                                */
/*               �Q�A�A�E�g�v�b�g���[�h�ɂ�S,C,F�̂����ꂩ���w�肷��BS = start, C = continue, F = finish�̈ӂŁA       */
/*                   S��F�͂��̃v���O�������ŕK����񂾂��Ăяo���Ȃ���΂Ȃ�Ȃ��B                                      */
/*                   S��F�̓��O�o�͂̂��߂̊J�n�����ƏI���������Ăяo�����߂̂��̂ł���B                                 */
/*                   C�͒P���Ƀ��O���o�͂��邽�߂̃��[�h�ł���B                                                      */
/*               �R�A���O���x���A�A�E�g�v�b�g���[�h�̑啶���E�������ǂ���ł��w��ł���B                                  */
/***************************************************************************************************************/

IS

/******************************************************************************/
/*	�y�ݒ�z                                                                   */
/*	  �P�AOUTPUT_OVER_THIS_LEVEL�萔�̃��x����ύX���邱�ƂŁA���O�̏o�̓��x����      */
/*	     �ύX���邱�Ƃ��o���܂��B                                                 */
/*	     �f�t�H���g�ł�'0'���ݒ肳��Ă���A�S�Ẵ��O���\������܂��B                  */
/*	  �Q�ALOGFILE_OUTPUT_PATH�̃t�@�C���p�X��Ƀ��O�t�@�C�����o�͂��܂��B             */
/******************************************************************************/


	/***************************************/
	/* ���̒萔��荂�����x���̃��O���o�͂���܂� */
	/* 5:FATAL                             */
	/* 4:ERROR                             */
	/* 3:WARN                              */
	/* 2:INFO                              */
	/* 1:DEBUG                             */
	/***************************************/
	OUTPUT_OVER_THIS_LEVEL CONSTANT CHAR(1) := '0';

	/* �e�@�\���Ƃ̃��O�t�@�C���o�͐��ݒ肵�܂� */
	LOGFILE_OUTPUT_PATH CONSTANT VARCHAR2(128) := '';

/** --���̍s�ȍ~�A�ύX�񐄏�--�@************************************************************************************/

	/* �X�^�[�g���[�h�Ăяo���`�F�b�N�J�E���^�[ */
	called_counter NUMBER := 0;

	/* �������݃��[�h */
	logfile_writing_mode    CONSTANT CHAR(1)  := 'w'; /* �V�K�쐬 */
	logfile_append_mode     CONSTANT CHAR(1)  := 'a'; /* �㏑��  */
	logfile_error_mode      CONSTANT CHAR(1)  := 'e'; /* �G���[�̏ꍇ  */

	/* ���O�\���p���� */
	LOGOUTPUT_CHAR_SPACE    CONSTANT CHAR(2)  := ' ';
	LOGOUTPUT_CHAR_SLASH    CONSTANT CHAR(2)  := '/';
	LOGOUTPUT_CHAR_COLON    CONSTANT CHAR(8) := ' : ';
	LOGOUTPUT_CHAR_NO       CONSTANT CHAR(8) := 'No.';

	/* ���[�U�[��`��O */
	setwritemode_err_logfilehundle EXCEPTION; /* logfile�������݂̃G���[ */

	/* �G���[���̃��b�Z�[�W */
	ERR_LOG_MESSAGE_WRITING  CONSTANT VARCHAR2(128) := '[ERROR] PLLOGGER�ŏ������ݗ�O���������܂����B';
	SETWRITEMODE_ERR_LOGFILE CONSTANT VARCHAR2(128) := '[ERROR] LOGFILE�̃t�@�C���p�X�������ɃG���[���������܂����B';

	/* UTL_FILE.FOPEN�ŗ��p����MAX_LINESIZE */
	CON_MAX_LINESIZE CONSTANT PLS_INTEGER := 32767;

	/* ���s�R�[�h(Windows�v���b�g�z�[�� CHR(13)||CHR(10), Linux�n�v���b�g�z�[�� CHR(10)) */
	CON_RETURN_CODE	CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);


	/****************************************************************************/
	/* �T�v : �󂯎����������`���̃��O���x���𐔒l�ɕϊ�����@�@�@�@�@                   */
	/* ���� : in_program_id,in_loglevel_char �@�@   �@�@�@�@�@�@                    */
	/* �ߒl : ���l�ɕϊ��������O���x��  �@                                           */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	FUNCTION ReplaceCHARtoNum(
		in_program_id    IN VARCHAR2,    /* �������̃v���O����ID,�v���O������ */
		in_user_id       IN VARCHAR2,    /* ���s��ID�A���s�Җ�              */
		in_loglevel_char IN VARCHAR2	 /* ���O�̏o�͂�ׂ� */
	)RETURN CHAR;

	/****************************************************************************/
	/* �T�v : ���O�o�͂ɔ����āA�����������s���@�@�@�@�@�@�@�@�@�@�@�@                   */
	/* ���� : in_program_id,in_output_mode�@�@�@�@�@�@�@�@�@�@�@�@�@                 */
	/* �ߒl : �Ȃ�                  �@                                            */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	FUNCTION InitLogOutPut(
		in_program_id     IN VARCHAR2,       /* �������̃v���O����ID,�v���O������ */
		in_user_id        IN VARCHAR2       /* ���s��ID�A���s�Җ�              */
	)RETURN VARCHAR2;


	/****************************************************************************/
	/* �T�v : �w�肵�����x���ɉ����ă��O���o�͂���@�@�@�@�@�@�@�@�@�@�@                   */
	/* ���� : in_program_id,in_user_id,in_loglevel,in_message,in_output_mode     */
	/* �ߒl : �Ȃ�                  �@                                            */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	PROCEDURE LogOutPut(
		in_program_id     IN VARCHAR2,       /* �������̃v���O����ID,�v���O������  */
		in_user_id        IN VARCHAR2,       /* ���s��ID�A���s�Җ�               */
		in_loglevel       IN VARCHAR2,       /* ���O�̏o�̓��x��                 */
		in_message        IN VARCHAR2,       /* �o�͂��������O���b�Z�[�W          */
		in_logfile_name   IN VARCHAR2        /* �t�@�C���n���h����               */
	);

	/****************************************************************************/
	/* �T�v : ���̃V�X�e�����̂̃��O���b�Z�[�W��\������@�@�@�@�@�@�@�@                  */
	/* ���� : in_program_id,in_user_id,in_message�@�@�@�@�@�@�@�@�@�@�@�@�@�@�@�@     */
	/* �ߒl : �Ȃ�                  �@                                            */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	PROCEDURE plLogger_logOutPut(
		in_program_id  IN VARCHAR2,  /* �������̃v���O����ID,�v���O������ */
		in_user_id     IN VARCHAR2,  /* ���s��ID�A���s�Җ�               */
		in_message     IN VARCHAR2  /* �o�͂��������O���b�Z�[�W          */
	);


	/****************************************************************************/
	/* �T�v : �w�肵���t�@�C���p�X�̐�Ƀ��O�t�@�C�������łɑ��݂��Ă��邩���m�F����@ */
	/* ���� : in_logfile_path                                                    */
	/* �ߒl : 'a','w'                                                            */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	FUNCTION setLogFileWriteMode(
		in_program_id   IN VARCHAR2,     /* �������̃v���O����ID,�v���O������ */
		in_user_id      IN VARCHAR2,     /* ���s��ID�A���s�Җ�              */
		in_logfile_path IN VARCHAR2,     /* ���O�t�@�C���f�B���N�g��         */
		in_logfile_name IN VARCHAR2      /* ���O�t�@�C�����@�@�@�@�@�@�@�@�@�@ */
	)RETURN CHAR;


	/****************************************************************************/
	/* �T�v : ������U�蕪���邽�߂̎x�z�l�@�@�@�@�@�@�@�@�@�@�@�@�@�@�@                   */
	/* ���� : in_program_id,in_user_id,in_loglevel,in_message,in_output_mode     */
	/* �ߒl : �Ȃ�                  �@                                            */
	/* ���l :                      �@                                            */
	/****************************************************************************/

	PROCEDURE Logger(
		in_program_id  IN VARCHAR2,  /* �������̃v���O����ID,�v���O������ */
		in_user_id     IN VARCHAR2,  /* ���s��ID�A���s�Җ�               */
		in_loglevel    IN VARCHAR2,  /* ���O�̏o�̓��x��                 */
		in_message     IN VARCHAR2  /* �o�͂��������O���b�Z�[�W          */
	);

END pkg_logger;
