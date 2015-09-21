#!/usr/bin/env ruby

require "net/http"
require "cgi"

module ErrorsReporter
  @threads = []
  at_exit {
    for thread in @threads
      STDERR.puts "Rollout: errors_reporter: waiting for #{thread}"
      thread.join
    end
  }

  def self.report_error(action, details)
    server = ENV["ROLLOUT_allServicesInOneServer"]
    if server.nil?
        server = "http://error.rollout.io"
    else
        server = server.gsub(/^https:\/\//, "http://")
    end

    app_key = ENV["ROLLOUT_appKey"]; app_key = "unknown_key" if app_key.nil?
    short_version = ENV["ROLLOUT_shortVersion"]; short_version = "unknown_short_version" if short_version.nil?
    api_version = ENV["ROLLOUT_apiVersion"]; api_version = "unknown_api_version" if api_version.nil?

    errors_url="#{server}/build/error/#{app_key}/#{short_version}/#{api_version}"
    report_full_url = "#{errors_url}?action=#{CGI.escape(action)}&label=#{CGI.escape (details.to_s)}"[0,8000]
    
    if @threads.length == 5
      STDERR.puts "Rollout: too many errors, will not report #{report_full_url}"
      return
    end
    
    @threads.push(Thread.new {
      STDERR.puts "Rollout: errors_reporter (thread #{Thread.current}): Will report the error via url:'#{report_full_url}'"
      result = Net::HTTP.get(URI(report_full_url))
      STDERR.puts "Rollout: errors_reporter (thread #{Thread.current}): report result: #{result}"
    })

  end

  report_error ARGV[0], ARGV[1] if File.basename($0) == "errors_reporter.rb"
end
