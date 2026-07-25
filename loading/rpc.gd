extends Node

func _ready():
	DiscordRPC.app_id = 1530222816421609472
	DiscordRPC.details = "Defense air space"
	DiscordRPC.state = "https://welloty.github.io/saaw/"
	DiscordRPC.large_image = "saawtd_logo"
	DiscordRPC.large_image_text = "saaw tower defense"
	DiscordRPC.small_image = "osa"
	DiscordRPC.small_image_text = "osa"
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())

	DiscordRPC.refresh()
