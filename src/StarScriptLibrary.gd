extends Resource
class_name StarScriptLibrary

## A Class that registers commands to a [StarScriptShell].

## Must be emitted every time a command finishes.
signal exec_finished(return_val)

## Virtual; installs the commands to a shell.
static func _install(function_container, shell):
	pass
