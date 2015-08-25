#! /usr/bin/env ruby

require 'sensu-handler'
require 'json'

class Slack < Sensu::Handler
  def slack_token
    get_setting('token')
  end

  def slack_channel
    get_setting('channel')
  end

  def slack_message_prefix
    get_setting('message_prefix')
  end

  def slack_team_name
    get_setting('team_name')
  end

  def slack_bot_name
    get_setting('bot_name')
  end

  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def get_setting(name)
    settings['devops-slack'][name]
  end

  def handle
    #attachment = @event['notification'] || build_attachment
    post_data(build_attachment)
  end

  def acquire_infra_details
    JSON.parse(File.read('/etc/sensu/conf.d/monitoring_infra.json'))
  end

  def define_sensu_env
    case acquire_infra_details['sensu']['environment']
    when 'prd'
      return 'Prod: '
    when 'dev'
      return 'Dev: '
    when 'stg'
      return 'Stg: '
    when 'vagrant'
      return 'Vagrant: '
    else
      return 'Test: '
    end
  end

  def define_status
    case @event['check']['status']
    when 0
      return 'OK'
    when 1
      return 'WARNING'
    when 2
      return 'CRITICAL'
    when 3
      return 'UNKNOWN'
    when 127
      return 'CONFIG ERROR'
    when 126
      return 'PERMISSION DENIED'
    else
      return 'ERROR'
    end
  end

  def set_color
    case @event['check']['status']
    when 0
      return '#33CC33'
    when 1
      return 'warning'
    when 2
      return '#FF0000'
    when 3
      return '#FF6600'
    else
      return '#FF6600'
    end
  end

  def define_check_state_duration
    ''
  end

  def build_attachment
[
          'fallback' => 'Sensu Alert',
          'text' => "#{define_sensu_env} #{@event['client']['name']} - #{@event['check']['name']}",
          'color' => set_color,
          'fields' => [
            {
              'title' => 'Monitored Instance',
              'value' => @event['client']['name'],
              'short' => true
            },
            {
              'title' => 'Sensu-Client',
              'value' => @event['client']['name'],
              'short' => true
            },
            {
              'title' => 'Check Name',
              'value' => @event['check']['name'],
              'short' => true
            },
            {
              'title' => 'Check State',
              'value' => define_status,
              'short' => true
            },
            {
              'title' => 'Event Time',
              'value' => Time.at(@event['check']['issued']),
              'short' => true
            },
            {
              'title' => 'Check State Duration',
              'value' => define_check_state_duration,
              'short' => true
            },
            {
              'title' => 'Check Output',
              'value' => @event['check']['output'],
              'short' => true
            }
          ]
      ]
  end

  def post_data(notice)
    uri = slack_uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
    req.body = "payload=#{payload(notice).to_json}"

    response = http.request(req)
    verify_response(response)
  end

  def verify_response(response)
    case response
    when Net::HTTPSuccess
      true
    else
      fail response.error!
    end
  end

  def payload(notice)
    {
      link_names: 1,
      text: slack_message_prefix,
      attachments: notice,
      icon_emoji: icon_emoji
    }.tap do |payload|
      payload[:channel] = slack_channel if slack_channel
      payload[:username] = slack_bot_name if slack_bot_name
    end
  end

  def icon_emoji
    default = ':feelsgood:'
    emoji = {
      0 => ':godmode:',
      1 => ':hurtrealbad:',
      2 => ':feelsgood:'
    }
    emoji.fetch(check_status.to_i, default)
  end

  def check_status
    @event['check']['status']
  end

  def slack_uri
    url = 'https://hooks.slack.com/services/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'
    URI(url)
  end
end
