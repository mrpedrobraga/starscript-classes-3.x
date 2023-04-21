extends StarScriptLibrary

func s_print(_shell, _command, _context):
	var msg = ""
	for i in _command.params:
		msg += i
		msg += " "
	msg = yield(_shell._eval_if_expr(msg, _context), "completed")
	_shell.r_print(str(msg))
	
	yield(_shell.get_tree(), "idle_frame")
	return str(msg)

func s_wait (_shell, _command, _context):
	yield(_shell.get_tree().create_timer(float(_command.params[0])), "timeout")

func s_eval (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	#print(_command.params)
	yield(_shell.get_tree(), "idle_frame")
	return _command.params[0]

func s_dialog(_shell : StarScriptShell, _command : StarScriptCommand, _context):
	_shell.r_print("Dialog by %s : %s" % [_command.params[2], _command.params[0]])
	yield(_shell.get_tree(), "idle_frame")

func s_cmp (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	var a = float(_command.params[0])
	var b = float(_command.params[1])

	if a > b:
		_shell.r_print('GREATER')
		return 1
	elif a < b:
		_shell.r_print('LESSER')
		return -1
	else:
		_shell.r_print('EQUAL')
		return 0
	yield(_shell.get_tree(), "idle_frame")

func s_expr (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	# TODO: Actually run the expression.
	print(_command.params)
	yield(_shell.get_tree(), "idle_frame")
	return _command.params[0]

func s_set (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	yield(_shell.get_tree(), "idle_frame")
	match _command.params[1]:
		"=":
			return _shell._set_variable(
				_command.params[0],
				_command.params[2],
				_context
			)
		"+=":
			return _shell._set_variable(
				_command.params[0],
				_shell._get_variable(_command.params[0], _context) + _command.params[2],
				_context
			)
		"-=":
			return _shell._set_variable(
				_command.params[0],
				_shell._get_variable(_command.params[0], _context) - _command.params[2],
				_context
			)
		"*=":
			return _shell._set_variable(
				_command.params[0],
				_shell._get_variable(_command.params[0], _context) * _command.params[2],
				_context
			)
		"^=":
			return _shell._set_variable(
				_command.params[0],
				pow(_shell._get_variable(_command.params[0], _context), _command.params[2]),
				_context
			)
		"/=":
			return _shell._set_variable(
				_command.params[0],
				_shell._get_variable(_command.params[0], _context) / _command.params[2],
				_context
			)
		"//=":
			return _shell._set_variable(
				_command.params[0],
				floor(_shell._get_variable(_command.params[0], _context) / _command.params[2]),
				_context
			)
		"%=":
			return _shell._set_variable(
				_command.params[0],
				fposmod(_shell._get_variable(_command.params[0], _context), _command.params[2]),
				_context
			)

func s_get (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	yield(_shell.get_tree(), "idle_frame")
	return _shell._get_variable(_command.params[0], _context)

func s_if (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	var condition = yield(_shell._eval_if_expr(_command.main_param, _context), "completed")
	if condition:
		return yield(_shell.x_block(_command, _context), "completed")
	yield(_shell.get_tree(), "idle_frame")
	return null

func s_unless (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	var condition = yield(_shell._eval_if_expr(_command.main_param, _context), "completed")
	if not condition:
		return yield(_shell.x_block(_command, _context), "completed")
	return null

func s_await (_shell : StarScriptShell, _command : StarScriptCommand, _context):
	var messages = _command.params.duplicate()
	# TODO: Implement conjunction;
	var await_all : bool = false
	var message_completion_statuses : Array = [] #Array[bool]
	message_completion_statuses.resize(messages.size())
	for i in message_completion_statuses.size():
		message_completion_statuses[i] = false
	while true:
		var message_name : String = yield(_shell, "message")
		if message_name in messages:
			message_completion_statuses[messages.find(message_name)] = true

		var can_move_on : bool = false
		if await_all:
			can_move_on = true
			for i in message_completion_statuses:
				can_move_on = can_move_on and i
		else:
			can_move_on = false
			for i in message_completion_statuses:
				can_move_on = can_move_on or i
		if can_move_on:
			break
	yield(_shell.get_tree(), "idle_frame")

static func _install(library, _shell):
	_shell.register_command ( "print ...", library, "s_print")
	_shell.register_command ( "wait <amt:number>", library, "s_wait")
	_shell.register_command ( "eval ...", library, "s_eval")
	_shell.register_command ( "dialog ...", library, "s_dialog")
	_shell.register_command ( "cmp <a:number> <b:number>", library, "s_cmp")
	_shell.register_command ( "set <variable:string> <mode:string> <value>", library, "s_set")
	_shell.register_command ( "get <variable:string>", library, "s_get")
	_shell.register_command ( "expr <expr>", library, "s_expr")
	_shell.register_command ( "if ...", library," s_if")
	_shell.register_command ( "unless ...", library, "s_unless")
	_shell.register_command ( "await <message>", library, "s_await")
