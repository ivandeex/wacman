<?php
// $Id$

// Language configuration. Auto or specified.

header('Content-type: text/html; charset=UTF-8', true);

function setup_language () {
    global $config;
    $language = get_config('language', 'en');

    if ($language == 'auto') {
	    // Make sure their browser correctly reports language. If not, skip this.
    	if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
	    	$langs = preg_split ('/[;,]+/', $_SERVER['HTTP_ACCEPT_LANGUAGE']);
	    	foreach ($langs as $key => $value) {
	    		$value = preg_split('/[-]+/',$value);
	    		$value = strtolower(substr($value[0],0,2));
	    		if ($value == 'q=')
	    			unset($langs[$key]);
	    		else
	    			$langs[$key] = $value;
	    	}
	    	$langs = array_unique($langs);
	    }
        // FIXME...
        $language = 'en';
    }
}

$translations = array(
	'ru' => array(
		'Domain Users'	=>	'Пользователи домена',
		'Remote Users'	=>	'Пользователи удаленного рабочего стола',
		'Name'			=>	'Имя',
		'Second name'	=>	'Фамилия',
		'Full name'		=>	'Полное имя',
		'Identifier'	=>	'Идентификатор',
		'Password'		=>	'Пароль',
		'Again password'=>	'Еще раз...',
		'Mail'			=>	'Почта',
		'User#'			=>	'Числовой ид.',
		'Group'			=>	'Группа',
		'Other groups'	=>	'Прочие группы',
		'Home directory'=>	'Домашний каталог',
		'Login shell'	=>	'Интерпретатор',
		'Drive'			=>	'Диск',
		'Profile'		=>	'Профиль',
		'Logon script'	=>	'Сценарий входа',
		'Telephone'		=>	'Телефон',
		'Fax number'	=>	'Номер факса',
		'Short number'	=>	'Короткий номер',
		'Common'		=>	'Основные',
		'Extended'		=>	'Дополнительно',
		'Manage Users'	=>	'Управление Пользователями',
		'User "%s" not found'	=>	'Не найден пользователь "%s"',
		'User "%s" not found: %s'	=>	'Пользователь "%s" не найден: %s',
		'Error reading list of Windows groups: %s'	=>	'Ошибка чтения списка Windows-групп: %s',
		'Error reading Windows group "%s" (%s): %s'	=>	'Ошибка чтения Windows-группы "%s" (%s): %s',
		'Error updating Windows-user "%s": %s'	=>	'Ошибка обновления Windows-пользователя "%s": %s',
		'Error updating mail account "%s" (%s): %s'	=>	'Ошибка обновления пользователя почты "%s" (%s): %s',
		'Error re-updating Unix-user "%s" (%s): %s'	=>	'Ошибка пере-обновления Unix-пользьвателя "%s" (%s): %s',
		'Error adding "%s" to Windows-group "%s": %s'	=>	'Ошибка добавления "%s" в Windows-группу "%s": %s',
		'Error saving user "%s" (%s): %s'	=>	'Ошибка сохранения пользователя "%s" (%s): %s',
		'Cannot change mail aliases for "%s": %s' => 'Ошибка изменения почтовых алиасов для "%s": %s',
		'Really revert changes ?'	=>	'Действительно откатить модификации ?',
		'Delete user "%s" ?'	=>	'Удалить пользователя "%s" ?',
		'Cancel new user ?'		=>	'Отменить добавление пользователя ?',
		'Error deleting Unix-user "%s" (%s): %s'	=>	'Ошибка удаления Unix-пользователя "%s" (%s): %s',
		'Error deleting Windows-user "%s" (%s): %s'	=>	'Ошибка удаления Windows-пользователя "%s" (%s): %s',
		'Error deleting mail account "%s" (%s): %s'	=>	'Ошибка удаления почтового пользователя "%s" (%s): %s',
		'Error creating mail alias "%s" for "%s": %s' => 'Ошибка создания почтового алиаса "%s" для "%s": %s',
		'Cannot display user "%s"'	=>	'Не могу вывести пользователя "%s"',
		'Cannot change password for "%s" on "%s": %s' => 'Не могу изменить пароль для "%s" на "%s": %s',
		'Exit and loose changes ?'	=>	'Выйти и потерять изменения ?',
		'Passwords dont match' => 'Введенные пароли не совпадают',
		'Password contains non-basic characters. Are you sure ?' => 'Пароль содержит символы из расширенного набора. Вы уверены ?',
		'Password is empty. Are you sure ?' => 'Пароль пустой. Вы уверены ?',
		'Password is less than 4 characters. Are you sure ?' => 'Пароль короче 4 символов. Вы уверены ?',
		'Mail aliases should not contain non-basic characters' => 'В почтовых алиасах допустимы только символы базового набора',
		'Key fields cannot be empty' => 'Ключевые поля должны быть непусты',
		'Key field modification is broken now. Are you sure ?' => 'Изменение ключевых полей пока не реализовано. Вы уверены, что хотите продолжить ?',
		'Attributes'	=>	'Атрибуты',
		'Save'			=>	'Сохранить',
		'Revert'		=>	'Отменить',
		'Identifier'	=>	'Идентификатор',
		'Full name'	=>	'Полное имя',
		'Create'	=>	'Добавить',
		'Delete'	=>	'Удалить',
		'Refresh'	=>	'Обновить',
		'Exit'	=>	'Выйти',
		'Close'	=>	'Закрыть',
		' Users '	=>	' Пользователи ',
		' Groups '	=>	' Группы ',
		' Mail groups '	=>	' Почтовые группы ',
		'Group name'	=>	'Название группы',
		'Group number'	=>	'Номер группы',
		'Description'	=>	'Описание',
		'Members'		=>	'Члены группы',
		'Principal name'=>	'Принципал',
		'Mail aliases'	=>	'Почтовые алиасы',
		'Mail groups'	=>	'Почтовые группы',
		'Domain Intercept'	=>	'Слеж. за доменом',
		'User Intercept'	=>	'Слеж. за пользователем',
		'Real user id'	=>	'Реальный ид. пользователя',
		'Real group id'	=>	'Реальный ид. группы',
		'Error saving group "%s": %s'	=>	'Ошибка сохранения группы "%s": %s',
		'Cancel new group ?'	=>	'Отменить добавление группы ?',
		'Delete group "%s" ?'	=>	'Удалить группу "%s"',
		'Error deleting group "%s": %s'	=> 'Ошибка удаления группы "%s": %s',
		'Cannot display group "%s"'	=>	'Не могу отобразить группу "%s"',
		'Groups not found: %s' => 'Группы не найдены: %s',
		'Error saving mail group "%s": %s' => 'Ошибка сохранения почтовой группы "%s": %s',
		'Cancel new mail group ?' => 'Отменить создание почтовой группы ?',
		'Delete mail group "%s" ?' => 'Удалить почтовую группу "%s" ?',
		'Error deleting mail group "%s": %s' => 'Ошибка удаления почтовой группы "%s": %s',
		'Cannot display mail group "%s"' => 'Не могу отобразить почтовую группу "%s"',
		'This object name is reserved' => 'Этот идентификатор зарезервирован. Используйте другой.',
		'Cannot delete reserved object' => 'Этот объект нельзя удалить. Он зарезервирован.',
		'Connection in progress ...' => 'Идет подключение ...',
		'Connection to "%s" failed' => 'Ошибка подключения к серверу "%s"',
	),
);

function _T () {
	global $translations;
	$lang = $translations['ru']; // FIXME
	$args = func_get_args();
	$format = array_shift($args);
	if (count($args) == 1 && is_array($args[0]))
	    $args = $args[0];
	if (isset($lang[$format]))
	    $format = $lang[$format];
	$message = empty($args) ? $format : vsprintf($format, $args);
	return $message;
}

?>
