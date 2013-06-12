require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'twitter'
require 'tweetstream'

CONFIG = YAML.load_file('config.yml')

[Twitter, TweetStream].each do |cls|
  cls.configure do |c|
    CONFIG.each { |k, v| c.send(:"#{k}=", v) }
  end
end

TARGET_USER = Twitter.user("WarframeAlerts")

class Alert
  def initialize(status)
    @user = status.user
    return unless @user == TARGET_USER

    @mission, @planet, @title, minutes, credits, @item_name, @item_type, *rest = status.text.split(/\s*[():]+\s*|\s+-\s+/)

    @valid = (minutes =~ /^\d+m$/ && credits =~ /^\d+cr$/)
    return unless @valid

    @minutes = minutes.to_i
    @credits = credits.to_i
    @deadline = status.created_at + (@minutes * 60)
  end

  def check
    if @user != TARGET_USER
      [false, "not from @#{TARGET_USER.screen_name}"]
    elsif !@valid
      [false, "invalid alert"]
    elsif @item_name.nil?
      [false, "no item offered"]
    elsif @deadline < Time.now
      [false, "deadline passed"]
    else
      [true, nil]
    end
  end

  def message
    deadline = @deadline.strftime("%H:%M")
    "#{@item_name} (#{@item_type}) at #{@planet} until #{deadline}"
  end

  def relay
    return unless important?

    puts "Alert meets criteria: #{message}"
    Twitter.update("@wisqnet #{message}")
    exit(1)
  end
end


#Twitter.user_timeline(TARGET_USER.id).each do |status|
TweetStream::Client.new.follow(TARGET_USER.id) do |status|
  puts "---\n@#{status.user.name}: #{status.text}"

  alert = Alert.new(status)
  important, reject_reason = alert.check
  if important
    puts "ALERT: #{alert.message}"
    Twitter.update("@wisqnet #{alert.message}")
  else
    puts "Rejected: #{reject_reason}"
  end
end
