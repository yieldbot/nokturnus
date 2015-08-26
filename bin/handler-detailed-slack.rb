#! /usr/bin/env ruby

require 'sensu-handler'
require 'json'

class Slack < Sensu::Handler
  # Acquires the mail settings from a json file dropped via Chef
  #
  # These settings will set who the mail should be set to along with any
  # necessary snmtp settings.  All can be overridden in the local Vagrantfile
  #
  # @example Get a setting
  #   "acquire_setting('alert_prefix')" #=> "go away"
  # @param name [string] the alert heading
  # @return [string] the configuration string
  def acquire_setting(name)
    case @current_product
    # when 'devops'
    #   return settings['devops-slack'][name]
    when 'platform'
      return settings['platform-slack'][name]
    else
      return settings["product-#{@current_product}-slack"][name]
    end
  end

  # Acquire any client or device specific information about the
  # monitoring infrastructure
  #
  # @example Get the information
  #   "acquire_infra_details" #=> Hash
  # @return [hash] any provided infra details for the device
  def acquire_infra_details
    JSON.parse(File.read('/etc/sensu/conf.d/monitoring_infra.json'))
  end

  # Acquires product names
  #
  # The product name will be used for contact routing purposes, etc. The product
  # will define which configuration snippet to use
  #
  # @example Get a array of products
  #   "acquire_product" #=> "luts, datapipeline"
  # @return [array] the products
  def acquire_products
    @event['check']['product']
  end

  def handle
    acquire_products.each do |p|
      @current_product = p
      post_data(build_alert)
    end
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

  def clean_output
    @event['check']['output'].partition(':')[0]
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
          'value' => clean_output,
          'short' => true
        }
      ]
    ]
  end

  def check_status
    @event['check']['status']
  end

  def slack_uri
    URI("https://hooks.slack.com/services/#{acquire_setting('token')}")
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
      text: acquire_setting('alert_prefix'),
      attachments: alert
    }.tap do |payload|
      payload[:channel] = acquire_setting('channel')
      payload[:username] = acquire_setting('bot_name')
    end
  end
end
