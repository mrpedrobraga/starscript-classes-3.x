extends Node
class_name StarScriptShell

## The interpreter that runs a [StarScript].

## The extra libraries that will be isntalled on this
## script when it initializes.
## Must be an Array[Script]
export var libraries : Array
var installed_libraries : Array
var installed_function_containers : Array

## The commands this shell recognizes.[br][br]
##
## The dictionary maps [String] ->
## [code]func (params : Array, context : StarScriptExecutionContext)[/code]
var commands : Dictionary = {}
## Commands, but stored by their key, for easy access.
var commands_by_key : Dictionary = {}

## Thes node that owns this shell,
## useful if this shell will be spawned to handle a character.
export var object : NodePath

const regex_syntax_variable := "<(?<name>\\w+)(?::(?<type>\\w+))?>$"
const regex_keyword := "\\w+(?:|\\w+)*"
const regex_param_syntax := "(\\w+(\\|\\w+)+|<\\w+(:\\w+)?>|\\w+)"
const boolean_truths := ['true', 'yes', 'on', 'always', 'sure', 'maybe']
const boolean_falses := ['false', 'no', 'off', 'never', 'nah']

signal message(message_name)

## Register a command giving a syntax and a handler.
func register_command(syntax : String, source_library, handler_function_name : String):
	if syntax == null or syntax == "":
		push_error("Syntax can not be empty.")
		return
	
	var r_variable = create_regex_from_string(regex_syntax_variable)
	var r_keyword = create_regex_from_string(regex_keyword)
	
	var members := syntax.split(" ", false)
	var key = String(members[0])
	members.remove(0)
	
	var syntaxes := []
	
	var counter := 0
	for p_syntax in members:
		counter += 1
		
		var syntax_checker := {}
		
		# Check for variables
		var match_ = r_variable.search(p_syntax)
		if not match_ == null:
			syntax_checker.type = "variable"
			syntax_checker.index = counter
			syntax_checker.argument_name = match_.get_string("name")
			if match_.names.has("type"):
				syntax_checker.argument_type = match_.get_string("type")
			syntaxes.append(syntax_checker)
			continue
		
		# Check for keywords
		match_ = r_keyword.search(p_syntax)
		if not match_ == null:
			syntax_checker.type = "keyword"
			syntax_checker.index = counter
			syntax_checker.options = p_syntax.split("|", false)
			syntaxes.append(syntax_checker)
			continue
	
		# Check for end of parameter list
		# (everything written after ... is introduced gets clumped together)
		# Any syntax after it gets discarded, so take care.
		if p_syntax == "...":
			syntax_checker.type = "resting"
			syntax_checker.index = counter
			syntaxes.append(syntax_checker)
			break
	
		# Check for errors
		push_error("Syntax invalid: '" + syntax + "' :: '" + p_syntax + "'.")
	
	commands[key] = {
		"parameter_syntaxes": syntaxes,
		"source_library": source_library,
		"handler_fn": handler_function_name
	}

## Executes a whole section
func x_section(section : StarScriptSection):
	# Create the master context
	var context := {}
	context.captured_variables = {}
	context.local_variables = {}
	# context.return_value = null
	
	var result
	
	result = yield(x_block(section, context), "completed")
	
	# Return
	return result

## Executes a whole code block
func x_block(block : StarScriptBlock, parent_context : Dictionary):
	var context := _create_subcontext(parent_context)
	var i_index := 0
	var result
	
	# Pass in the block through the context.
	context.block = block
	
	# Run all the commands
	while i_index < block.commands.size():
		# Pass in the iteration index through the context.
		context.i_index = i_index
		
		# The return value of a block is the value of
		# the last command that runs in it.since y
		result = yield(x_command(block.commands[i_index], context), "completed")
		context.erase("ephemerals")
		i_index += 1
	
	# Free
	context.erase("local_variables") # Free locals.
	
	# Return
	yield(get_tree(), "idle_frame")
	return result

func _create_subcontext(context : Dictionary) -> Dictionary:
	var subc := {}
	subc.captured_variables = context.captured_variables
	merge_b_into_a(subc.captured_variables, context.local_variables)
	# All variables in a subcontext are captured variables...
	# This is happens because local variables are discarded when
	# a context dies... but local variables from the parent
	# shouldn't be discarded.
	subc.local_variables = {}
	# subc.return_value = null
	
	return subc

func merge_b_into_a (a : Dictionary, b : Dictionary):
	for key in b.keys():
		a[key] = b[key]

# Gets a variable from an execution context.
func _get_variable(variable : String, context : Dictionary):
	if context.local_variables.has(variable):
		return context.local_variables[variable]
	if context.captured_variables.has(variable):
		return context.captured_variables[variable]
	push_warning("Trying to access undeclared variable.")
	return null

# Sets a variable inside an execution context.
func _set_variable(variable : String, value, context : Dictionary):
	# If a local variable exist, it'll set it.
	if context.local_variables.has(variable):
		context.local_variables[variable] = value
		return value
	# If not, a captured variable exists, it'll set that.
	if context.captured_variables.has(variable):
		context.captured_variables[variable] = value
		return value
	# If no variables exist, it'll declare a new local variable.
	# TODO: This behaviour might change, allowing for declaration
	# of section-level global variables through assignment.
	# And creation of local variables through 'let'.
	context.local_variables[variable] = value
	return value

## Executes a single [StarScriptCommand].
func x_command(command, context : Dictionary):
	if not commands.has(command.key):
		push_error("Command '%s' not found: %s" % [command.key, command])
		yield(get_tree(), "idle_frame")
		return null
	
	var command_handler : Dictionary = commands[command.key]
	var handler_object = command_handler["source_library"].new()
	
	var match_ := match_syntax(command.params, command_handler)
	
	if match_.valid:
		var result = yield(handler_object.call(command_handler["handler_fn"],
			self,				# StarScriptShell
			command,			# The executed command (has params and all inside)
			context				# StarScriptExecutionContext
		), "completed")
		return result
	
	push_warning("Command invalid, skipping.")

func match_syntax(params : Array, command_handler : Dictionary) -> Dictionary:
	var result := {}
	result.valid = true
	result.arguments = {}
	result.partials = []
	
	for i in range(params.size()):
		var result_i := {}
		var param = params[i]
		var syntax = command_handler["parameter_syntaxes"][min(i, command_handler["parameter_syntaxes"].size() - 1)]
		result_i.valid = true
		
		match syntax.type:
			"keyword":
				result_i.type = "keyword"
				
				if not param in syntax.options:
					result_i.valid = false
					result.valid = false
					r_error(
						"Unrecognized Parameter",
						"The parameter '%s' doesn't match %s" % [param, syntax.options],
						str(params)
					)
			"variable":
				result_i.type = "variable"
				
				if syntax.has("argument_type"):
					match syntax.argument_type:
						"string":
							if not typeof(param) == TYPE_STRING:
								result_i.valid = false
								result.valid = false
								r_error(
									"Type Mismatch",
									"The parameter '%s' is not of type %s" % [param, syntax.argument_type],
									str(params)
								)
						"int":
							if param is String:
								if param.is_valid_int():
									params[i] = param.to_int()
								elif param.is_valid_hex_number(true):
									params[i] = param.hex_to_int()
								param = params[i]
							if not typeof(param) == TYPE_INT:
								result_i.valid = false
								result.valid = false
								r_error(
									"Type Mismatch",
									"The parameter '%s' is not of type %s" % [param, syntax.argument_type],
									str(params)
								)
						"bool":
							if param in boolean_truths:
								params[i] = true
							if param in boolean_falses:
								params[i] = false
							param = params[i]
							if not typeof(param) in [TYPE_BOOL, TYPE_INT, TYPE_REAL]:
								result_i.valid = false
								result.valid = false
								r_error(
									"Type Mismatch",
									"The parameter '%s' is not of type %s" % [param, syntax.argument_type],
									str(params)
								)
						"number":
							if param is String:
								if param.is_valid_float():
									params[i] = param.to_float()
									param = params[i]
							if not typeof(param) in [TYPE_BOOL, TYPE_INT, TYPE_REAL]:
								result_i.valid = false
								result.valid = false
								r_error(
									"Type Mismatch",
									"The parameter '%s' is not of type %s" % [param, syntax.argument_type],
									str(params)
								) # CAST!!!
				
				result.arguments[syntax.argument_name] = param
		
		result.partials.push_back(result_i)
	
	return result

## Throws a Runtime error.
func r_error(error_name : String, error_desc : String, error_placement : String):
	var msg := "At %s: %s; %s." % [error_placement, error_name, error_desc]
	push_error(
		msg
	)

## Prints a message to the standard outputs.
func r_print(_message : String):
	print(_message)

## Prints a message to the standard error outputs.
func r_err(errorname:String, errormessage : String):
	push_error(errormessage)

func _eval_if_expr(obj, context):
	var result = obj
	if "key" in result:
		return yield(x_command(result, context), "completed")
	yield(get_tree(), "idle_frame")
	return result

#----- LIBRARIES -----#

## The core library, with commands fundamental
## to StarScript's behaviour.
var libcore := load("res://Components/StarScript/lib/lib_core.gd")

func _init():
	libcore._install(libcore, self)

func _ready():
	_setup()

func _setup():
	install_libraries()

func install_libraries():
	# Install user defined libraries.
	if libraries:
		for lib in libraries:
			if lib in installed_libraries:
				continue
			lib._install(lib, self)
			installed_libraries.push_back(lib)

static func create_regex_from_string(string : String):
	var r := RegEx.new()
	r.compile(string)
	return r
