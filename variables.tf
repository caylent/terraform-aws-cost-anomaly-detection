variable "threshold_type" {
  description = "Indicate if the alert will trigger based on a absolute amount or a percentage"
  type        = string

  validation {
    condition     = contains(["ANOMALY_TOTAL_IMPACT_ABSOLUTE", "ANOMALY_TOTAL_IMPACT_PERCENTAGE"], var.threshold_type)
    error_message = "threshold_type must be  ANOMALY_TOTAL_IMPACT_ABSOLUTE for an alert based on absolute value or ANOMALY_TOTAL_IMPACT_PERCENTAGE for a percentage alert"
  }
}
variable "alert_threshold" {
  description = "Defines the value to trigger an alert. Depending on the value chosen for the threshold_type variable, it will represent a percentage or an absolute ammount of money"
  type        = number
}

variable "slack_channel_id" {
  description = "right click on the channel name, copy channel URL, and use the letters and number after the last /"
  type        = string
  default     = ""
}

variable "slack_workspace_id" {
  description = "ID of your slack slack_workspace_id"
  type        = string
  default     = ""
}

variable "enable_slack_integration" {
  description = "Set to false if slack integration is not needed and another subscriber to the SNS topic is preferred"
  type        = bool
  default     = true
}

variable "enable_ms_teams_integration" {
  description = "Set to false if Microsoft Teams integration is not needed and another subscriber to the SNS topic is preferred"
  type        = bool
  default     = true
}

variable "team_id" {
  description = "The id of the Microsoft Teams team"
  type        = string
  default     = ""

}
variable "teams_channel_id" {
  description = "The id of the Microsoft Teams channel"
  type        = string
  default     = ""
}

variable "teams_tenant_id" {
  description = "The id of the Microsoft Teams tenant"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "name for the monitors, topic, etc"
  type        = string
  default     = "cost-anomaly-monitor"
}

variable "sns_topic_arn" {
  description = "ARN of an already existing SNS topic to send alerts. If a value is provided, the module will not create a SNS topic"
  type        = string
  default     = ""
}

variable "accounts" {
  description = "List of AWS accounts to monitor. Use it when deploying the module on the root account of an organization"
  type        = list(string)
  default     = []
}

variable "deploy_lambda" {
  description = "flag to choose if the lambda will be deployed or not"
  type        = bool
  default     = true
}

variable "lambda_frequency" {
  description = "Frequency to run the lambda (cron formating is also accepted)"
  type        = string
  default     = "cron(0 13 ? * MON *)" # defaults to Mondays 9:00 am ET (13 UTC)
}
variable "lambda_timeout" {
  description = "maximum amount of time in seconds that the Lambda function can run"
  type        = number
  default     = 3
  validation {
    condition     = var.lambda_timeout > 0 && var.lambda_timeout <= 900
    error_message = "timeout value must be higher than 0 seconds and lower or equal than 900 seconds (15 minutes)"
  }
}
