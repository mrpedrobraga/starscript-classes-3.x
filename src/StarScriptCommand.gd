tool
extends StarScriptBlock
class_name StarScriptCommand

## Holds the data for a single StarScript command.

## The key of the command.
export var key : String

## The parameters of the command, as an array.
export var params : Array

## Creates a new command quickly
static func create(key_ : String, params_ : Array):
	var selfClass = load("res://Components/StarScript/src/StarScriptCommand.gd")
	var __s = selfClass.new() 
	__s.key = key_
	__s.params = params_
	return __s

## Overriding to add property conversion functionality.
func try_as_dictionary():
	if commands.size() > 0:
		return self
	var result
	
	if params[0] != null:
		result = params[0]
	else:
		# This property is a full-on dictionary.
		# TODO: Handle Arrays (unnamed properties)
		result = {}
		for prop in properties.keys():
			result[prop] = properties[prop].try_as_dictionary()
	
	return result

func _to_string():
	#return '[SSH - Command %s]' % key 
	
	var repr := "[C] "
	
	repr += str(key)
	
	for param in params:
		repr += " "
		repr += str(param)
	
	if commands:
		repr += "\n"
		repr += ._to_string().indent('\t')
	
	return repr
