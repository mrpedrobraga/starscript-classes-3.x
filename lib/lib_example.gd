extends StarScriptLibrary

## Your command callback takes three parameters,
##	
##	shell : StarScriptShell
##	- The shell that's calling this callback.
##	- You can use it to run commands, and even sub blocks.
##
##	command : StarScriptCommand
##	- The command that's calling this function.
##	It contains all the information you need - from it's key to its parameters
##	to its subcommands.
##
##	context : Dictionary
##	- Contains context about the command execution on the
##	parent scope of the current command, such as
##	- Local and captured variables;
##	- The local iteration index;
##	- Etc;
##	- You can, of course, add your own things to the context.
func example_command(shell, command, context):
	# Checking out what's inside the command.
	shell.r_print(str([command.key, command.params]))
	
	# Checking out what's inside the context.
	shell.r_print(str(context))
	
	# All function callbacks must yield something before
	# returning (that's just how 3.x works).
	# If you don't, it'll throw "First argument of yield is not of type object."
	#
	# So, adding this here waits a single frame.
	yield(shell.get_tree(), "idle_frame")
	
	# The return value is passed to the caller,
	# in case you ran this command inside another one.
	return true

## This function will install your custom commands.
##
## library : GDScript
## is the library that'll be used to regiter this command.
## its value will be this own script;
##
## shell : StarScriptShell
## this is the shell the library will be installed on.
static func _install(library, shell):
	# Registering a command is equally simple.
	# Use shell.register_command, which takes three arguments:
	#
	# syntax : String
	# - How this command will be used.
	# - In this part, you can add optional type-checking.
	#
	# library : GDScript
	# - The object the callback function will be in.
	# the _install function already passes this very script file
	# through [param library], so you can use that
	# and declare the callback in this file.
	#
	# callback_name : String
	# - The name of the callback.
	
	shell.register_command ( "await <message>", library, "s_await")
