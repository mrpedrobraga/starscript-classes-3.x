extends StarScriptBlock
class_name StarScript

## Stores a script written in StarScript.

## Dictionary of sections containing all the [StarScriptSection]s
## defined in this file.
export var sections : Dictionary

export var source_code : String
export var compilation_version : String = "2.0"

## Similar to [method try_as_dictionary], but won't convert
## this object into one, instead, it will convert only the
## inner properties.[br]
## This method actually modifies the contents of this [StarScript].
func compact():
	for key in properties.keys():
		properties[key] = properties[key].try_as_dictionary()
		# Subcompact the properties:
		var selfClass = load("res://Components/StarScript/src/StarScriptBlock.gd")
		if properties[key] is selfClass:
			properties[key].compact()
	return self

func _to_string():
	#return "SSH"
	
	var repr := ""
	
	var b : String = ._to_string()
	if b:
		repr += b
	
	if sections:
		for key in sections.keys():
			repr += "--%s\n%s" % [key, str(sections[key]).indent('\t')]
	
	return repr
