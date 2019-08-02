#!/usr/bin/ruby
# vim: ts=2 sw=2 et si ai : 

require 'pp'
require 'mqtt'
require 'open-uri'
require 'fileutils'
require 'logger'
require 'base64'
require 'json'
require 'yaml'
require 'ostruct'
require 'benchmark'

def usage
  $stderr.puts "usage #{$0} config.yaml"
  exit
end
usage if ARGV.size == 0

Dir.chdir(File.dirname($0))

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

$conf = OpenStruct.new(YAML.load_file(ARGV[0]))

def mqtt_publish(str)
  conn_opts = {
    "remote_host" => $conf.host,
    "remote_port" => $conf.port
  }
  if $conf.use_auth
    conn_opts["username"] = $conf.username
    conn_opts["password"] = $conf.password
  end
  
  MQTT::Client.connect(conn_opts) do |c|
    $log.debug "publish: publish_topic=#{$conf.publish_topic}, payload_size=#{str.size}"
    c.publish($conf.publish_topic, str)
  end
end

# create image backup directory
FileUtils.mkdir_p($conf.img_history_dir)

loop do
  filename = Time.now.strftime("m5cam-%Y%m%d-%H%M%S.jpg")

  t = Benchmark.realtime do
    begin
      # capture setting....
      open($conf.m5camera_control_url).read

      sleep 0.5

      open($conf.m5camera_capture_url) do |f|
        img = f.read
      
        # save history
        path = $conf.img_history_dir + File::Separator + filename
        open(path, "wb+") do |f|
          f.write(img)
        end

        b64 = Base64.strict_encode64(img)
        data_uri_scheme = "data:image/jpeg;base64," + b64

        h = {}
        h["image"] = data_uri_scheme
        json_str = h.to_json
        mqtt_publish(json_str)
      
      end
      $log.debug "capture image...filenaem=" + filename 

    rescue Exception => e
      $log.error(e)
    end
  end
  
  sleep $conf.interval - t
end

