extends Node

func _ready() -> void:
	if OS.get_name() == "Android" or not ClassDB.class_exists("DiscordRPC"):
		set_process(false)
		return

	# На ПК безпечно встановлюємо всі значення
	DiscordRPC.set("app_id", 1530222816421609472)
	DiscordRPC.set("details", "air!")
	DiscordRPC.set("state", "https://welloty.github.io/saaw/")
	DiscordRPC.set("large_image", "saawtd_logo")
	DiscordRPC.set("large_image_text", "saaw tower defense")
	DiscordRPC.set("small_image", "osa")
	DiscordRPC.set("small_image_text", "AA")
	DiscordRPC.set("start_timestamp", int(Time.get_unix_time_from_system()))

	DiscordRPC.call("refresh")
