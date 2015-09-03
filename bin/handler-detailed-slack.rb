#! /usr/bin/env ruby

require 'sensu-handler'
require 'json'
require 'zoma/config'

class Slack < Sensu::Handler



  # Create the slack attachment and ship it
  # @example Send a slack attachment to the correct channel
  #   "handle" #=> "A well-formed slack notification to a recipent"
  # @return [integer] exit code
  def handle
    post_data(build_alert)
    puts 'slack msg -- sent alert for ' + @event['client']['name'] + ' to ' + Zoma.acquire_setting('channel')
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

  def build_alert
    [
      'fallback' => 'Sensu Alert',
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
          'value' => Zoma.define_status,
          'short' => true
        },
        {
          'title' => 'Event Time',
          'value' => Time.at(@event['check']['issued']),
          'short' => true
        },
        {
          'title' => 'Check State Duration',
          'value' => Zoma.define_check_state_duration,
          'short' => true
        },
        {
          'title' => 'Check Output',
          'value' => Zoma.clean_output,
          'short' => true
        }
      ]
    ]
  end


  def slack_uri
    URI("https://hooks.slack.com/services/#{Zoma.acquire_setting('token')}")
  end

  def post_data(alert)
    uri = slack_uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
    req.body = "payload=#{payload(alert).to_json}"

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

  def payload(alert)
    {
      link_names: 1,
      text: Zoma.acquire_setting('alert_prefix'),
      attachments: alert
    }.tap do |payload|
      payload[:channel] = Zoma.acquire_setting('channel')
      payload[:username] = Zoma.acquire_setting('bot_name')
    end
  end
end
