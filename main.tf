resource "aws_sns_topic" "cost_anomaly_topic" {
  count  = var.sns_topic_arn == "" ? 1 : 0
  name   = "${var.name}-topic"
  policy = data.aws_iam_policy_document.sns_topic_policy_document[count.index].json
  tags   = var.tags
}


resource "aws_ce_anomaly_monitor" "service_anomaly_monitor" {
  count             = local.multi_account ? 0 : 1
  name              = "SERVICE-${var.name}"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = var.tags
}

resource "aws_ce_anomaly_monitor" "linked_account_anomaly_monitor" {
  # Each linked account monitor only supports 10 accounts. This creates extra monitors if there are more than 10 accounts
  count        = local.multi_account ? ceil(length(var.accounts) / 10) : 0
  name         = "LINKED-ACCOUNT-${var.name}-${count.index}"
  monitor_type = "CUSTOM"
  monitor_specification = jsonencode(
    {
      # Do not remove null values. Otherwise TF will recreate the monitor on each apply
      And            = null
      CostCategories = null
      Dimensions = {
        Key          = "LINKED_ACCOUNT"
        MatchOptions = null
        Values       = chunklist(var.accounts, 10)[count.index]
      }
      Not  = null
      Or   = null
      Tags = null
    }
  )
  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "anomaly_subscription" {
  name = "${local.multi_account ? aws_ce_anomaly_monitor.linked_account_anomaly_monitor[0].name : aws_ce_anomaly_monitor.service_anomaly_monitor[0].name}-subscription"
  threshold_expression {
    dimension {
      key           = var.threshold_type
      values        = [var.alert_threshold]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  frequency = "IMMEDIATE" # required for alerts sent to SNS

  monitor_arn_list = local.multi_account ? aws_ce_anomaly_monitor.linked_account_anomaly_monitor[*].arn : aws_ce_anomaly_monitor.service_anomaly_monitor[*].arn

  subscriber {
    type    = "SNS"
    address = var.sns_topic_arn == "" ? aws_sns_topic.cost_anomaly_topic[0].arn : var.sns_topic_arn
  }

  tags = var.tags
}


resource "awscc_chatbot_slack_channel_configuration" "chatbot_slack_channel" {
  count              = local.slack_integration
  configuration_name = "${var.name}-slack-config"
  iam_role_arn       = aws_iam_role.chatbot_role[0].arn
  slack_channel_id   = var.slack_channel_id
  slack_workspace_id = var.slack_workspace_id
  guardrail_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess", ]
  sns_topic_arns     = [var.sns_topic_arn == "" ? aws_sns_topic.cost_anomaly_topic[count.index].arn : var.sns_topic_arn]
}

resource "aws_iam_policy" "chatbot_channel_policy" {
  count  = local.slack_integration
  name   = "${var.name}-channel-policy"
  policy = data.aws_iam_policy_document.chatbot_channel_policy_document.json
}


resource "aws_iam_role" "chatbot_role" {
  count              = local.slack_integration
  name               = "${var.name}-chatbot-role"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "chatbot_role_attachement" {
  count      = local.slack_integration
  role       = aws_iam_role.chatbot_role[0].name
  policy_arn = aws_iam_policy.chatbot_channel_policy[0].arn
}

resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  count       = local.deploy_lambda
  name        = "${var.name}-trigger"
  description = "${var.name}-trigger"

  schedule_expression = var.lambda_frequency
}

resource "aws_cloudwatch_event_target" "event_target" {
  count     = local.deploy_lambda
  rule      = aws_cloudwatch_event_rule.lambda_trigger[0].name
  target_id = "TriggerLambda"
  arn       = module.lambda[0].lambda_function_arn
}

resource "aws_lambda_permission" "allow_events_bridge_to_run_lambda" {
  count         = local.deploy_lambda
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda[0].lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_trigger[0].arn
}

module "lambda" {
  count            = local.deploy_lambda
  source  = "terraform-aws-modules/lambda/aws"
  version = "5.0.0"
  function_name = "${var.name}-lambda"
  description   = "report current and forecast cost"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  source_path   = "${path.module}/lambda/main.py"
  attach_policy_json = true
  policy_json = data.aws_iam_policy_document.lambda_policy.json
  environment_variables = {
    "SNS_TOPIC_ARN" = var.sns_topic_arn != "" ? var.sns_topic_arn : aws_sns_topic.cost_anomaly_topic[0].arn # Do not change the key. It's used by the lambda
    "ACCOUNT_ID"    = data.aws_caller_identity.current.account_id
    "REGION"        = data.aws_region.current.name
  }
}