extends SceneTree

func _initialize() -> void:
	var file := FileAccess.open("res://build/GODOT-LICENSE.txt", FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file.close()
	var notices := FileAccess.open("res://build/THIRD-PARTY-NOTICES.txt", FileAccess.WRITE)
	notices.store_string("Godot engine third-party components\n\n")
	notices.store_string(JSON.stringify(Engine.get_copyright_info(), "\t"))
	notices.store_string("\n\nLicense texts\n\n")
	var licenses := Engine.get_license_info()
	for key in licenses:
		notices.store_string(str(key) + "\n" + str(licenses[key]) + "\n\n")
	notices.close()
	quit()
