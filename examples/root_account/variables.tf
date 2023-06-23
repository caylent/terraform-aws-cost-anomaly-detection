variable "slack_channel_id" {
  description = "right click on the channel name, select copy channel URL, and use the letters and number after the last /"
  type        = string
}

variable "slack_workspace_id" {
  description = "ID of your slack slack_workspace_id"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}