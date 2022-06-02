extends TextureButton

func _on_Donate_pressed():
	var error = OS.shell_open("https://www.paypal.com/donate?hosted_button_id=764A5SEQUZYR8")
	if error != OK:
		printerr("Error opening browser. Error Code: %s" % error )
